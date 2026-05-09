const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const opts = { invoker: "public" };

// ─── getPendingApprovals ──────────────────────────────────────
exports.getPendingApprovals = onCall(opts, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Not signed in.");
  }

  const callerDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }

  const snapshot = await admin
    .firestore()
    .collection("pending_profiles")
    .where("status", "==", "awaiting_admin_approval")
    .orderBy("createdAt", "desc")
    .get();

  const pending = snapshot.docs.map((doc) => ({
    uid: doc.id,
    ...doc.data(),
    createdAt: doc.data().createdAt?.toMillis() ?? null,
  }));

  return { pending };
});

// ─── approvePendingUser ───────────────────────────────────────
exports.approvePendingUser = onCall(opts, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Not signed in.");
  }

  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .get();
  if (!callerDoc.exists || callerDoc.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }

  const { uid } = request.data;
  if (!uid) {
    throw new HttpsError("invalid-argument", "uid required.");
  }

  const pendingRef = admin.firestore().collection("pending_profiles").doc(uid);
  const pendingDoc = await pendingRef.get();
  if (!pendingDoc.exists) {
    throw new HttpsError("not-found", "Pending profile not found.");
  }

  const pendingData = pendingDoc.data();

  const batch = admin.firestore().batch();
  batch.set(admin.firestore().collection("users").doc(uid), {
    ...pendingData,
    isApproved: true,
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    approvedBy: callerUid,
    status: "approved",
  });
  batch.delete(pendingRef);
  await batch.commit();

  const fcmToken = pendingData.fcmToken;
  const bloodBankName = pendingData.bloodBankName ?? "Blood Bank";

  if (fcmToken && fcmToken.trim() !== "") {
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Account Approved! 🎉",
          body: `Your blood bank "${bloodBankName}" has been approved. You can now log in and start posting blood requests.`,
        },
        data: { type: "account_approved", uid: uid },
        android: {
          priority: "high",
          notification: { channelId: "general", sound: "default" },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      });
      console.log(`Approval notification sent to ${bloodBankName} (${uid})`);
    } catch (notifErr) {
      console.warn(
        `Could not send approval notification to ${uid}:`,
        notifErr.message,
      );
    }
  } else {
    console.log(`No FCM token for ${uid} — notification skipped`);
  }

  return { success: true };
});

// ─── rejectPendingUser ────────────────────────────────────────
exports.rejectPendingUser = onCall(opts, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Not signed in.");
  }

  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .get();
  if (!callerDoc.exists || callerDoc.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }

  const { uid, reason } = request.data;
  if (!uid) {
    throw new HttpsError("invalid-argument", "uid required.");
  }

  const pendingRef = admin.firestore().collection("pending_profiles").doc(uid);
  const pendingDoc = await pendingRef.get();

  const pendingData = pendingDoc.exists ? pendingDoc.data() : {};
  const fcmToken = pendingData.fcmToken;
  const bloodBankName = pendingData.bloodBankName ?? "Blood Bank";

  if (fcmToken && fcmToken.trim() !== "") {
    try {
      const reasonLine = reason
        ? `\nReason: ${reason}`
        : "\nPlease contact support for more information.";

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Registration Not Approved",
          body: `Your blood bank "${bloodBankName}" registration was not approved.${reasonLine}`,
        },
        data: { type: "account_rejected", uid: uid, reason: reason ?? "" },
        android: {
          priority: "high",
          notification: { channelId: "general", sound: "default" },
        },
      });
    } catch (notifErr) {
      console.warn(
        `Could not send rejection notification to ${uid}:`,
        notifErr.message,
      );
    }
  }

  if (pendingDoc.exists) {
    await pendingRef.delete();
  }

  try {
    await admin.auth().deleteUser(uid);
  } catch (e) {
    // ignored
  }

  await admin
    .firestore()
    .collection("rejected_profiles")
    .doc(uid)
    .set({
      uid,
      bloodBankName,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectedBy: callerUid,
      reason: reason ?? null,
    });

  return { success: true };
});
