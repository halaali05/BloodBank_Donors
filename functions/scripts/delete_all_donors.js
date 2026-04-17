/**
 * Permanently removes all donor accounts from Firebase (Auth + Firestore + Storage).
 *
 * Prerequisites (run from repo root or functions/):
 *   - firebase-admin credentials, e.g. set GOOGLE_APPLICATION_CREDENTIALS to a
 *     service-account JSON with Firebase Authentication Admin + Cloud Datastore User
 *     + Storage Admin (or use `gcloud auth application-default login` if your org allows).
 *
 * Usage (repo root — uses functions/node_modules):
 *   npm run delete-all-donors -- --dry-run
 *   npm run delete-all-donors
 *
 * Or from functions/:
 *   npm run delete-all-donors -- --dry-run
 *   node scripts/delete_all_donors.js --dry-run
 */

const admin = require("firebase-admin");

const DRY_RUN =
  process.argv.includes("--dry-run") ||
  String(process.env.DRY_RUN || "").toLowerCase() === "1" ||
  String(process.env.DRY_RUN || "").toLowerCase() === "true";

function initAdmin() {
  if (admin.apps.length) return;
  try {
    admin.initializeApp();
  } catch (e) {
    console.error(
      "Failed to initialize Firebase Admin. Set GOOGLE_APPLICATION_CREDENTIALS or run from a Firebase project context.",
    );
    throw e;
  }
}

/** @param {FirebaseFirestore.CollectionReference} collRef */
async function deleteCollectionInBatches(collRef, batchSize = 400) {
  let total = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snap = await collRef.limit(batchSize).get();
    if (snap.empty) break;
    if (!DRY_RUN) {
      const batch = admin.firestore().batch();
      for (const d of snap.docs) batch.delete(d.ref);
      await batch.commit();
    }
    total += snap.size;
    if (snap.size < batchSize) break;
  }
  return total;
}

/** @param {string} uid */
async function deleteNotificationsForUser(uid) {
  const db = admin.firestore();
  const notifDoc = db.collection("notifications").doc(uid);
  const sub = notifDoc.collection("user_notifications");
  const n = await deleteCollectionInBatches(sub);
  if (!DRY_RUN) {
    await notifDoc.delete().catch(() => {});
  }
  return n;
}

/** @param {string} donorUid */
async function deleteMedicalReportsForDonor(donorUid) {
  const db = admin.firestore();
  const snap = await db
    .collection("medicalReports")
    .where("donorId", "==", donorUid)
    .get();
  if (DRY_RUN) return snap.size;
  for (let i = 0; i < snap.docs.length; i += 400) {
    const batch = db.batch();
    for (const d of snap.docs.slice(i, i + 400)) batch.delete(d.ref);
    await batch.commit();
  }
  return snap.size;
}

/** @param {string} donorUid */
async function deleteDonorResponseDocs(donorUid) {
  const db = admin.firestore();
  const FieldPath = admin.firestore.FieldPath;
  const snap = await db
    .collectionGroup("donorResponses")
    .where(FieldPath.documentId(), "==", donorUid)
    .get();
  if (DRY_RUN) return snap.size;
  for (let i = 0; i < snap.docs.length; i += 400) {
    const batch = db.batch();
    for (const d of snap.docs.slice(i, i + 400)) batch.delete(d.ref);
    await batch.commit();
  }
  return snap.size;
}

/** @param {string} uid */
async function deleteStoragePrefix(uid) {
  const bucket = admin.storage().bucket();
  const prefixes = [
    `medical_reports/${uid}/`,
    `profile_images/${uid}/`,
  ];
  let files = 0;
  for (const prefix of prefixes) {
    try {
      if (DRY_RUN) {
        const [arr] = await bucket.getFiles({ prefix, maxResults: 500 });
        files += arr.length;
        continue;
      }
      await bucket.deleteFiles({ prefix, force: true });
    } catch (e) {
      console.warn(`[storage] ${prefix}:`, e.message || e);
    }
  }
  return files;
}

/** @param {string} uid */
async function deleteDonorUid(uid) {
  const db = admin.firestore();
  const summary = {
    uid,
    notifications: 0,
    medicalReports: 0,
    donorResponses: 0,
    storageFiles: 0,
  };

  summary.notifications = await deleteNotificationsForUser(uid);
  summary.medicalReports = await deleteMedicalReportsForDonor(uid);
  summary.donorResponses = await deleteDonorResponseDocs(uid);
  summary.storageFiles = await deleteStoragePrefix(uid);

  if (!DRY_RUN) {
    await Promise.allSettled([
      db.collection("pending_profiles").doc(uid).delete(),
      db.collection("users").doc(uid).delete(),
    ]);
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      if (e && e.code === "auth/user-not-found") {
        console.warn(`[skip auth] ${uid}: user not found in Auth`);
      } else {
        throw e;
      }
    }
  }

  return summary;
}

async function collectDonorUids() {
  const db = admin.firestore();
  const uids = new Set();

  const usersSnap = await db.collection("users").where("role", "==", "donor").get();
  for (const d of usersSnap.docs) uids.add(d.id);

  const pendingSnap = await db
    .collection("pending_profiles")
    .where("role", "==", "donor")
    .get();
  for (const d of pendingSnap.docs) uids.add(d.id);

  return { uids: [...uids], usersCount: usersSnap.size, pendingCount: pendingSnap.size };
}

async function main() {
  initAdmin();
  console.log(
    DRY_RUN ?
      "DRY RUN — no deletes will be performed.\n" :
      "LIVE RUN — donors will be permanently deleted.\n",
  );

  const { uids, usersCount, pendingCount } = await collectDonorUids();
  console.log(
    `Found ${uids.length} unique donor UID(s) ` +
      `(users role=donor: ${usersCount}, pending_profiles role=donor: ${pendingCount}).`,
  );

  if (uids.length === 0) {
    console.log("Nothing to do.");
    return;
  }

  let ok = 0;
  for (const uid of uids) {
    try {
      const s = await deleteDonorUid(uid);
      console.log(
        `${DRY_RUN ? "[dry-run]" : "[deleted]"} ${uid} ` +
          `notifDocs=${s.notifications} medicalReports=${s.medicalReports} ` +
          `donorResponses=${s.donorResponses} ` +
          (DRY_RUN ? `storage~=${s.storageFiles}` : "storage=prefixes cleared"),
      );
      ok++;
    } catch (e) {
      console.error(`FAILED ${uid}:`, e.message || e);
    }
  }

  console.log(`\nDone. ${ok}/${uids.length} donor UID(s) processed successfully.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
