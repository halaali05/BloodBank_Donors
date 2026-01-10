const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { requireAuth, nonEmptyString, toHttpsError } = require("./utils");

const db = admin.firestore();

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
 * updateLastLoginAt
 * Updates the lastLoginAt timestamp for authenticated users.
 * Only updates if user document exists in users collection.
 * This is used to filter notifications to only logged-in users.
 */
exports.updateLastLoginAt = onCall(async (request) => {
    try {
        const uid = requireAuth(request);

        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();

        // Only update if user document already exists
        // This prevents creating documents before email verification
        if (!userSnap.exists) {
            return { ok: true, message: "User profile not yet activated." };
        }

        await userRef.set(
            {
                lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        return { ok: true, message: "Last login time updated." };
    } catch (err) {
        console.error("[updateLastLoginAt] ERROR:", err);
        throw toHttpsError(err, "Failed to update last login time.");
    }
});

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
 * updateFcmToken
 * Updates the FCM token for the authenticated user.
 * Used for push notifications targeting.
 */
exports.updateFcmToken = onCall(async (request) => {
    try {
        const uid = requireAuth(request);
        const data = request.data || {};

        const fcmToken = typeof data.fcmToken === "string" && data.fcmToken.trim() !== ""
            ? data.fcmToken.trim()
            : null;

        if (!fcmToken) {
            throw new HttpsError(
                "invalid-argument",
                "FCM token is required."
            );
        }

        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();

        // Only update if user document exists
        if (!userSnap.exists) {
            return {
                ok: true,
                message: "User profile not yet activated. Token will be saved after activation.",
            };
        }

        await userRef.set(
            {
                fcmToken: fcmToken,
                lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        return { ok: true, message: "FCM token updated." };
    } catch (err) {
        console.error("[updateFcmToken] ERROR:", err);
        throw toHttpsError(err, "Failed to update FCM token.");
    }
});

/**
 * updateUserProfile
 * Updates user profile information (name, etc.)
 * Only allows users to update their own profile.
 */
exports.updateUserProfile = onCall(async (request) => {
    try {
        const uid = requireAuth(request);
        const data = request.data || {};

        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();

        if (!userSnap.exists) {
            throw new HttpsError("not-found", "User profile not found.");
        }

        const updates = {};
        const userRecord = await admin.auth().getUser(uid);

        // Update name if provided
        if (typeof data.name === "string" && data.name.trim() !== "") {
            const newName = data.name.trim();
            updates.name = newName;
            updates.fullName = newName; // Also update fullName for consistency
            updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

            // Update Firebase Auth display name
            try {
                await admin.auth().updateUser(uid, {
                    displayName: newName,
                });
            } catch (authErr) {
                console.warn("[updateUserProfile] Failed to update Auth displayName:", authErr);
                // Continue even if Auth update fails
            }
        }

        if (Object.keys(updates).length === 0) {
            throw new HttpsError(
                "invalid-argument",
                "No valid fields to update."
            );
        }

        await userRef.set(updates, { merge: true });

        return {
            ok: true,
            message: "Profile updated successfully.",
        };
    } catch (err) {
        console.error("[updateUserProfile] ERROR:", err);
        throw toHttpsError(err, "Failed to update profile.");
    }
});

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
