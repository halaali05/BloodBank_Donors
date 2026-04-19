const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  requireAuth,
  nonEmptyString,
  toHttpsError,
  normalizeJordanMobile,
  parseDonorGender,
} = require("./utils");
const { publicCallableOpts } = require("../callable_config");

const db = admin.firestore();

/**
 * createPendingProfile
 * Writes ONLY to pending_profiles/{uid}.
 * Now also saves latitude/longitude from the governorate coordinates.
 */
exports.createPendingProfile = onCall(publicCallableOpts, async (request) => {
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

    // Save latitude/longitude if provided (sent from Flutter AppTheme.getLatitude/getLongitude)
    if (typeof data.latitude === "number") payload.latitude = data.latitude;
    if (typeof data.longitude === "number") payload.longitude = data.longitude;

    if (role === "donor") {
      payload.fullName = nonEmptyString(data.fullName, "fullName");
      payload.location = nonEmptyString(data.location, "location");
      const gender = parseDonorGender(data.gender);
      if (!gender) {
        throw new HttpsError(
          "invalid-argument",
          "gender must be male or female.",
        );
      }
      payload.gender = gender;
      const phoneNorm = normalizeJordanMobile(
        typeof data.phoneNumber === "string" ? data.phoneNumber : "",
      );
      if (!phoneNorm) {
        throw new HttpsError(
          "invalid-argument",
          "phoneNumber must be a valid Jordan mobile (e.g. 0791234567 or +962791234567).",
        );
      }
      payload.phoneNumber = phoneNorm;
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
exports.completeProfileAfterVerification = onCall(publicCallableOpts, async (request) => {
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

exports.getUserData = onCall(publicCallableOpts, async (request) => {
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
    const toMillis = (v) => {
      if (v == null) return null;
      if (typeof v.toMillis === "function") return v.toMillis();
      if (typeof v === "number" && Number.isFinite(v)) return v;
      return null;
    };

    return {
      uid: targetUid,
      ...d,
      createdAt: toMillis(d.createdAt),
      activatedAt: toMillis(d.activatedAt),
      emailVerifiedAt: toMillis(d.emailVerifiedAt),
      lastDonatedAt: toMillis(d.lastDonatedAt),
      nextDonationEligibleAt: toMillis(d.nextDonationEligibleAt),
      restrictedUntil: toMillis(d.restrictedUntil),
    };
  } catch (err) {
    console.error("[getUserData] ERROR:", err);
    throw toHttpsError(err, "Failed to load user profile.");
  }
});

exports.getUserRole = onCall(publicCallableOpts, async (request) => {
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

exports.updateLastLoginAt = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return { ok: true, message: "User profile not yet activated." };
    }

    await userRef.set(
      { lastLoginAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );

    return { ok: true, message: "Last login time updated." };
  } catch (err) {
    console.error("[updateLastLoginAt] ERROR:", err);
    throw toHttpsError(err, "Failed to update last login time.");
  }
});

async function deletePendingUser(uid) {
  await Promise.allSettled([
    db.collection("pending_profiles").doc(uid).delete(),
    db.collection("users").doc(uid).delete(),
  ]);
  await admin.auth().deleteUser(uid);
}

exports.updateFcmToken = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const fcmToken =
      typeof data.fcmToken === "string" && data.fcmToken.trim() !== ""
        ? data.fcmToken.trim()
        : null;

    if (!fcmToken) {
      throw new HttpsError("invalid-argument", "FCM token is required.");
    }

    console.log(
      `[updateFcmToken] uid=${uid} tokenPrefix=${fcmToken.substring(0, 16)}`,
    );

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        "User profile not found. Complete profile activation first.",
      );
    }

    // Do NOT remove this token from other users.
    // During testing or multi-account/device scenarios, aggressive duplicate cleanup
    // can silently break notifications for one account.

    await userRef.set(
      {
        fcmToken: fcmToken,
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const verifySnap = await userRef.get();
    const savedToken = verifySnap.exists &&
      typeof verifySnap.data().fcmToken === "string" ?
      verifySnap.data().fcmToken.trim() :
      "";
    if (!savedToken) {
      throw new HttpsError(
        "internal",
        "FCM token was not persisted to user profile.",
      );
    }

    console.log(`[updateFcmToken] token saved for uid=${uid}`);

    return { ok: true, message: "FCM token updated." };
  } catch (err) {
    console.error("[updateFcmToken] ERROR:", err);
    throw toHttpsError(err, "Failed to update FCM token.");
  }
});

exports.updateUserProfile = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const updates = {};

    if (typeof data.name === "string" && data.name.trim() !== "") {
      const newName = data.name.trim();
      updates.name = newName;
      updates.fullName = newName;
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

      try {
        await admin.auth().updateUser(uid, { displayName: newName });
      } catch (authErr) {
        console.warn(
          "[updateUserProfile] Failed to update Auth displayName:",
          authErr,
        );
      }
    }

    if (Object.keys(updates).length === 0) {
      throw new HttpsError("invalid-argument", "No valid fields to update.");
    }

    await userRef.set(updates, { merge: true });

    return { ok: true, message: "Profile updated successfully." };
  } catch (err) {
    console.error("[updateUserProfile] ERROR:", err);
    throw toHttpsError(err, "Failed to update profile.");
  }
});

exports.cleanupUnverifiedUsers = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "Asia/Amman",
    region: "us-central1",
  },
  async () => {
    const DAYS = 2;
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
  },
);
