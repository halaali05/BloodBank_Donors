const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  requireAuth,
  nonEmptyString,
  toHttpsError,
  normalizeJordanMobile,
  jordanMobileFirestoreLookupVariants,
  parseDonorGender,
} = require("./utils");
const { publicCallableOpts } = require("../callable_config");
const {
  scheduleRef,
  mergeUserWithScheduleSnap,
} = require("../donation_schedule");

const db = admin.firestore();

/**
 * Prefer Firestore email; fallback to Firebase Auth (`users.email` can be stale/missing).
 * @param {string} uid
 * @param {FirebaseFirestore.DocumentData} data
 * @return {Promise<string>}
 */
async function donorEmailFromUserDoc(uid, data) {
  const fromFs = typeof data.email === "string" ? data.email.trim() : "";
  if (fromFs) return fromFs;
  try {
    const rec = await admin.auth().getUser(uid);
    return typeof rec.email === "string" ? rec.email.trim() : "";
  } catch (_) {
    return "";
  }
}

/**
 * Same mobile may be stored as +962…, 962…, or 07… — merge without double-counting.
 *
 * @param {FirebaseFirestore.CollectionReference} colRef
 * @param {string} normalized
 * @return {Promise<FirebaseFirestore.QueryDocumentSnapshot[]>}
 */
async function snapshotsForPhoneVariants(colRef, normalized) {
  const variants = jordanMobileFirestoreLookupVariants(normalized);
  /** @type {Map<string, FirebaseFirestore.QueryDocumentSnapshot>} */
  const byId = new Map();
  for (const variant of variants) {
    const snap = await colRef.where("phoneNumber", "==", variant).limit(25).get();
    for (const doc of snap.docs) {
      if (!byId.has(doc.id)) byId.set(doc.id, doc);
    }
  }
  return Array.from(byId.values());
}

/**
 * When Firestore has no `phoneNumber` match but the user linked this mobile in
 * Firebase Auth (donor SMS step), resolve sign-in email from Auth + profile role.
 *
 * @param {string} normalized E.164
 * @return {Promise<string|null>}
 */
async function resolveDonorEmailViaAuthLinkedPhone(normalized) {
  let userRecord;
  try {
    userRecord = await admin.auth().getUserByPhoneNumber(normalized);
  } catch (e) {
    const code = e && (e.code || (e.errorInfo && e.errorInfo.code));
    if (code === "auth/user-not-found") return null;
    throw e;
  }

  const email =
      typeof userRecord.email === "string" ? userRecord.email.trim() : "";
  if (!email) return null;

  return email;
}

/**
 * User has verified / linked SMS phone on Auth (linked phone numbers include E.164).
 */
function authUserHasVerifiedPhoneLinked(userRecord) {
  return (
    typeof userRecord.phoneNumber === "string" &&
    userRecord.phoneNumber.trim() !== ""
  );
}

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
 * Moves pending_profiles/{uid} -> users/{uid} when verification rules pass.
 *
 * - Donors: BOTH verified email AND SMS-linked phone (single signup path via client).
 * - Hospitals: verified email only.
 */
exports.completeProfileAfterVerification = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);

    const userRecord = await admin.auth().getUser(uid);
    const emailVerified = userRecord.emailVerified === true;
    const phoneVerified = authUserHasVerifiedPhoneLinked(userRecord);
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
    const role = pendingData.role;

    if (role === "donor") {
      if (!emailVerified || !phoneVerified) {
        throw new HttpsError(
          "failed-precondition",
          "Verify both your email (inbox link) and your phone number (SMS) before continuing.",
        );
      }
    } else if (role === "hospital") {
      if (!emailVerified) {
        throw new HttpsError(
          "failed-precondition",
          "Email is not verified yet.",
        );
      }
    } else {
      throw new HttpsError(
        "failed-precondition",
        "Unknown profile role; cannot complete verification.",
      );
    }

    await db.runTransaction(async (tx) => {
      tx.set(
        userRef,
        {
          ...pendingData,
          email: userRecord.email || null,
          phoneNumber: pendingData.phoneNumber || userRecord.phoneNumber || null,
          emailVerified,
          phoneVerified,
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          ...(emailVerified
            ? {emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp()}
            : {}),
          ...(phoneVerified
            ? {phoneVerifiedAt: admin.firestore.FieldValue.serverTimestamp()}
            : {}),
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

    const schedSnap = await scheduleRef(db, targetUid).get();
    const d = mergeUserWithScheduleSnap(snap.data() || {}, schedSnap);
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

/**
 * Resolve the account email from a normalized Jordan mobile.
 * Allows phone + password login (same Firebase credential as email sign-in).
 *
 * Lookup order:
 * 1) Firestore `users` (+ stored-format variants),
 * 2) Firestore `pending_profiles`,
 * 3) Firebase Auth phone index (`phoneNumber` on the Auth user record, e.g. after SMS link).
 *
 * No caller authentication — returns not-found when nothing matches.
 */
exports.resolveDonorEmailForPhoneLogin = onCall(
    publicCallableOpts,
    async (request) => {
      try {
        const data = request.data || {};
        const raw =
            typeof data.phoneNumber === "string" ? data.phoneNumber : "";
        const normalized = normalizeJordanMobile(raw);
        if (!normalized) {
          throw new HttpsError(
              "invalid-argument",
              "Enter a valid Jordan mobile (079, 078, 077, or 962…).",
          );
        }

        const userSnaps =
            await snapshotsForPhoneVariants(db.collection("users"), normalized);
        const matchingUserDocs = userSnaps;

        if (matchingUserDocs.length === 1) {
          const doc = matchingUserDocs[0];
          const email =
              await donorEmailFromUserDoc(doc.id, doc.data() || {});
          if (!email) {
            throw new HttpsError(
                "not-found",
                "No account uses this phone number.",
            );
          }
          return { ok: true, email };
        }

        if (matchingUserDocs.length > 1) {
          /** @type {{ id: string, email: string }[]} */
          const withEmail = [];
          for (const doc of matchingUserDocs) {
            const email =
                await donorEmailFromUserDoc(doc.id, doc.data() || {});
            if (email) withEmail.push({ id: doc.id, email });
          }
          const distinctLower =
              [...new Set(withEmail.map((x) => x.email.toLowerCase()))];

          const everyDocHasEmail =
              withEmail.length === matchingUserDocs.length;

          if (everyDocHasEmail && distinctLower.length === 1) {
            return {
              ok: true,
              email: withEmail[0].email,
            };
          }

          console.error(
              "[resolveDonorEmailForPhoneLogin] duplicate phone users",
              normalized,
              {
                uidCount: matchingUserDocs.length,
                resolvedEmails: distinctLower.length,
              },
          );
          throw new HttpsError(
              "failed-precondition",
              "Several accounts share this mobile. Please sign in with "
                  + "your email or contact support to tidy duplicate profiles.",
          );
        }

        // Still onboarding: phone is on pending_profiles only until activation.
        const pendingSnaps =
            await snapshotsForPhoneVariants(
                db.collection("pending_profiles"),
                normalized,
            );

        const pendingMatchingDocs = pendingSnaps;

        if (pendingMatchingDocs.length === 1) {
          const uid = pendingMatchingDocs[0].id;
          try {
            const userRecord = await admin.auth().getUser(uid);
            const authEmail =
                typeof userRecord.email === "string" ?
                    userRecord.email.trim() :
                    "";
            if (!authEmail) {
              throw new HttpsError(
                  "not-found",
                  "No account uses this phone number.",
              );
            }
            return { ok: true, email: authEmail };
          } catch (err) {
            if (err instanceof HttpsError) throw err;
            console.error("[resolveDonorEmailForPhoneLogin] Auth lookup:", err);
            throw new HttpsError(
                "not-found",
                "No account uses this phone number.",
            );
          }
        }

        if (pendingMatchingDocs.length > 1) {
          /** @type {{ id: string, email: string }[]} */
          const withEmail = [];
          for (const doc of pendingMatchingDocs) {
            try {
              const rec = await admin.auth().getUser(doc.id);
              const authEmail =
                  typeof rec.email === "string" ? rec.email.trim() : "";
              if (authEmail) withEmail.push({ id: doc.id, email: authEmail });
            } catch (_) {
              // orphaned pending_profiles doc
            }
          }
          const distinctLower =
              [...new Set(withEmail.map((x) => x.email.toLowerCase()))];

          if (withEmail.length === pendingMatchingDocs.length &&
              distinctLower.length === 1) {
            return {
              ok: true,
              email: withEmail[0].email,
            };
          }

          console.error(
              "[resolveDonorEmailForPhoneLogin] duplicate phone pending",
              normalized,
              { count: pendingMatchingDocs.length },
          );
          throw new HttpsError(
              "failed-precondition",
              "Several onboarding accounts share this mobile. Sign in with "
                  + "your email or contact support.",
          );
        }

        const emailFromAuthPhone =
            await resolveDonorEmailViaAuthLinkedPhone(normalized);
        if (emailFromAuthPhone) {
          return { ok: true, email: emailFromAuthPhone };
        }

        throw new HttpsError(
            "not-found",
            "No account uses this phone number.",
        );
      } catch (err) {
        console.error("[resolveDonorEmailForPhoneLogin] ERROR:", err);
        throw toHttpsError(err, "Could not resolve account.");
      }
    },
);

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
        if (typeof user.phoneNumber === "string" && user.phoneNumber !== "") {
          continue;
        }
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
