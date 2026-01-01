const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
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
      : (fallbackMessage || "Server error occurred.");

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
      throw new HttpsError("invalid-argument", "role must be donor or hospital");
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
      payload.bloodBankName = nonEmptyString(data.bloodBankName, "bloodBankName");
      payload.location = nonEmptyString(data.location, "location");
    }

    await db.collection("pending_profiles").doc(uid).set(payload, { merge: true });

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
    const toMillis = (v) => (v && typeof v.toMillis === "function" ? v.toMillis() : null);

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
    const ud = userSnap.exists ? (userSnap.data() || {}) : {};

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
      throw new HttpsError("invalid-argument", "units must be a positive number");
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

    if (isUrgent) {
      const donorsSnapshot = await db
        .collection("users")
        .where("role", "==", "donor")
        .get();

      const batch = db.batch();
      donorsSnapshot.docs.forEach((doc) => {
        const notificationRef = db
          .collection("notifications")
          .doc(doc.id)
          .collection("user_notifications")
          .doc();

        batch.set(notificationRef, {
          title: `Urgent blood request: ${bloodType}`,
          body: `${units} units needed at ${bloodBankName}`,
          requestId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });
      });

      await batch.commit();
    }

    return { ok: true, message: "Request created successfully" };
  } catch (err) {
    console.error("[addRequest] ERROR:", err);
    throw toHttpsError(err, "Failed to create request.");
  }
});

/**
 * getRequests - pagination
 */
exports.getRequests = onCall(async (request) => {
  try {
    requireAuth(request);
    const data = request.data || {};

    const limit = typeof data.limit === "number" ? Math.min(data.limit, 100) : 50;
    const lastRequestId =
      typeof data.lastRequestId === "string" ? data.lastRequestId : null;

    let query = db.collection("requests").orderBy("createdAt", "desc").limit(limit);

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

    console.log("[cleanupUnverifiedUsers] done", { scanned, deleted, days: DAYS });
  }
);
