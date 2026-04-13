const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { requireAuth, nonEmptyString, toHttpsError } = require("./utils");

const db = admin.firestore();

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
 * deleteOldNotifications - delete notifications older than [days] for the current user
 */
exports.deleteOldNotifications = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const daysRaw =
      typeof data.days === "number" ? data.days : parseInt(data.days, 10);
    const days = Number.isInteger(daysRaw) && daysRaw > 0 ? daysRaw : 30;

    const cutoffDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

    const notificationsRef = db
      .collection("notifications")
      .doc(uid)
      .collection("user_notifications");

    const oldSnapshot = await notificationsRef
      .where("createdAt", "<", cutoffTimestamp)
      .get();

    if (oldSnapshot.empty) {
      return {
        ok: true,
        deletedCount: 0,
        message: `No notifications older than ${days} day(s).`,
      };
    }

    const batchSize = 500;
    let deletedCount = 0;
    for (let i = 0; i < oldSnapshot.docs.length; i += batchSize) {
      const batch = db.batch();
      oldSnapshot.docs.slice(i, i + batchSize).forEach((doc) => {
        batch.delete(doc.ref);
        deletedCount += 1;
      });
      await batch.commit();
    }

    return {
      ok: true,
      deletedCount,
      message: `Deleted ${deletedCount} old notification(s).`,
    };
  } catch (err) {
    console.error("[deleteOldNotifications] ERROR:", err);
    throw toHttpsError(err, "Failed to delete old notifications.");
  }
});

/**
 * getNotifications - Get all notifications for the authenticated user
 */
exports.getNotifications = onCall(async (request) => {
  try {
    const uid = requireAuth(request);

    const snapshot = await db
      .collection("notifications")
      .doc(uid)
      .collection("user_notifications")
      .orderBy("createdAt", "desc")
      .get();

    const notifications = snapshot.docs.map((doc) => {
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

    return { notifications, count: notifications.length };
  } catch (err) {
    console.error("[getNotifications] ERROR:", err);
    throw toHttpsError(err, "Failed to load notifications.");
  }
});

/**
 * getMessages - Get all messages for a specific request
 */
exports.getMessages = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const requestId = nonEmptyString(data.requestId, "requestId");

    // Verify request exists
    const requestRef = db.collection("requests").doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }

    const requestData = requestSnap.data() || {};
    const isRequestOwner = requestData.bloodBankId === uid;

    // Get user role
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    // Get all messages
    const messagesSnapshot = await requestRef
      .collection("messages")
      .orderBy("createdAt", "desc")
      .get();

    // Filter messages based on user role and recipientId
    const allMessages = messagesSnapshot.docs.map((doc) => {
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

    // Extract optional filterRecipientId (used when blood bank chats with specific donor)
    let filterRecipientId = null;
    if (
      data.filterRecipientId !== undefined &&
      data.filterRecipientId !== null
    ) {
      if (
        typeof data.filterRecipientId === "string" &&
        data.filterRecipientId.trim().length > 0
      ) {
        filterRecipientId = data.filterRecipientId.trim();
        console.log(
          `[getMessages] 🔍 Blood bank filtering messages for recipientId: ${filterRecipientId}`,
        );
      }
    }

    // Filter messages:
    // - If user is request owner (blood bank) AND filterRecipientId is provided:
    //   Show only general messages OR messages for that specific recipient
    // - If user is request owner (blood bank) AND NO filterRecipientId:
    //   Show all messages (general view)
    // - If user is donor: show only messages without recipientId OR messages with recipientId matching their uid
    const filteredMessages = allMessages.filter((msg) => {
      if (isRequestOwner) {
        // Blood bank viewing messages
        if (filterRecipientId) {
          // Blood bank is chatting with a specific donor - STRICT filtering:
          // Only show messages relevant to THIS specific donor conversation
          const msgRecipientId = msg.recipientId
            ? String(msg.recipientId).trim()
            : "";
          const msgSenderId = msg.senderId ? String(msg.senderId).trim() : "";
          const filterId = String(filterRecipientId).trim();

          // 1. General messages (no recipientId) - visible to all donors
          if (!msgRecipientId || msgRecipientId === "") {
            return true;
          }

          // 2. Messages TO this specific donor (recipientId matches)
          if (msgRecipientId === filterId) {
            console.log(
              `[getMessages] ✅ Showing message TO ${filterId} (recipientId matches)`,
            );
            return true;
          }

          // 3. Messages FROM this specific donor (senderId matches)
          // These are messages the donor sent to the blood bank
          if (msgSenderId === filterId) {
            console.log(
              `[getMessages] ✅ Showing message FROM ${filterId} (senderId matches)`,
            );
            return true;
          }

          // 4. EXCLUDE all other personalized messages (to other donors)
          // If message has recipientId but it's not for this donor, don't show it
          console.log(
            `[getMessages] ❌ Hiding message: recipientId=${msgRecipientId}, senderId=${msgSenderId}, filter=${filterId}`,
          );
          return false;
        } else {
          // Blood bank viewing all messages (no filter)
          return true; // Show all messages
        }
      }

      // Donor sees:
      // 1. Messages without recipientId (general messages)
      // 2. Messages with recipientId matching their uid (personalized messages)
      // 3. Their own sent messages (senderId == donor uid)
      const donorUid = String(uid).trim();
      const msgRecipient = msg.recipientId != null
        ? String(msg.recipientId).trim()
        : "";
      const msgSender = msg.senderId != null
        ? String(msg.senderId).trim()
        : "";
      const hasRecipientId = msgRecipient.length > 0;
      if (msgSender === donorUid) {
        return true; // Always show donor's own outgoing messages
      }
      if (!hasRecipientId) {
        return true; // General message - visible to all
      }

      return msgRecipient === donorUid;
    });

    return {
      messages: filteredMessages,
      count: filteredMessages.length,
      bloodBankId: requestData.bloodBankId || null,
    };
  } catch (err) {
    console.error("[getMessages] ERROR:", err);
    throw toHttpsError(err, "Failed to load messages.");
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

    // Extract recipientId - must be a non-empty string
    let recipientId = null;
    console.log(
      `[sendMessage] 🔍 Received data.recipientId: ${data.recipientId} (type: ${typeof data.recipientId})`,
    );
    console.log(
      `[sendMessage] 🔍 data object keys: ${Object.keys(data).join(", ")}`,
    );

    if (data.recipientId !== undefined && data.recipientId !== null) {
      if (
        typeof data.recipientId === "string" &&
        data.recipientId.trim().length > 0
      ) {
        recipientId = data.recipientId.trim();
        console.log(
          `[sendMessage] ✅ Received VALID recipientId: ${recipientId}`,
        );
      } else {
        console.log(
          `[sendMessage] ❌ recipientId provided but invalid: ${data.recipientId} (type: ${typeof data.recipientId})`,
        );
      }
    } else {
      console.log(
        `[sendMessage] ⚠️ No recipientId provided - this will be a general message (visible to all donors)`,
      );
    }

    // Get user role
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    const senderRole = userData.role || "donor";
    const senderName =
      userData.fullName || userData.name || userData.bloodBankName || "User";

    // Verify request exists
    const requestRef = db.collection("requests").doc(requestId);
    const requestSnap = await requestRef.get();
    const requestData = requestSnap.data() || {};

    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }

    let effectiveRecipientId = recipientId;
    if (!effectiveRecipientId && senderRole === "donor") {
      const ownerId =
        typeof requestData.bloodBankId === "string"
          ? requestData.bloodBankId.trim()
          : "";
      if (ownerId) {
        effectiveRecipientId = ownerId;
      }
    }

    // Build message object
    const messageData = {
      text: text.trim(),
      senderId: uid,
      senderRole: senderRole,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // CRITICAL: Add recipientId if provided (for direct messages between blood bank and specific donor)
    // This field is essential for filtering messages to show only to the intended donor
    console.log(
      `[sendMessage] 🔍 About to store message. recipientId value: ${recipientId}`,
    );
    if (effectiveRecipientId) {
      messageData.recipientId = effectiveRecipientId;
      console.log(
        `[sendMessage] ✅ Storing PERSONALIZED message with recipientId: ${effectiveRecipientId}`,
      );
      console.log(
        `[sendMessage] ✅ messageData.recipientId = ${messageData.recipientId}`,
      );
      console.log(
        `[sendMessage] ✅ This message will ONLY be visible to recipient: ${effectiveRecipientId}`,
      );
    } else {
      console.log(
        `[sendMessage] ⚠️ Storing GENERAL message WITHOUT recipientId (visible to all donors)`,
      );
      console.log(`[sendMessage] ⚠️ messageData.recipientId will be undefined`);
    }

    // Add message to the request's messages subcollection
    const messageRef = await requestRef.collection("messages").add(messageData);

    // Verify what was actually stored
    const storedData = {
      messageId: messageRef.id,
      recipientId: messageData.recipientId || null,
      senderId: messageData.senderId,
      senderRole: messageData.senderRole,
      hasRecipientId: !!messageData.recipientId,
    };
    console.log(
      `[sendMessage] ✅ Message stored successfully:`,
      JSON.stringify(storedData),
    );

    // Double-check by reading it back
    const verifyDoc = await messageRef.get();
    const verifyData = verifyDoc.data();
    console.log(
      `[sendMessage] 🔍 Verification - Message read back from Firestore:`,
      {
        id: verifyDoc.id,
        recipientId: verifyData?.recipientId || null,
        senderId: verifyData?.senderId,
        senderRole: verifyData?.senderRole,
      },
    );

    // Push notification for direct messages only (no persistence in notifications list).
    // Broadcast messages intentionally skip push to avoid noisy blasts.
    const recipientCandidates = new Set();
    if (effectiveRecipientId) recipientCandidates.add(effectiveRecipientId);
    if (
      senderRole === "donor" &&
      typeof requestData.bloodBankId === "string" &&
      requestData.bloodBankId.trim()
    ) {
      recipientCandidates.add(requestData.bloodBankId.trim());
    }
    if (recipientCandidates.size > 0) {
      try {
        for (const recipientUid of recipientCandidates) {
          console.log(
            `[sendMessage] 🔔 Preparing push. sender=${uid} recipient=${recipientUid}`,
          );
          const recipientUserSnap = await db
            .collection("users")
            .doc(recipientUid)
            .get();
          const recipientData = recipientUserSnap.exists ?
            recipientUserSnap.data() || {} :
            {};
          console.log(
            `[sendMessage] 🔔 Recipient doc exists=${recipientUserSnap.exists} role=${recipientData.role || "unknown"}`,
          );
          const token = typeof recipientData.fcmToken === "string" ?
            recipientData.fcmToken.trim() :
            "";
          if (!token) {
            console.warn(
              `[sendMessage] 🔕 Push skipped: recipient has no fcmToken (uid=${recipientUid})`,
            );
            continue;
          }
          const title = senderRole === "hospital" ?
            `${requestData.bloodBankName || senderName}` :
            senderName;
          const body = text.trim().length > 120 ?
            `${text.trim().slice(0, 117)}...` :
            text.trim();
          const messagePayload = {
            token,
            notification: {title, body},
            data: {
              type: "chat",
              requestId: String(requestId),
              title: String(title),
              body: String(body),
              senderId: String(uid),
              recipientId: String(recipientUid),
            },
            android: {
              priority: "high",
              notification: {
                // Must match a channel created in LocalNotifService (Flutter).
                channelId: "normal_request_channel",
                icon: "ic_launcher",
                sound: "normal_request",
                defaultSound: false,
              },
            },
            apns: {
              payload: {
                aps: {
                  alert: {title, body},
                  sound: "normal_request.mp3",
                },
              },
            },
            webpush: {
              headers: {
                Urgency: "high",
              },
              notification: {
                title,
                body,
                requireInteraction: true,
                tag: `chat_${String(requestId)}`,
              },
              fcmOptions: {
                // Open app on click. Service worker then routes using notificationData.
                link: "/",
              },
              data: {
                type: "chat",
                requestId: String(requestId),
                title: String(title),
                body: String(body),
                senderId: String(uid),
                recipientId: String(recipientUid),
              },
            },
          };
          const pushMessageId = await admin.messaging().send(messagePayload);
          console.log(
            `[sendMessage] 🔔 Push sent successfully to recipient=${recipientUid} messageId=${pushMessageId}`,
          );
        }
      } catch (pushErr) {
        console.warn("[sendMessage] Push send failed:", pushErr.message);
      }
    }

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
 * ensureDonorWelcomeMessage — If this donor has no personalized hospital message
 * for the request yet, create the same line as sendRequestMessageToDonors (idempotent).
 * Lets Messages from the donor dashboard match notification/chat content.
 */
exports.ensureDonorWelcomeMessage = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const requestId = nonEmptyString(data.requestId, "requestId");

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }
    const userData = userSnap.data() || {};
    if (userData.role !== "donor") {
      throw new HttpsError(
        "permission-denied",
        "Only donors can ensure welcome messages.",
      );
    }

    const requestRef = db.collection("requests").doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }

    const rd = requestSnap.data() || {};
    const bloodBankId = rd.bloodBankId;
    if (!bloodBankId || typeof bloodBankId !== "string") {
      throw new HttpsError("failed-precondition", "Invalid request data.");
    }

    const snapshot = await requestRef
      .collection("messages")
      .orderBy("createdAt", "desc")
      .limit(80)
      .get();

    const donorUid = String(uid).trim();
    const bankId = String(bloodBankId).trim();

    const hasPersonalFromBank = snapshot.docs.some((doc) => {
      const m = doc.data() || {};
      const recip =
        m.recipientId != null ? String(m.recipientId).trim() : "";
      const send = m.senderId != null ? String(m.senderId).trim() : "";
      const role = m.senderRole || "";
      return recip === donorUid && send === bankId && role === "hospital";
    });

    if (hasPersonalFromBank) {
      return { ok: true, created: false };
    }

    const donorName =
      userData.fullName || userData.name || "Donor";
    const bloodBankName = rd.bloodBankName || "Blood Bank";
    const text =
      `Please ${donorName}, ${bloodBankName} needs your help ❤️`;

    await requestRef.collection("messages").add({
      senderId: bloodBankId,
      senderRole: "hospital",
      recipientId: uid,
      text,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true, created: true };
  } catch (err) {
    console.error("[ensureDonorWelcomeMessage] ERROR:", err);
    throw toHttpsError(err, "Failed to ensure welcome message.");
  }
});

/**
 * cleanupOrphanNotifications - Scheduled cleanup for orphan notifications
 */
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
  },
);

/**
 * cleanupOrphanMessages - Scheduled cleanup for orphan messages
 * حذف الرسائل الموجودة مسبقا بدون طلبات بالفيربيس
 */
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
      const existingRequestIds = requestsSnapshot.docs.map((doc) => doc.id);

      // احصل على جميع المستندات تحت requests
      const allRequestsSnapshot = await db.collection("requests").get();

      let totalDeleted = 0;

      // افحص كل الطلبات القديمة
      for (const requestDoc of allRequestsSnapshot.docs) {
        const requestId = requestDoc.id;

        // إذا هذا الطلب موجود، تجاهل
        if (existingRequestIds.includes(requestId)) continue;

        // احصل على جميع الرسائل تحت هذا الطلب
        const messagesRef = db
          .collection("requests")
          .doc(requestId)
          .collection("messages");
        const messagesSnapshot = await messagesRef.get();

        if (!messagesSnapshot.empty) {
          const batchSize = 500;
          for (let i = 0; i < messagesSnapshot.docs.length; i += batchSize) {
            const batch = db.batch();
            messagesSnapshot.docs.slice(i, i + batchSize).forEach((doc) => {
              batch.delete(doc.ref);
              totalDeleted++;
            });
            await batch.commit();
          }
          console.log(
            `[cleanupOrphanMessages] Deleted ${messagesSnapshot.size} orphan messages for request ${requestId}`,
          );
        }
      }

      console.log(
        `[cleanupOrphanMessages] done. Total orphan messages deleted: ${totalDeleted}`,
      );
    } catch (err) {
      console.error("[cleanupOrphanMessages] ERROR:", err);
    }
  },
);
