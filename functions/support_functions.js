"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { publicCallableOpts } = require("./callable_config");

const db = admin.firestore();

function resolveIssueDocId(data) {
  const d = data || {};
  return String(d.issueId ?? d.ticketId ?? "").trim();
}

// ─── Helper: تأكد أن المستدعي هو أدمن ──────────────────────────
async function requireAdmin(uid) {
  if (!uid) throw new HttpsError("unauthenticated", "Not signed in.");
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists || doc.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }
}

// ─── submitSupportIssue ─────────────────────────────────────────
// يُستدعى من المتبرع أو بنك الدم لإرسال قضية دعم جديدة
exports.submitSupportIssue = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Not signed in.");

  const data = request.data || {};
  const type = String(data.type || "help").trim();
  const subject = String(data.subject || "").trim();
  const message = String(data.message || "").trim();
  const senderRole = String(data.senderRole || "donor").trim();
  const senderName = data.senderName ? String(data.senderName).trim() : null;

  if (!subject) {
    throw new HttpsError("invalid-argument", "Subject is required.");
  }
  if (message.length < 10) {
    throw new HttpsError(
      "invalid-argument",
      "Message must be at least 10 characters.",
    );
  }
  if (!["complaint", "help"].includes(type)) {
    throw new HttpsError("invalid-argument", "Invalid issue type.");
  }

  const userRecord = await admin.auth().getUser(uid);
  const senderEmail = userRecord.email || "";

  const issueRef = await db.collection("supportTickets").add({
    senderId: uid,
    senderEmail,
    senderName,
    senderRole,
    type,
    subject,
    message,
    status: "open",
    adminReply: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const issueDocId = issueRef.id;

  try {
    const adminsSnap = await db
      .collection("users")
      .where("role", "==", "admin")
      .limit(1)
      .get();

    if (!adminsSnap.empty) {
      const adminDoc = adminsSnap.docs[0];
      const adminUid = adminDoc.id;
      const adminData = adminDoc.data() || {};

      await db
        .collection("notifications")
        .doc(adminUid)
        .collection("user_notifications")
        .add({
          type: "support_new_issue",
          title:
            type === "complaint" ? "📋 New Complaint" : "🆘 New Help Request",
          body: `${senderName || senderEmail}: ${subject}`,
          issueId: issueDocId,
          ticketId: issueDocId,
          senderId: uid,
          read: false,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      const adminToken =
        typeof adminData.fcmToken === "string" ? adminData.fcmToken.trim() : "";
      if (adminToken) {
        const title =
          type === "complaint" ? "📋 New Complaint" : "🆘 New Help Request";
        const body = `${senderName || senderEmail}: ${subject}`;
        await admin
          .messaging()
          .send({
            token: adminToken,
            notification: { title, body },
            data: {
              type: "support_new_issue",
              issueId: issueDocId,
              ticketId: issueDocId,
              title,
              body,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "normal_request_channel",
                icon: "ic_launcher",
              },
            },
            apns: {
              payload: { aps: { alert: { title, body }, sound: "default" } },
            },
            webpush: {
              headers: { Urgency: "normal" },
              notification: { title, body },
            },
          })
          .catch((err) =>
            console.warn(
              "[submitSupportIssue] Admin push failed:",
              err.message,
            ),
          );
      }
    }
  } catch (notifErr) {
    console.warn(
      "[submitSupportIssue] Admin notification failed:",
      notifErr.message,
    );
  }

  return { ok: true, issueId: issueDocId, ticketId: issueDocId };
});

// ─── replySupportIssue ──────────────────────────────────────────
exports.replySupportIssue = onCall(publicCallableOpts, async (request) => {
  const adminUid = request.auth?.uid;
  await requireAdmin(adminUid);

  const data = request.data || {};
  const issueDocId = resolveIssueDocId(data);
  const reply = String(data.reply || "").trim();
  const newStatus = String(data.status || "inProgress").trim();

  if (!issueDocId) {
    throw new HttpsError("invalid-argument", "issueId is required.");
  }
  if (!reply) {
    throw new HttpsError("invalid-argument", "Reply cannot be empty.");
  }
  const validStatuses = ["open", "inProgress", "resolved", "closed"];
  if (!validStatuses.includes(newStatus)) {
    throw new HttpsError("invalid-argument", "Invalid status value.");
  }

  const issueRef = db.collection("supportTickets").doc(issueDocId);
  const issueSnap = await issueRef.get();
  if (!issueSnap.exists) {
    throw new HttpsError("not-found", "Issue not found.");
  }

  const issue = issueSnap.data() || {};
  const senderId = String(issue.senderId || "").trim();
  const subject = String(issue.subject || "Support Issue").trim();

  await issueRef.update({
    adminReply: reply,
    status: newStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (!senderId) {
    console.warn("[replySupportIssue] No senderId on issue, skipping push.");
    return { ok: true };
  }

  const notifTitle = "💬 Admin replied to your issue";
  const notifBody = reply.length > 100 ? `${reply.slice(0, 97)}...` : reply;

  await db
    .collection("notifications")
    .doc(senderId)
    .collection("user_notifications")
    .add({
      type: "support_reply",
      title: notifTitle,
      body: notifBody,
      issueId: issueDocId,
      ticketId: issueDocId,
      ticketSubject: subject,
      ticketStatus: newStatus,
      read: false,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  const userSnap = await db.collection("users").doc(senderId).get();
  const userData = userSnap.exists ? userSnap.data() || {} : {};
  const token =
    typeof userData.fcmToken === "string" ? userData.fcmToken.trim() : "";

  if (token) {
    try {
      await admin.messaging().send({
        token,
        notification: { title: notifTitle, body: notifBody },
        data: {
          type: "support_reply",
          issueId: issueDocId,
          ticketId: issueDocId,
          ticketSubject: subject,
          ticketStatus: newStatus,
          title: notifTitle,
          body: notifBody,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "normal_request_channel",
            icon: "ic_launcher",
            sound: "normal_request",
            defaultSound: false,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: { title: notifTitle, body: notifBody },
              sound: "normal_request.mp3",
            },
          },
        },
        webpush: {
          headers: { Urgency: "high" },
          notification: {
            title: notifTitle,
            body: notifBody,
            requireInteraction: true,
            tag: `support_${issueDocId}`,
          },
          data: {
            type: "support_reply",
            issueId: issueDocId,
            ticketId: issueDocId,
            ticketStatus: newStatus,
            title: notifTitle,
            body: notifBody,
          },
        },
      });
      console.log(
        `[replySupportIssue] ✅ Push sent to uid=${senderId} issue=${issueDocId}`,
      );
    } catch (pushErr) {
      console.warn("[replySupportIssue] Push failed:", pushErr.message);
    }
  } else {
    console.warn(
      `[replySupportIssue] No fcmToken for uid=${senderId}, skipping push.`,
    );
  }

  return { ok: true };
});

// ─── getMyIssues ─────────────────────────────────────────────────
exports.getMyIssues = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Not signed in.");

  const snap = await db
    .collection("supportTickets")
    .where("senderId", "==", uid)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  const issues = snap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      ...d,
      createdAt: d.createdAt?.toMillis() ?? null,
      updatedAt: d.updatedAt?.toMillis() ?? null,
    };
  });

  return { issues, tickets: issues };
});

// ─── getAllIssues ────────────────────────────────────────────────
exports.getAllIssues = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  await requireAdmin(uid);

  const data = request.data || {};
  const filterStatus = data.status ? String(data.status).trim() : null;
  const filterType = data.type ? String(data.type).trim() : null;
  const limit =
    typeof data.limit === "number" ? Math.min(data.limit, 200) : 100;

  let query = db
    .collection("supportTickets")
    .orderBy("createdAt", "desc")
    .limit(limit);

  if (filterStatus) query = query.where("status", "==", filterStatus);
  if (filterType) query = query.where("type", "==", filterType);

  const snap = await query.get();
  const issues = snap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      ...d,
      createdAt: d.createdAt?.toMillis() ?? null,
      updatedAt: d.updatedAt?.toMillis() ?? null,
    };
  });

  return { issues, tickets: issues };
});

// ─── updateIssueStatus ───────────────────────────────────────────
exports.updateIssueStatus = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  await requireAdmin(uid);

  const data = request.data || {};
  const issueDocId = resolveIssueDocId(data);
  const newStatus = String(data.status || "").trim();

  if (!issueDocId) {
    throw new HttpsError("invalid-argument", "issueId is required.");
  }

  const valid = ["open", "inProgress", "resolved", "closed"];

  if (!valid.includes(newStatus)) {
    throw new HttpsError("invalid-argument", "Invalid status.");
  }

  await db.collection("supportTickets").doc(issueDocId).update({
    status: newStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

// ─── deleteSupportIssue ───────────────────────────────────────────
exports.deleteSupportIssue = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  await requireAdmin(uid);

  const issueDocId = resolveIssueDocId(request.data || {});
  if (!issueDocId) {
    throw new HttpsError("invalid-argument", "issueId is required.");
  }

  const [notifByTicket, notifByIssue] = await Promise.all([
    db
      .collectionGroup("user_notifications")
      .where("ticketId", "==", issueDocId)
      .get(),
    db
      .collectionGroup("user_notifications")
      .where("issueId", "==", issueDocId)
      .get(),
  ]);

  const uniqueRefs = new Map();
  for (const doc of notifByTicket.docs) uniqueRefs.set(doc.ref.path, doc.ref);
  for (const doc of notifByIssue.docs) uniqueRefs.set(doc.ref.path, doc.ref);
  const refs = [...uniqueRefs.values()];

  const batchSize = 500;
  if (refs.length > 0) {
    for (let i = 0; i < refs.length; i += batchSize) {
      const batch = db.batch();
      for (
        let j = i;
        j < Math.min(i + batchSize, refs.length);
        j += 1
      ) {
        batch.delete(refs[j]);
      }
      await batch.commit();
    }
  }

  await db.collection("supportTickets").doc(issueDocId).delete();
  return {
    ok: true,
    deletedNotifications: refs.length,
  };
});

// ─── countOpenIssues ─────────────────────────────────────────────
exports.countOpenIssues = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  await requireAdmin(uid);

  const snap = await db
    .collection("supportTickets")
    .where("status", "==", "open")
    .count()
    .get();

  return { count: snap.data().count ?? 0 };
});
