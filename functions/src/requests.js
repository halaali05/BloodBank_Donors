const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { requireAuth, nonEmptyString, toHttpsError } = require("./utils");

const db = admin.firestore();

/**
 * Haversine formula — calculates distance in km between two GPS coordinates.
 * (kept for reference but no longer used for filtering)
 */
function haversineDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * addRequest - hospitals only.
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

    const hospitalLatitude =
      typeof data.hospitalLatitude === "number" ? data.hospitalLatitude : null;
    const hospitalLongitude =
      typeof data.hospitalLongitude === "number"
        ? data.hospitalLongitude
        : null;

    await db.collection("requests").doc(requestId).set({
      bloodBankId: uid,
      bloodBankName,
      bloodType,
      units,
      isUrgent,
      details,
      hospitalLocation,
      hospitalLatitude,
      hospitalLongitude,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(
      `[addRequest] Request ${requestId} created. hospitalLocation=${hospitalLocation}`,
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
 * getDonors - Get list of all donors (hospitals only).
 */
exports.getDonors = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

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

    const bloodType =
      typeof data.bloodType === "string" && data.bloodType.trim() !== ""
        ? data.bloodType.trim()
        : null;

    let query = db.collection("users").where("role", "==", "donor");
    if (bloodType) {
      query = query.where("bloodType", "==", bloodType);
    }

    const donorsSnapshot = await query.get();

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

    return { ok: true, donors, count: donors.length };
  } catch (err) {
    console.error("[getDonors] ERROR:", err);
    throw toHttpsError(err, "Failed to get donors list.");
  }
});

/**
 * getRequests - pagination (all requests for donors).
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
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
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
 * getRequestsByBloodBankId - Get all requests for a specific blood bank.
 */
exports.getRequestsByBloodBankId = onCall(async (request) => {
  try {
    const uid = requireAuth(request);

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    if (userData.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can view their requests.",
      );
    }

    const snapshot = await db
      .collection("requests")
      .where("bloodBankId", "==", uid)
      .orderBy("createdAt", "desc")
      .get();

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

    return { requests, count: requests.length };
  } catch (err) {
    console.error("[getRequestsByBloodBankId] ERROR:", err);
    throw toHttpsError(err, "Failed to load requests.");
  }
});

/**
 * deleteRequest - delete a blood request (hospitals only, must own the request).
 */
exports.deleteRequest = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const requestId = nonEmptyString(data.requestId, "requestId");

    console.log(
      "[deleteRequest] Called with Request ID:",
      requestId,
      "by User UID:",
      uid,
    );

    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};
    if (!userSnap.exists || userData.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can delete requests.",
      );
    }

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

    let notificationsDeleted = 0;

    try {
      const notificationsQuery = db
        .collectionGroup("user_notifications")
        .where("requestId", "==", requestId);
      const notificationsSnapshot = await notificationsQuery.get();

      if (!notificationsSnapshot.empty) {
        const batchSize = 500;
        const deletePromises = [];
        for (let i = 0; i < notificationsSnapshot.docs.length; i += batchSize) {
          const batch = db.batch();
          notificationsSnapshot.docs.slice(i, i + batchSize).forEach((doc) => {
            batch.delete(doc.ref);
            notificationsDeleted++;
          });
          deletePromises.push(batch.commit());
        }
        if (deletePromises.length > 0) {
          await Promise.all(deletePromises);
        }
        console.log(
          `[deleteRequest] Deleted ${notificationsDeleted} notification(s)`,
        );
      }
    } catch (notifError) {
      console.warn(
        `[deleteRequest] Collection group query failed: ${notifError.message}`,
      );
      try {
        const usersSnapshot = await db.collection("users").get();
        const deletePromises = [];
        for (const userDoc of usersSnapshot.docs) {
          const userId = userDoc.id;
          const userNotifSnapshot = await db
            .collection("notifications")
            .doc(userId)
            .collection("user_notifications")
            .where("requestId", "==", requestId)
            .get();
          if (!userNotifSnapshot.empty) {
            const batch = db.batch();
            userNotifSnapshot.docs.forEach((doc) => {
              batch.delete(doc.ref);
              notificationsDeleted++;
            });
            deletePromises.push(batch.commit());
          }
        }
        if (deletePromises.length > 0) {
          await Promise.all(deletePromises);
        }
      } catch (fallbackError) {
        console.error(
          `[deleteRequest] Fallback also failed: ${fallbackError.message}`,
        );
      }
    }

    const messagesSnapshot = await requestRef.collection("messages").get();
    let messagesDeleted = 0;

    if (!messagesSnapshot.empty) {
      const batchSize = 500;
      const messageDeletePromises = [];
      for (let i = 0; i < messagesSnapshot.docs.length; i += batchSize) {
        const batch = db.batch();
        messagesSnapshot.docs.slice(i, i + batchSize).forEach((doc) => {
          batch.delete(doc.ref);
          messagesDeleted++;
        });
        messageDeletePromises.push(batch.commit());
      }
      if (messageDeletePromises.length > 0) {
        await Promise.all(messageDeletePromises);
      }
      console.log(`[deleteRequest] Deleted ${messagesDeleted} message(s)`);
    }

    await requestRef.delete();
    console.log("[deleteRequest] Request document deleted from Firestore");

    return {
      ok: true,
      message:
        notificationsDeleted > 0
          ? `Request, messages, and ${notificationsDeleted} notification(s) deleted successfully.`
          : "Request and messages deleted successfully.",
      notificationsDeleted,
    };
  } catch (err) {
    console.error("[deleteRequest] ERROR:", err);
    throw toHttpsError(
      err,
      `Failed to delete request: ${err.message || "Unknown error"}`,
    );
  }
});

/**
 * sendRequestMessageToDonors - Firestore trigger.
 * ✅ UPDATED: Filters donors by GOVERNORATE (location name) instead of GPS distance.
 * Only donors in the same governorate as the hospital will receive notifications.
 * Falls back to notifying ALL donors if hospitalLocation is missing.
 */
exports.sendRequestMessageToDonors = onDocumentCreated(
  { document: "requests/{requestId}" },
  async (event) => {
    try {
      console.log("[sendRequestMessageToDonors] Trigger fired");

      const snapshot = event.data;
      const data = snapshot ? snapshot.data() : null;
      if (!data) {
        console.log("[sendRequestMessageToDonors] No data in event, exiting");
        return;
      }

      const requestId = event.params.requestId;
      const bloodType = data.bloodType;
      const bloodBankId = data.bloodBankId;

      // ✅ الجديد: استخرج اسم المحافظة من hospitalLocation
      const hospitalLocation = (data.hospitalLocation || "").trim();

      console.log(
        `[sendRequestMessageToDonors] Request: ${requestId}, bloodType: ${bloodType}, ` +
          `hospitalLocation: ${hospitalLocation}`,
      );

      const requestRef = db.collection("requests").doc(requestId);

      const allDonorsSnapshot = await db
        .collection("users")
        .where("role", "==", "donor")
        .get();

      const activeDonors = allDonorsSnapshot.docs.filter((doc) => {
        const donorData = doc.data();
        const fcmToken = donorData.fcmToken;

        // لازم يكون عنده FCM token عشان يستقبل الإشعار
        if (
          !fcmToken ||
          typeof fcmToken !== "string" ||
          fcmToken.trim().length === 0
        ) {
          return false;
        }

        // ✅ إذا المستشفى ما عنده location، وصّل للكل كـ fallback
        if (!hospitalLocation) {
          console.log(
            `[sendRequestMessageToDonors] No hospitalLocation set, notifying all donors`,
          );
          return true;
        }

        const donorLocation = (donorData.location || "").trim();

        // إذا المتبرع ما عنده location، اشمله كـ fallback
        if (!donorLocation) {
          return true;
        }

        // ✅ المطابقة الرئيسية: محافظة المتبرع = محافظة المستشفى
        const sameGovernorate =
          donorLocation.toLowerCase() === hospitalLocation.toLowerCase();

        console.log(
          `[sendRequestMessageToDonors] Donor ${doc.id}: ` +
            `donorLocation="${donorLocation}", hospitalLocation="${hospitalLocation}", ` +
            `match=${sameGovernorate}`,
        );

        return sameGovernorate;
      });

      console.log(
        `[sendRequestMessageToDonors] Total donors: ${allDonorsSnapshot.size}, ` +
          `matching governorate "${hospitalLocation}": ${activeDonors.length}`,
      );

      if (activeDonors.length === 0) {
        console.log(
          `[sendRequestMessageToDonors] No donors found in governorate "${hospitalLocation}", exiting`,
        );
        return;
      }

      const tokens = [];
      const MAX_BATCH_SIZE = 500;
      let notificationBatch = db.batch();
      let messageBatch = db.batch();
      let notificationBatchCount = 0;
      let messageBatchCount = 0;
      const batchPromises = [];

      // ✅ إنشاء الإشعارات للمتبرعين بنفس المحافظة فقط
      for (const donorDoc of activeDonors) {
        const donorData = donorDoc.data();
        const donorId = donorDoc.id;

        if (donorData.fcmToken) {
          tokens.push(donorData.fcmToken);
        }

        const notificationRef = db
          .collection("notifications")
          .doc(donorId)
          .collection("user_notifications")
          .doc();

        notificationBatch.set(notificationRef, {
          title: `Blood request: ${bloodType}`,
          body: `${data.bloodBankName || "Blood Bank"} needs your help ❤️`,
          requestId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });
        notificationBatchCount++;

        if (notificationBatchCount >= MAX_BATCH_SIZE) {
          batchPromises.push(notificationBatch.commit());
          notificationBatch = db.batch();
          notificationBatchCount = 0;
        }
      }

      // ✅ إنشاء الرسائل للمتبرعين بنفس المحافظة فقط
      for (const donorDoc of activeDonors) {
        const donorData = donorDoc.data();
        const donorId = donorDoc.id;
        const donorName = donorData.fullName || donorData.name || "Donor";

        const messageRef = requestRef.collection("messages").doc();
        messageBatch.set(messageRef, {
          senderId: bloodBankId,
          senderRole: "hospital",
          text: `Please ${donorName}, ${data.bloodBankName || "Blood Bank"} needs your help ❤️`,
          recipientId: donorId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        messageBatchCount++;

        if (messageBatchCount >= MAX_BATCH_SIZE) {
          batchPromises.push(messageBatch.commit());
          messageBatch = db.batch();
          messageBatchCount = 0;
        }
      }

      if (notificationBatchCount > 0) {
        batchPromises.push(notificationBatch.commit());
      }
      if (messageBatchCount > 0) {
        batchPromises.push(messageBatch.commit());
      }
      if (batchPromises.length > 0) {
        await Promise.all(batchPromises);
      }

      console.log(
        `[sendRequestMessageToDonors] ✅ Created ${activeDonors.length} notifications and messages`,
      );

      const uniqueTokens = [...new Set(tokens)].filter(
        (t) => typeof t === "string" && t.trim().length > 0,
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

        const message = {
          data: {
            type: "request",
            requestId,
            bloodType,
            isUrgent: data.isUrgent ? "true" : "false",
            title,
            body,
          },
          android: { priority: "high" },
          apns: {
            payload: {
              aps: {
                alert: { title, body },
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        await sendInChunks(uniqueTokens, 500, async (chunk) => {
          const messages = chunk.map((token) => ({ ...message, token }));
          try {
            const res = await admin.messaging().sendAll(messages);
            console.log(
              `[Push] sent: ${res.successCount}, failed: ${res.failureCount}`,
            );
            res.responses.forEach((r, idx) => {
              if (!r.success) {
                console.log(
                  "[Push] failed token:",
                  chunk[idx],
                  r.error ? r.error.message : "",
                );
              }
            });
          } catch (err) {
            console.error("[Push] Error sending messages:", err);
            for (const token of chunk) {
              try {
                await admin.messaging().send({ ...message, token });
              } catch (individualErr) {
                console.log(
                  "[Push] Failed for token:",
                  token,
                  individualErr.message,
                );
              }
            }
          }
        });
      } else {
        console.log(
          `[Push] No tokens found for donors in "${hospitalLocation}".`,
        );
      }

      console.log(
        `[sendRequestMessageToDonors] Done. Notified ${activeDonors.length} donors in "${hospitalLocation}".`,
      );
    } catch (err) {
      console.error("[sendRequestMessageToDonors] ERROR:", err);
      console.error("[sendRequestMessageToDonors] Error stack:", err.stack);
    }
  },
);
