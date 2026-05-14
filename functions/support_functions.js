"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { publicCallableOpts } = require("./callable_config");

const db = admin.firestore();

// ─── Helper: تأكد أن المستدعي هو أدمن ──────────────────────────
async function requireAdmin(uid) {
  if (!uid) throw new HttpsError("unauthenticated", "Not signed in.");
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists || doc.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }
}

// ─── submitSupportTicket ─────────────────────────────────────────
// يُستدعى من المتبرع أو بنك الدم لإرسال تذكرة جديدة
exports.submitSupportTicket = onCall(publicCallableOpts, async (request) => {
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
    throw new HttpsError("invalid-argument", "Invalid ticket type.");
  }

  // جلب email من Firebase Auth
  const userRecord = await admin.auth().getUser(uid);
  const senderEmail = userRecord.email || "";

  const ticketRef = await db.collection("supportTickets").add({
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

  // إشعار داخلي للأدمن (يحفظ في notifications collection لأول أدمن يلاقيه)
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

      // حفظ إشعار في Firestore للأدمن
      await db
        .collection("notifications")
        .doc(adminUid)
        .collection("user_notifications")
        .add({
          type: "support_new_ticket",
          title:
            type === "complaint" ? "📋 New Complaint" : "🆘 New Help Request",
          body: `${senderName || senderEmail}: ${subject}`,
          ticketId: ticketRef.id,
          senderId: uid,
          read: false,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Push notification للأدمن
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
              type: "support_new_ticket",
              ticketId: ticketRef.id,
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
              "[submitSupportTicket] Admin push failed:",
              err.message,
            ),
          );
      }
    }
  } catch (notifErr) {
    // لا توقف العملية إذا فشل الإشعار
    console.warn(
      "[submitSupportTicket] Admin notification failed:",
      notifErr.message,
    );
  }

  return { ok: true, ticketId: ticketRef.id };
});

// ─── replySupportTicket ──────────────────────────────────────────
// يُستدعى من الأدمن فقط — يرد ويرسل إشعار FCM للمرسل
exports.replySupportTicket = onCall(publicCallableOpts, async (request) => {
  const adminUid = request.auth?.uid;
  await requireAdmin(adminUid);

  const data = request.data || {};
  const ticketId = String(data.ticketId || "").trim();
  const reply = String(data.reply || "").trim();
  const newStatus = String(data.status || "inProgress").trim();

  if (!ticketId) {
    throw new HttpsError("invalid-argument", "ticketId is required.");
  }
  if (!reply) {
    throw new HttpsError("invalid-argument", "Reply cannot be empty.");
  }
  const validStatuses = ["open", "inProgress", "resolved", "closed"];
  if (!validStatuses.includes(newStatus)) {
    throw new HttpsError("invalid-argument", "Invalid status value.");
  }

  // جلب التذكرة
  const ticketRef = db.collection("supportTickets").doc(ticketId);
  const ticketSnap = await ticketRef.get();
  if (!ticketSnap.exists) {
    throw new HttpsError("not-found", "Ticket not found.");
  }

  const ticket = ticketSnap.data() || {};
  const senderId = String(ticket.senderId || "").trim();
  const subject = String(ticket.subject || "Support Ticket").trim();

  // تحديث التذكرة في Firestore
  await ticketRef.update({
    adminReply: reply,
    status: newStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (!senderId) {
    console.warn("[replySupportTicket] No senderId on ticket, skipping push.");
    return { ok: true };
  }

  // ─── إشعار Firestore للمستخدم ───────────────────────────────
  const statusLabels = {
    open: "Open",
    inProgress: "In Progress",
    resolved: "Resolved ✅",
    closed: "Closed",
  };

  const notifTitle = "💬 Admin Replied to Your Ticket";
  const notifBody = reply.length > 100 ? `${reply.slice(0, 97)}...` : reply;

  await db
    .collection("notifications")
    .doc(senderId)
    .collection("user_notifications")
    .add({
      type: "support_reply",
      title: notifTitle,
      body: notifBody,
      ticketId,
      ticketSubject: subject,
      ticketStatus: newStatus,
      read: false,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  // ─── FCM Push للمستخدم ───────────────────────────────────────
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
          ticketId,
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
            tag: `support_${ticketId}`,
          },
          data: {
            type: "support_reply",
            ticketId,
            ticketStatus: newStatus,
            title: notifTitle,
            body: notifBody,
          },
        },
      });
      console.log(
        `[replySupportTicket] ✅ Push sent to uid=${senderId} ticket=${ticketId}`,
      );
    } catch (pushErr) {
      console.warn("[replySupportTicket] Push failed:", pushErr.message);
    }
  } else {
    console.warn(
      `[replySupportTicket] No fcmToken for uid=${senderId}, skipping push.`,
    );
  }

  return { ok: true };
});

// ─── getMyTickets ─────────────────────────────────────────────────
// جلب تذاكر المستخدم الحالي
exports.getMyTickets = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Not signed in.");

  const snap = await db
    .collection("supportTickets")
    .where("senderId", "==", uid)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  const tickets = snap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      ...d,
      createdAt: d.createdAt?.toMillis() ?? null,
      updatedAt: d.updatedAt?.toMillis() ?? null,
    };
  });

  return { tickets };
});

// ─── getAllTickets ────────────────────────────────────────────────
// جلب كل التذاكر للأدمن مع فلترة اختيارية
exports.getAllTickets = onCall(publicCallableOpts, async (request) => {
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
  const tickets = snap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      ...d,
      createdAt: d.createdAt?.toMillis() ?? null,
      updatedAt: d.updatedAt?.toMillis() ?? null,
    };
  });

  return { tickets };
});

// ─── updateTicketStatus ───────────────────────────────────────────
// تغيير حالة التذكرة (أدمن فقط)
exports.updateTicketStatus = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  await requireAdmin(uid);

  const data = request.data || {};
  const ticketId = String(data.ticketId || "").trim();
  const newStatus = String(data.status || "").trim();

  if (!ticketId) {
    throw new HttpsError("invalid-argument", "ticketId is required.");
  }

  const valid = ["open", "inProgress", "resolved", "closed"];

  if (!valid.includes(newStatus)) {
    throw new HttpsError("invalid-argument", "Invalid status.");
  }

  await db.collection("supportTickets").doc(ticketId).update({
    status: newStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

// ─── deleteTicket ─────────────────────────────────────────────────
exports.deleteSupportTicket = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  await requireAdmin(uid);

  const ticketId = String(request.data?.ticketId || "").trim();
  if (!ticketId) {
    throw new HttpsError("invalid-argument", "ticketId is required.");
  }

  // Remove every in-app notification tied to this ticket (sender + admin, etc.).
  const notifSnap = await db
    .collectionGroup("user_notifications")
    .where("ticketId", "==", ticketId)
    .get();

  const batchSize = 500;
  if (!notifSnap.empty) {
    for (let i = 0; i < notifSnap.docs.length; i += batchSize) {
      const batch = db.batch();
      for (
        let j = i;
        j < Math.min(i + batchSize, notifSnap.docs.length);
        j += 1
      ) {
        batch.delete(notifSnap.docs[j].ref);
      }
      await batch.commit();
    }
  }

  await db.collection("supportTickets").doc(ticketId).delete();
  return {
    ok: true,
    deletedNotifications: notifSnap.docs.length,
  };
});

// ─── countOpenTickets ─────────────────────────────────────────────
exports.countOpenTickets = onCall(publicCallableOpts, async (request) => {
  const uid = request.auth?.uid;
  await requireAdmin(uid);

  const snap = await db
    .collection("supportTickets")
    .where("status", "==", "open")
    .count()
    .get();

  return { count: snap.data().count ?? 0 };
});
