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
    err && typeof err.message === "string" && err.message.trim() ?
      err.message.trim() :
      fallbackMessage || "Server error occurred.";

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
        "role must be donor or hospital",
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
        typeof data.medicalFileUrl === "string" ?
          data.medicalFileUrl.trim() :
          null;
    } else {
      payload.bloodBankName = nonEmptyString(
        data.bloodBankName,
        "bloodBankName",
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
      message: emailVerified ?
        "Email already verified. You can complete your profile." :
        "Pending profile saved. Please verify your email.",
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
        { merge: true },
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
        "Only hospitals can create blood requests",
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
        "units must be a positive number",
      );
    }

    const isUrgent = data.isUrgent === true;
    const hospitalLocation = nonEmptyString(
      data.hospitalLocation,
      "hospitalLocation",
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

    // ✅ Create personalized messages for all matching donors
    // Notifications will be created by the sendRequestMessageToDonors trigger
    console.log(
      `[addRequest] Searching for donors with blood type: ${bloodType}`
    );

    const donorsSnapshot = await db
      .collection("users")
      .where("role", "==", "donor")
      .where("bloodType", "==", bloodType)
      .get();

    console.log(
      `[addRequest] Found ${donorsSnapshot.size} donors with blood type ${bloodType}`
    );

    if (donorsSnapshot.empty) {
      console.log(
        `[addRequest] No donors found with blood type ${bloodType}, skipping message creation`
      );
    } else {
      // Prepare personalized chat messages only
      // Notifications are handled by the trigger
      const messageOps = [];

      donorsSnapshot.docs.forEach((doc) => {
        try {
          const donorData = doc.data();
          const donorId = doc.id;
          const donorName = donorData.fullName || donorData.name || "Donor";

          console.log(
            `[addRequest] Processing donor: ${donorName} (${donorId})`
          );

          // Prepare personalized chat message
          const messageRef = db
            .collection("requests")
            .doc(requestId)
            .collection("messages")
            .doc();

          messageOps.push({
            ref: messageRef,
            data: {
              senderId: uid, // From the hospital
              senderRole: "hospital",
              text: `Please ${donorName} donate and save a life ❤️`,
              recipientId: donorId, // Track which donor this message is for
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          });
        } catch (donorErr) {
          console.error(
            `[addRequest] Error processing donor ${doc.id}:`,
            donorErr
          );
        }
      });

      // Commit messages in batches if needed
      const MAX_BATCH_SIZE = 500;

      if (messageOps.length > 0) {
        console.log(
          `[addRequest] Preparing to create ${messageOps.length} personalized messages in batches`
        );

        try {
          for (let i = 0; i < messageOps.length; i += MAX_BATCH_SIZE) {
            const batch = db.batch();
            const chunk = messageOps.slice(i, i + MAX_BATCH_SIZE);
            const batchNumber = Math.floor(i / MAX_BATCH_SIZE) + 1;

            console.log(
              `[addRequest] Creating batch ${batchNumber} with ${chunk.length} messages`
            );

            chunk.forEach((op) => {
              batch.set(op.ref, op.data);
            });

            await batch.commit();
            console.log(
              `[addRequest] ✅ Successfully committed message batch ${batchNumber} (${chunk.length} messages)`
            );
          }

          console.log(
            `[addRequest] ✅ Successfully created ALL ${messageOps.length} personalized messages`
          );
        } catch (batchErr) {
          console.error(`[addRequest] ❌ CRITICAL ERROR committing message batches:`, batchErr);
          console.error(`[addRequest] Batch error details:`, {
            messageCount: messageOps.length,
            error: batchErr.message,
            stack: batchErr.stack,
          });
          // Don't throw - request is already created
          // Log the error but continue - the trigger may create messages as backup
          // However, this is a critical error that should be investigated
          console.error(
            `[addRequest] ⚠️ WARNING: Request ${requestId} was created but ${messageOps.length} personalized messages failed to be created!`
          );
        }
      } else {
        console.log(`[addRequest] ⚠️ No messages to create (no matching donors found)`);
      }
    }

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
        "Only hospitals can view donor lists.",
      );
    }

    // bloodType is optional - if not provided, get all donors
    const bloodType = typeof data.bloodType === "string" && data.bloodType.trim() !== ""
      ? data.bloodType.trim()
      : null;

    let query = db.collection("users").where("role", "==", "donor");

    if (bloodType) {
      query = query.where("bloodType", "==", bloodType);
      console.log(
        `[getDonors] Hospital ${uid} requesting donors with blood type: ${bloodType}`
      );
    } else {
      console.log(
        `[getDonors] Hospital ${uid} requesting all donors`
      );
    }

    const donorsSnapshot = await query.get();

    console.log(
      `[getDonors] Found ${donorsSnapshot.size} donors${bloodType ? ` with blood type ${bloodType}` : ""}`
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
          d.createdAt && typeof d.createdAt.toMillis === "function" ?
            d.createdAt.toMillis() :
            null,
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
 * deleteNotification - delete a specific notification
 */
exports.deleteNotification = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const notificationId = nonEmptyString(
      data.notificationId,
      "notificationId",
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

    console.log("[deleteRequest] Called with data:", JSON.stringify(data));

    const requestId = nonEmptyString(data.requestId, "requestId");
    console.log("[deleteRequest] Request ID:", requestId);
    console.log("[deleteRequest] User UID:", uid);

    // Check if user is a hospital
    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};

    if (!userSnap.exists || userData.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can delete requests.",
      );
    }

    // Check if request exists and belongs to this hospital
    const requestRef = db.collection("requests").doc(requestId);
    const requestSnap = await requestRef.get();

    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }

    const requestData = requestSnap.data() || {};
    if (requestData.bloodBankId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You can only delete your own requests.",
      );
    }

    // Delete the request (main operation)
    console.log("[deleteRequest] Deleting request document:", requestId);
    await requestRef.delete();
    console.log("[deleteRequest] Request deleted successfully");

    // Try to delete notifications (optional - won't block if it fails)
    // We'll iterate through all users and check their notifications
    // This avoids needing a collectionGroup index
    let notificationsDeleted = 0;
    try {
      // Get all users to check their notifications
      const usersSnapshot = await db.collection("users").get();
      const deletePromises = [];

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const notificationsRef = db
          .collection("notifications")
          .doc(userId)
          .collection("user_notifications");

        // Get notifications for this user that match the requestId
        const userNotifications = await notificationsRef
          .where("requestId", "==", requestId)
          .get();

        // Delete each notification
        userNotifications.docs.forEach((notifDoc) => {
          deletePromises.push(notifDoc.ref.delete());
          notificationsDeleted++;
        });
      }

      // Wait for all deletions to complete
      if (deletePromises.length > 0) {
        await Promise.all(deletePromises);
      }

      console.log(
        `[deleteRequest] Deleted ${notificationsDeleted} notification(s)`,
      );
    } catch (notifErr) {
      // If notification deletion fails, log but continue
      // The request is already deleted, so this is just cleanup
      console.warn(
        "[deleteRequest] Could not delete all notifications:",
        notifErr.message || notifErr,
      );
    }

    return {
      ok: true,
      message:
        notificationsDeleted > 0 ?
          `Request and ${notificationsDeleted} notification(s) deleted.` :
          "Request deleted successfully.",
    };
  } catch (err) {
    console.error("[deleteRequest] ERROR:", err);
    console.error("[deleteRequest] Error type:", typeof err);
    console.error("[deleteRequest] Error details:", {
      message: err.message,
      code: err.code,
      name: err.name,
      stack: err.stack,
    });

    // If it's already an HttpsError, rethrow it with original message
    if (err instanceof HttpsError) {
      console.error(
        "[deleteRequest] Re-throwing HttpsError:",
        err.code,
        err.message,
      );
      throw err;
    }

    // Provide more specific error message
    const errorMessage = err.message || "Unknown error occurred";
    console.error("[deleteRequest] Converting to HttpsError:", errorMessage);
    throw toHttpsError(err, `Failed to delete request: ${errorMessage}`);
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
          user.metadata && user.metadata.creationTime ?
            user.metadata.creationTime :
            null;

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
  },
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
  });
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

      // استعلام عن المتبرعين لنفس فصيلة الدم
      const donorsSnapshot = await db
        .collection("users")
        .where("role", "==", "donor")
        .where("bloodType", "==", bloodType)
        .get();

      console.log(
        `[sendRequestMessageToDonors] Found ${donorsSnapshot.size} donors with blood type ${bloodType}`
      );

      if (donorsSnapshot.empty) {
        console.log("[sendRequestMessageToDonors] No donors found, exiting");
        return;
      }

      const tokens = [];
      const MAX_BATCH_SIZE = 500; // Firestore batch limit
      let notificationBatch = db.batch();
      let messageBatch = db.batch();
      let notificationBatchCount = 0;
      let messageBatchCount = 0;
      let totalMessagesCreated = 0;
      const batchPromises = [];

      // Check if messages already exist (created by addRequest)
      const existingMessagesSnapshot = await requestRef
        .collection("messages")
        .where("recipientId", "!=", null)
        .limit(1)
        .get();

      const messagesAlreadyExist = !existingMessagesSnapshot.empty;
      console.log(
        `[sendRequestMessageToDonors] Messages already exist: ${messagesAlreadyExist}`
      );

      // Send notifications and messages (messages as backup if not already created)
      for (const donorDoc of donorsSnapshot.docs) {
        const donorData = donorDoc.data();
        const donorId = donorDoc.id;
        const donorName = donorData.fullName || donorData.name || "Donor";

        console.log(
          `[sendRequestMessageToDonors] Processing donor: ${donorName} (${donorId})`
        );

        if (donorData.fcmToken) tokens.push(donorData.fcmToken);

        // Create notification for each donor
        const notificationRef = db
          .collection("notifications")
          .doc(donorId)
          .collection("user_notifications")
          .doc();

        notificationBatch.set(notificationRef, {
          title: `Blood request: ${bloodType}`,
          body: `Please ${donorName} donate and save a life ❤️`,
          requestId: requestId,
          bloodBankName: data.bloodBankName || "Blood Bank",
          isUrgent: data.isUrgent === true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });
        notificationBatchCount++;

        // Create personalized message as backup if not already created by addRequest
        if (!messagesAlreadyExist) {
          const messageRef = requestRef.collection("messages").doc();
          messageBatch.set(messageRef, {
            senderId: bloodBankId,
            senderRole: "hospital",
            text: `Please ${donorName} donate and save a life ❤️`,
            recipientId: donorId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          messageBatchCount++;
          totalMessagesCreated++;
        }

        // Commit notification batch if it reaches the limit
        if (notificationBatchCount >= MAX_BATCH_SIZE) {
          batchPromises.push(notificationBatch.commit());
          notificationBatch = db.batch();
          notificationBatchCount = 0;
        }

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
          `[sendRequestMessageToDonors] ✅ Successfully created ${donorsSnapshot.size} notifications`
        );
        if (!messagesAlreadyExist && totalMessagesCreated > 0) {
          console.log(
            `[sendRequestMessageToDonors] ✅ Successfully created ${totalMessagesCreated} personalized messages as backup`
          );
        } else if (messagesAlreadyExist) {
          console.log(
            `[sendRequestMessageToDonors] ℹ️ Messages already exist, skipped message creation`
          );
        }
      } else {
        console.log(
          `[sendRequestMessageToDonors] ⚠️ No batches to commit`
        );
      }

      // إرسال إشعار Push Notification للمتبرعين
      if (tokens.length > 0) {
        await admin.messaging().sendMulticast({
          tokens: tokens,
          notification: {
            title: `New Blood Request (${bloodType})`,
            body: "Please donate and save a life ❤️",
          },
          data: {
            requestId: requestId,
          },
        });
      }

      console.log(
        `[sendRequestMessageToDonors] Successfully sent messages and notifications to ${donorsSnapshot.size} donors`
      );
    } catch (err) {
      console.error("[sendRequestMessageToDonors] ERROR:", err);
      console.error("[sendRequestMessageToDonors] Error stack:", err.stack);
      // Don't throw - we don't want to fail the request creation
    }
  }
);
