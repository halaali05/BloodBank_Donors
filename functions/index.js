const admin = require("firebase-admin");
const functions = require("firebase-functions");
admin.initializeApp();
const db = admin.firestore();

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");

setGlobalOptions({ region: "us-central1" });

/**
 * Require authenticated caller (v2 callable uses request.auth).
 * @param {object} request onCall request
 * @return {string} uid
 */
function requireAuth(request) {
  if (!request || !request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }
  return request.auth.uid;
}

/**
 * Validate a non-empty string.
 * @param {*} v value
 * @param {string} field field name
 * @return {string} trimmed string
 */
function nonEmptyString(v, field) {
  if (typeof v !== "string" || v.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return v.trim();
}

/**
 * Convert unknown errors to HttpsError.
 * @param {*} err error
 * @param {string} fallbackMessage fallback message
 * @return {HttpsError} https error
 */
function toHttpsError(err, fallbackMessage) {
  if (err instanceof HttpsError) return err;

  const msg =
    err && typeof err.message === "string" && err.message.trim()
      ? err.message.trim()
      : fallbackMessage || "Server error occurred.";

  return new HttpsError("internal", msg);
}

/**
 * createPendingProfile
 * Writes ONLY to pending_profiles/{uid}.
 */
exports.createPendingProfile = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const userRecord = await admin.auth().getUser(uid);
    const emailVerified = userRecord.emailVerified === true;

    const role = nonEmptyString(data.role, "role");
    if (role !== "donor" && role !== "hospital") {
      throw new HttpsError(
        "invalid-argument",
        "role must be donor or hospital"
      );
    }

    const payload = {
      role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (role === "donor") {
      payload.fullName = nonEmptyString(data.fullName, "fullName");
      payload.bloodType = nonEmptyString(data.bloodType, "bloodType");
      payload.location = nonEmptyString(data.location, "location");
      payload.medicalFileUrl =
        typeof data.medicalFileUrl === "string"
          ? data.medicalFileUrl.trim()
          : null;
    } else {
      payload.bloodBankName = nonEmptyString(
        data.bloodBankName,
        "bloodBankName"
      );
      payload.location = nonEmptyString(data.location, "location");
    }

    await db
      .collection("pending_profiles")
      .doc(uid)
      .set(payload, { merge: true });

    return {
      ok: true,
      emailVerified,
      message: emailVerified
        ? "Email already verified. You can complete your profile."
        : "Pending profile saved. Please verify your email.",
    };
  } catch (err) {
    console.error("[createPendingProfile] ERROR:", err);
    throw toHttpsError(err, "Failed to save profile data.");
  }
});

/**
 * completeProfileAfterVerification
 * Moves pending_profiles/{uid} -> users/{uid} only if email verified.
 */
exports.completeProfileAfterVerification = onCall(async (request) => {
  try {
    const uid = requireAuth(request);

    const userRecord = await admin.auth().getUser(uid);
    if (!userRecord.emailVerified) {
      throw new HttpsError("failed-precondition", "Email is not verified yet.");
    }

    const pendingRef = db.collection("pending_profiles").doc(uid);
    const userRef = db.collection("users").doc(uid);

    const pendingSnap = await pendingRef.get();

    if (!pendingSnap.exists) {
      const userSnap = await userRef.get();
      if (userSnap.exists) {
        return { ok: true, message: "Profile already completed." };
      }
      throw new HttpsError("not-found", "No pending profile found.");
    }

    const pendingData = pendingSnap.data() || {};

    await db.runTransaction(async (tx) => {
      tx.set(
        userRef,
        {
          ...pendingData,
          email: userRecord.email || null,
          emailVerified: true,
          emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          activatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      tx.delete(pendingRef);
    });

    if (pendingData && pendingData.role) {
      await admin.auth().setCustomUserClaims(uid, { role: pendingData.role });
    }

    return { ok: true, message: "Profile activated." };
  } catch (err) {
    console.error("[completeProfileAfterVerification] ERROR:", err);
    throw toHttpsError(err, "Failed to activate profile.");
  }
});

/**
 * getUserData (final profile)
 */
exports.getUserData = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const targetUid = typeof data.uid === "string" ? data.uid : uid;

    if (targetUid !== uid) {
      throw new HttpsError("permission-denied", "Not allowed.");
    }

    const snap = await db.collection("users").doc(targetUid).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const d = snap.data() || {};

    // ✅ normalize timestamps to millis (safe for Flutter)
    const toMillis = (v) =>
      v && typeof v.toMillis === "function" ? v.toMillis() : null;

    return {
      uid: targetUid,
      ...d,
      createdAt: toMillis(d.createdAt),
      activatedAt: toMillis(d.activatedAt),
      emailVerifiedAt: toMillis(d.emailVerifiedAt),
    };
  } catch (err) {
    console.error("[getUserData] ERROR:", err);
    throw toHttpsError(err, "Failed to load user profile.");
  }
});

/**
 * getUserRole (final profile)
 */
exports.getUserRole = onCall(async (request) => {
  try {
    const uid = requireAuth(request);

    const snap = await db.collection("users").doc(uid).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const d = snap.data() || {};
    return { role: d.role || "" };
  } catch (err) {
    console.error("[getUserRole] ERROR:", err);
    throw toHttpsError(err, "Failed to load user role.");
  }
});

/**
 * addRequest - hospitals only
 */
exports.addRequest = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const userSnap = await db.collection("users").doc(uid).get();
    const ud = userSnap.exists ? userSnap.data() || {} : {};

    if (!userSnap.exists || ud.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can create blood requests"
      );
    }

    const requestId = nonEmptyString(data.requestId, "requestId");
    const bloodBankName = nonEmptyString(data.bloodBankName, "bloodBankName");
    const bloodType = nonEmptyString(data.bloodType, "bloodType");

    const units =
      typeof data.units === "number" ? data.units : parseInt(data.units, 10);
    if (isNaN(units) || units < 1) {
      throw new HttpsError(
        "invalid-argument",
        "units must be a positive number"
      );
    }

    const isUrgent = data.isUrgent === true;
    const hospitalLocation = nonEmptyString(
      data.hospitalLocation,
      "hospitalLocation"
    );
    const details = typeof data.details === "string" ? data.details.trim() : "";

    await db.collection("requests").doc(requestId).set({
      bloodBankId: uid,
      bloodBankName,
      bloodType,
      units,
      isUrgent,
      details,
      hospitalLocation,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ✅ Notifications and messages are handled by the trigger (sendRequestMessageToDonors)
    // This ensures they are created reliably when the request document is created
    console.log(
      `[addRequest] Request ${requestId} created. Notifications and messages will be created by trigger.`
    );

    return {
      ok: true,
      message:
        "Request created and personalized messages sent to all matching donors.",
    };
  } catch (err) {
    console.error("[addRequest] ERROR:", err);
    throw toHttpsError(err, "Failed to create request.");
  }
});

/**
 * getDonors - Get list of all donors (hospitals only)
 * Optional: filter by bloodType if provided
 */
exports.getDonors = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    // Verify user is a hospital
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    if (userData.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can view donor lists."
      );
    }

    // bloodType is optional - if not provided, get all donors
    const bloodType =
      typeof data.bloodType === "string" && data.bloodType.trim() !== ""
        ? data.bloodType.trim()
        : null;

    let query = db.collection("users").where("role", "==", "donor");

    if (bloodType) {
      query = query.where("bloodType", "==", bloodType);
      console.log(
        `[getDonors] Hospital ${uid} requesting donors with blood type: ${bloodType}`
      );
    } else {
      console.log(`[getDonors] Hospital ${uid} requesting all donors`);
    }

    const donorsSnapshot = await query.get();

    console.log(
      `[getDonors] Found ${donorsSnapshot.size} donors${
        bloodType ? ` with blood type ${bloodType}` : ""
      }`
    );

    const donors = donorsSnapshot.docs.map((doc) => {
      const donorData = doc.data();
      return {
        id: doc.id,
        fullName: donorData.fullName || donorData.name || "Donor",
        location: donorData.location || "Unknown location",
        bloodType: donorData.bloodType || "",
        email: donorData.email || "",
      };
    });

    return {
      ok: true,
      donors: donors,
      count: donors.length,
    };
  } catch (err) {
    console.error("[getDonors] ERROR:", err);
    throw toHttpsError(err, "Failed to get donors list.");
  }
});

/**
 * getRequests - pagination
 */
exports.getRequests = onCall(async (request) => {
  try {
    requireAuth(request);
    const data = request.data || {};

    const limit =
      typeof data.limit === "number" ? Math.min(data.limit, 100) : 50;
    const lastRequestId =
      typeof data.lastRequestId === "string" ? data.lastRequestId : null;

    let query = db
      .collection("requests")
      .orderBy("createdAt", "desc")
      .limit(limit);

    if (lastRequestId) {
      const lastDoc = await db.collection("requests").doc(lastRequestId).get();
      if (lastDoc.exists) query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    const requests = snapshot.docs.map((doc) => {
      const d = doc.data() || {};
      return {
        id: doc.id,
        ...d,
        createdAt:
          d.createdAt && typeof d.createdAt.toMillis === "function"
            ? d.createdAt.toMillis()
            : null,
      };
    });

    return { requests, hasMore: snapshot.docs.length === limit };
  } catch (err) {
    console.error("[getRequests] ERROR:", err);
    throw toHttpsError(err, "Failed to load requests.");
  }
});

/**
 * markNotificationsAsRead - mark all unread notifications as read for a user
 */
exports.markNotificationsAsRead = onCall(async (request) => {
  try {
    const uid = requireAuth(request);

    const snapshot = await db
      .collection("notifications")
      .doc(uid)
      .collection("user_notifications")
      .where("read", "==", false)
      .get();

    if (snapshot.empty) {
      return { ok: true, message: "No unread notifications.", count: 0 };
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, { read: true });
    });

    await batch.commit();

    return {
      ok: true,
      message: `Marked ${snapshot.docs.length} notification(s) as read.`,
      count: snapshot.docs.length,
    };
  } catch (err) {
    console.error("[markNotificationsAsRead] ERROR:", err);
    throw toHttpsError(err, "Failed to mark notifications as read.");
  }
});

/**
 * markNotificationAsRead - mark a single notification as read for a user
 */
exports.markNotificationAsRead = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const notificationId = nonEmptyString(
      data.notificationId,
      "notificationId"
    );

    const notificationRef = db
      .collection("notifications")
      .doc(uid)
      .collection("user_notifications")
      .doc(notificationId);

    const notificationSnap = await notificationRef.get();
    if (!notificationSnap.exists) {
      throw new HttpsError("not-found", "Notification not found.");
    }

    // Update both read and isRead fields for compatibility
    await notificationRef.update({
      read: true,
      isRead: true,
    });

    return { ok: true, message: "Notification marked as read." };
  } catch (err) {
    console.error("[markNotificationAsRead] ERROR:", err);
    throw toHttpsError(err, "Failed to mark notification as read.");
  }
});

/**
 * deleteNotification - delete a specific notification
 */
exports.deleteNotification = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const notificationId = nonEmptyString(
      data.notificationId,
      "notificationId"
    );

    const notificationRef = db
      .collection("notifications")
      .doc(uid)
      .collection("user_notifications")
      .doc(notificationId);

    const notificationSnap = await notificationRef.get();
    if (!notificationSnap.exists) {
      throw new HttpsError("not-found", "Notification not found.");
    }

    await notificationRef.delete();

    return { ok: true, message: "Notification deleted." };
  } catch (err) {
    console.error("[deleteNotification] ERROR:", err);
    throw toHttpsError(err, "Failed to delete notification.");
  }
});

/**
 * sendMessage - send a message in a request chat
 */
exports.sendMessage = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const requestId = nonEmptyString(data.requestId, "requestId");
    const text = nonEmptyString(data.text, "text");

    // Get user role
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    const senderRole = userData.role || "donor";

    // Verify request exists
    const requestRef = db.collection("requests").doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }

    // Add message to the request's messages subcollection
    await requestRef.collection("messages").add({
      text: text.trim(),
      senderId: uid,
      senderRole: senderRole,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      ok: true,
      message: "Message sent successfully.",
    };
  } catch (err) {
    console.error("[sendMessage] ERROR:", err);
    throw toHttpsError(err, "Failed to send message.");
  }
});

/**
 * deleteRequest - delete a blood request (hospitals only, must own the request)
 */
exports.deleteRequest = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const requestId = nonEmptyString(data.requestId, "requestId");

    console.log("[deleteRequest] Called with Request ID:", requestId, "by User UID:", uid);

    // تحقق من أن المستخدم مستشفى
    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};
    if (!userSnap.exists || userData.role !== "hospital") {
      throw new HttpsError("permission-denied", "Only hospitals can delete requests.");
    }

    // تحقق من أن الطلب موجود وينتمي للمستشفى
    const requestRef = db.collection("requests").doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }
    const requestData = requestSnap.data() || {};
    if (requestData.bloodBankId !== uid) {
      throw new HttpsError("permission-denied", "You can only delete your own requests.");
    }

    // =========================
    // 1️⃣ حذف الرسائل الفرعية
    // =========================
    const messagesSnapshot = await requestRef.collection("messages").get();
    if (!messagesSnapshot.empty) {
      const batchSize = 500;
      for (let i = 0; i < messagesSnapshot.docs.length; i += batchSize) {
        const batch = db.batch();
        messagesSnapshot.docs.slice(i, i + batchSize).forEach(doc => batch.delete(doc.ref));
        await batch.commit();
      }
      console.log(`[deleteRequest] Deleted ${messagesSnapshot.size} messages`);
    }

    // =========================
    // 2️⃣ حذف الطلب نفسه
    // =========================
    await requestRef.delete();
    console.log("[deleteRequest] Request deleted successfully");

    // =========================
    // 3️⃣ حذف الإشعارات المرتبطة بالطلب لكل المستخدمين
    // =========================
    const usersSnapshot = await db.collection("users").get();
    const notifPromises = [];
    let notificationsDeleted = 0;

    for (const userDoc of usersSnapshot.docs) {
      const notificationsRef = db
        .collection("notifications")
        .doc(userDoc.id)
        .collection("user_notifications");
      const userNotifs = await notificationsRef.where("requestId", "==", requestId).get();
      if (!userNotifs.empty) {
        const batch = db.batch();
        userNotifs.docs.forEach(doc => {
          batch.delete(doc.ref);
          notificationsDeleted++;
        });
        notifPromises.push(batch.commit());
      }
    }

    if (notifPromises.length > 0) await Promise.all(notifPromises);
    console.log(`[deleteRequest] Deleted ${notificationsDeleted} notification(s)`);

    return {
      ok: true,
      message:
        notificationsDeleted > 0
          ? `Request, messages, and ${notificationsDeleted} notification(s) deleted successfully.`
          : "Request and messages deleted successfully.",
    };

  } catch (err) {
    console.error("[deleteRequest] ERROR:", err);
    throw toHttpsError(err, `Failed to delete request: ${err.message || "Unknown error"}`);
  }
});


/* =======================
   ✅ Cleanup: Pending Accounts
   ======================= */

/**
 * Delete pending doc + auth user.
 * Also delete users doc just in case (safe cleanup).
 * @param {string} uid uid
 * @return {Promise<void>}
 */
async function deletePendingUser(uid) {
  await Promise.allSettled([
    db.collection("pending_profiles").doc(uid).delete(),
    db.collection("users").doc(uid).delete(),
  ]);
  await admin.auth().deleteUser(uid);
}

/**
 * Scheduled cleanup:
 * deletes users with emailVerified=false older than DAYS.
 */
exports.cleanupUnverifiedUsers = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "Asia/Amman",
    region: "us-central1",
  },
  async () => {
    const DAYS = 2; // ✅ غيريها
    const cutoffMs = Date.now() - DAYS * 24 * 60 * 60 * 1000;

    let nextPageToken = undefined;
    let scanned = 0;
    let deleted = 0;

    do {
      const res = await admin.auth().listUsers(1000, nextPageToken);
      nextPageToken = res.pageToken;

      for (const user of res.users) {
        scanned++;

        if (user.emailVerified) continue;

        const createdStr =
          user.metadata && user.metadata.creationTime
            ? user.metadata.creationTime
            : null;

        const createdMs = createdStr ? Date.parse(createdStr) : NaN;
        if (!Number.isFinite(createdMs)) continue;

        if (createdMs < cutoffMs) {
          try {
            await deletePendingUser(user.uid);
            deleted++;
          } catch (e) {
            console.error("[cleanupUnverifiedUsers] Failed:", user.uid, e);
          }
        }
      }
    } while (nextPageToken);

    console.log("[cleanupUnverifiedUsers] done", {
      scanned,
      deleted,
      days: DAYS,
    });
  }
);

/* =========================
   ✅ Cleanup: Orphan Notifications
========================= */
exports.cleanupOrphanNotifications = onSchedule(
  {
    schedule: "35 5 * * *", // كل يوم الساعة 4 صباحًا
    timeZone: "Asia/Amman",
    region: "us-central1",
  },
  async () => {
    console.log("[cleanupOrphanNotifications] started");

    try {
      const usersSnapshot = await db.collection("users").get();
      let totalDeleted = 0;

      for (const userDoc of usersSnapshot.docs) {
        const uid = userDoc.id;
        const notificationsRef = db
          .collection("notifications")
          .doc(uid)
          .collection("user_notifications");

        // استعلام للإشعارات التي ليس لها requestId
        const orphanSnap = await notificationsRef
          .where("requestId", "==", null)
          .get();

        if (!orphanSnap.empty) {
          const batch = db.batch();
          orphanSnap.docs.forEach((doc) => {
            batch.delete(doc.ref);
            totalDeleted++;
          });
          await batch.commit();
          console.log(`[cleanupOrphanNotifications] 
              deleted ${orphanSnap.docs.length}
               orphan notifications for user ${uid}`);
        }
      }

      console.log(`[cleanupOrphanNotifications]
           done. Total deleted: ${totalDeleted}`);
    } catch (err) {
      console.error("[cleanupOrphanNotifications] ERROR:", err);
    }
  }
);
exports.sendRequestMessageToDonors = onDocumentCreated(
  {
    document: "requests/{requestId}",
    // Note: Firestore triggers work across regions, so us-central1 is fine
    // even though Firestore is in nam5
  },
  async (event) => {
    try {
      console.log("[sendRequestMessageToDonors] Trigger fired");
      const data = event.data?.data();
      if (!data) {
        console.log("[sendRequestMessageToDonors] No data in event, exiting");
        return;
      }

      const requestId = event.params.requestId;
      const bloodType = data.bloodType;
      const bloodBankId = data.bloodBankId;

      console.log(
        `[sendRequestMessageToDonors] Processing request: ${requestId}, bloodType: ${bloodType}, bloodBankId: ${bloodBankId}`
      );

      const requestRef = db.collection("requests").doc(requestId);

      // Get ALL donors for notifications
      const allDonorsSnapshot = await db
        .collection("users")
        .where("role", "==", "donor")
        .get();

      // Get matching donors for personalized messages
      const matchingDonorsSnapshot = await db
        .collection("users")
        .where("role", "==", "donor")
        .where("bloodType", "==", bloodType)
        .get();

      console.log(
        `[sendRequestMessageToDonors] Found ${allDonorsSnapshot.size} total donors and ${matchingDonorsSnapshot.size} matching donors with blood type ${bloodType}`
      );

      if (allDonorsSnapshot.empty) {
        console.log("[sendRequestMessageToDonors] No donors found, exiting");
        return;
      }

      const tokens = [];
      const MAX_BATCH_SIZE = 500; // Firestore batch limit
      let notificationBatch = db.batch();
      let messageBatch = db.batch();
      let notificationBatchCount = 0;
      let messageBatchCount = 0;
      const batchPromises = [];

      // Create notifications for ALL donors
      for (const donorDoc of allDonorsSnapshot.docs) {
        const donorData = donorDoc.data();
        const donorId = donorDoc.id;
        const donorName = donorData.fullName || donorData.name || "Donor";

        console.log(
          `[sendRequestMessageToDonors] Processing notification for donor: ${donorName} (${donorId})`
        );

        if (donorData.fcmToken) tokens.push(donorData.fcmToken);

        // Create notification for each donor (ALL donors)
        const notificationRef = db
          .collection("notifications")
          .doc(donorId)
          .collection("user_notifications")
          .doc();

        notificationBatch.set(notificationRef, {
          title: `Blood request: ${bloodType}`,
          body: `Please ${donorName} donate as soon as possible ❤️`,
          requestId: requestId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });
        notificationBatchCount++;

        // Commit notification batch if it reaches the limit
        if (notificationBatchCount >= MAX_BATCH_SIZE) {
          batchPromises.push(notificationBatch.commit());
          notificationBatch = db.batch();
          notificationBatchCount = 0;
        }
      }

      // Create personalized messages for ALL donors
      for (const donorDoc of allDonorsSnapshot.docs) {
        const donorData = donorDoc.data();
        const donorId = donorDoc.id;
        const donorName = donorData.fullName || donorData.name || "Donor";

        console.log(
          `[sendRequestMessageToDonors] Processing personalized message for donor: ${donorName} (${donorId})`
        );

        // Create personalized message for ALL donors
        const messageRef = requestRef.collection("messages").doc();
        messageBatch.set(messageRef, {
          senderId: bloodBankId,
          senderRole: "hospital",
          text: `Please ${donorName} donate as soon as possible ❤️`,
          recipientId: donorId, // Track which donor this message is for
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        messageBatchCount++;

        // Commit message batch if it reaches the limit
        if (messageBatchCount >= MAX_BATCH_SIZE) {
          batchPromises.push(messageBatch.commit());
          messageBatch = db.batch();
          messageBatchCount = 0;
        }
      }

      // Commit remaining notification batch
      if (notificationBatchCount > 0) {
        batchPromises.push(notificationBatch.commit());
      }

      // Commit remaining message batch
      if (messageBatchCount > 0) {
        batchPromises.push(messageBatch.commit());
      }

      // Wait for all batches to complete
      if (batchPromises.length > 0) {
        await Promise.all(batchPromises);
        console.log(
          `[sendRequestMessageToDonors] ✅ Successfully created ${allDonorsSnapshot.size} notifications for all donors`
        );
        console.log(
          `[sendRequestMessageToDonors] ✅ Successfully created ${allDonorsSnapshot.size} personalized messages for all donors`
        );
      } else {
        console.log(`[sendRequestMessageToDonors] ⚠️ No batches to commit`);
      }

      // إرسال إشعار Push Notification للمتبرعين
      // ✅ Push Notification to ALL donors (no device filtering)

      // 1) remove null/empty + de-duplicate
      const uniqueTokens = [...new Set(tokens)].filter(
        (t) => typeof t === "string" && t.trim().length > 0
      );

      async function sendInChunks(arr, size, fn) {
        for (let i = 0; i < arr.length; i += size) {
          await fn(arr.slice(i, i + size));
        }
      }

      if (uniqueTokens.length > 0) {
        const title = data.isUrgent
          ? "Urgent blood request"
          : "New blood request";
        const body = `${data.bloodBankName || "Blood Bank"} needs ${
          data.units || ""
        } units (${bloodType})`;

        await sendInChunks(uniqueTokens, 500, async (chunk) => {
          const res = await admin.messaging().sendEachForMulticast({
            tokens: chunk,
            notification: { title, body },
            data: {
              type: "request",
              requestId,
              bloodType,
              isUrgent: data.isUrgent ? "true" : "false",
            },
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default" } } },
          });

          console.log(
            "[Push] sent:",
            res.successCount,
            "failed:",
            res.failureCount
          );

          // (Optional) log failures
          res.responses.forEach((r, idx) => {
            if (!r.success) {
              console.log("[Push] failed token:", chunk[idx], r.error?.message);
            }
          });
        });
      } else {
        console.log("[Push] No tokens found for donors.");
      }

      console.log(
        `[sendRequestMessageToDonors] Successfully sent notifications and personalized messages to ${allDonorsSnapshot.size} donors`
      );
    } catch (err) {
      console.error("[sendRequestMessageToDonors] ERROR:", err);
      console.error("[sendRequestMessageToDonors] Error stack:", err.stack);
      // Don't throw - we don't want to fail the request creation
    }
  }
);

// cleanupOrphanMessages حذف الرسائل الموجودة مسبقا بدون طلبات بالفيربيس 
exports.cleanupOrphanMessages = onSchedule(
  {
    schedule: "0 4 * * *", // كل يوم الساعة 4 صباحًا
    timeZone: "Asia/Amman",
    region: "us-central1",
  },
  async () => {
    console.log("[cleanupOrphanMessages] started");

    try {
      const requestsSnapshot = await db.collection("requests").get();
      const existingRequestIds = requestsSnapshot.docs.map(doc => doc.id);

      // احصل على جميع المستندات تحت requests
      const allRequestsSnapshot = await db.collection("requests").get();

      let totalDeleted = 0;

      // افحص كل الطلبات القديمة
      for (const requestDoc of allRequestsSnapshot.docs) {
        const requestId = requestDoc.id;

        // إذا هذا الطلب موجود، تجاهل
        if (existingRequestIds.includes(requestId)) continue;

        // احصل على جميع الرسائل تحت هذا الطلب
        const messagesRef = db.collection("requests").doc(requestId).collection("messages");
        const messagesSnapshot = await messagesRef.get();

        if (!messagesSnapshot.empty) {
          const batchSize = 500;
          for (let i = 0; i < messagesSnapshot.docs.length; i += batchSize) {
            const batch = db.batch();
            messagesSnapshot.docs.slice(i, i + batchSize).forEach(doc => {
              batch.delete(doc.ref);
              totalDeleted++;
            });
            await batch.commit();
          }
          console.log(`[cleanupOrphanMessages] Deleted ${messagesSnapshot.size} orphan messages for request ${requestId}`);
        }
      }

      console.log(`[cleanupOrphanMessages] done. Total orphan messages deleted: ${totalDeleted}`);
    } catch (err) {
      console.error("[cleanupOrphanMessages] ERROR:", err);
    }
  }
); 
