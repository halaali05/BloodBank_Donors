/**
 * Wipes Firestore data used by this app (and optionally Auth + Storage).
 *
 * Firestore (always when --execute):
 *   - requests/* (+ messages, donorResponses)
 *   - notifications/* (+ user_notifications)
 *   - medicalReports/*
 *   - users/*
 *   - pending_profiles/*
 *
 * Prerequisites: GOOGLE_APPLICATION_CREDENTIALS (or ADC) with permissions
 * for Firestore, and optionally Firebase Authentication Admin + Storage Admin.
 *
 * Usage:
 *   npm run wipe-all-data
 *   npm run wipe-all-data -- --execute
 *   npm run wipe-all-data -- --execute --auth
 *   npm run wipe-all-data -- --execute --storage
 *
 * From functions/: node scripts/wipe_all_app_data.js
 */

const admin = require("firebase-admin");

const EXECUTE = process.argv.includes("--execute");
const WITH_AUTH = process.argv.includes("--auth");
const WITH_STORAGE = process.argv.includes("--storage");

function initAdmin() {
  if (admin.apps.length) return;
  try {
    admin.initializeApp();
  } catch (e) {
    console.error("Failed to initialize Firebase Admin:", e.message || e);
    throw e;
  }
}

/** @param {FirebaseFirestore.CollectionReference} collRef */
async function deleteCollectionInBatches(collRef, batchSize = 400) {
  const db = admin.firestore();
  let total = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snap = await collRef.limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    for (const d of snap.docs) batch.delete(d.ref);
    await batch.commit();
    total += snap.size;
    if (snap.size < batchSize) break;
  }
  return total;
}

/** @param {FirebaseFirestore.CollectionReference} collRef */
async function countCollection(collRef) {
  const snap = await collRef.count().get();
  return snap.data().count;
}

async function printDryRunSummary(db) {
  console.log("\n--- Dry run (no changes) ---\n");
  try {
    const [reqC, usrC, penC, medC, notifTop] = await Promise.all([
      countCollection(db.collection("requests")),
      countCollection(db.collection("users")),
      countCollection(db.collection("pending_profiles")),
      countCollection(db.collection("medicalReports")),
      countCollection(db.collection("notifications")),
    ]);
    console.log(`  requests (documents):           ${reqC}`);
    console.log(`  users:                          ${usrC}`);
    console.log(`  pending_profiles:               ${penC}`);
    console.log(`  medicalReports:                 ${medC}`);
    console.log(`  notifications (parent docs):  ${notifTop}`);
    console.log(
      "\n  Subcollections under each request (messages, donorResponses)",
    );
    console.log("  and under each notifications doc (user_notifications)");
    console.log("  will be deleted when you run with --execute.\n");
  } catch (e) {
    console.warn("Could not run count() queries:", e.message || e);
  }
  console.log("To permanently delete the Firestore data above, run:");
  console.log("  npm run wipe-all-data -- --execute\n");
  console.log("Optional (same command, add flags):");
  console.log("  --auth     Delete every Firebase Authentication user");
  console.log(
    "  --storage  Delete Storage under prefixes medical_reports/ and profile_images/",
  );
}

async function wipeNotifications(db) {
  const parents = await db.collection("notifications").get();
  let subDocs = 0;
  for (const doc of parents.docs) {
    subDocs += await deleteCollectionInBatches(
      doc.ref.collection("user_notifications"),
    );
    await doc.ref.delete();
  }
  return { parents: parents.size, subDocs };
}

async function wipeRequests(db) {
  const parents = await db.collection("requests").get();
  let messages = 0;
  let responses = 0;
  for (const doc of parents.docs) {
    messages += await deleteCollectionInBatches(doc.ref.collection("messages"));
    responses += await deleteCollectionInBatches(
      doc.ref.collection("donorResponses"),
    );
    await doc.ref.delete();
  }
  return {
    requests: parents.size,
    messages,
    donorResponses: responses,
  };
}

async function wipeAllAuthUsers() {
  let deleted = 0;
  let nextPageToken;
  do {
    const res = await admin.auth().listUsers(1000, nextPageToken);
    nextPageToken = res.pageToken;
    for (const u of res.users) {
      try {
        await admin.auth().deleteUser(u.uid);
        deleted++;
      } catch (e) {
        console.warn(`[auth] skip ${u.uid}:`, e.message || e);
      }
    }
  } while (nextPageToken);
  return deleted;
}

async function wipeKnownStoragePrefixes() {
  const bucket = admin.storage().bucket();
  const prefixes = ["medical_reports/", "profile_images/"];
  for (const prefix of prefixes) {
    try {
      await bucket.deleteFiles({ prefix, force: true });
      console.log(`[storage] cleared prefix: ${prefix}`);
    } catch (e) {
      console.warn(`[storage] ${prefix}:`, e.message || e);
    }
  }
}

async function main() {
  initAdmin();
  const db = admin.firestore();

  if (!EXECUTE) {
    await printDryRunSummary(db);
    return;
  }

  console.log(
    "\n*** EXECUTE: wiping Firestore app collections (this cannot be undone) ***\n",
  );

  const reqStats = await wipeRequests(db);
  console.log("[firestore] requests:", reqStats);

  const notifStats = await wipeNotifications(db);
  console.log("[firestore] notifications:", notifStats);

  const med = await deleteCollectionInBatches(db.collection("medicalReports"));
  console.log("[firestore] medicalReports docs deleted:", med);

  const users = await deleteCollectionInBatches(db.collection("users"));
  console.log("[firestore] users docs deleted:", users);

  const pending = await deleteCollectionInBatches(
    db.collection("pending_profiles"),
  );
  console.log("[firestore] pending_profiles docs deleted:", pending);

  if (WITH_AUTH) {
    console.log("\n*** Deleting all Firebase Auth users ***\n");
    const n = await wipeAllAuthUsers();
    console.log("[auth] deleted users:", n);
  }

  if (WITH_STORAGE) {
    console.log("\n*** Clearing known Storage prefixes ***\n");
    await wipeKnownStoragePrefixes();
  }

  console.log("\nDone.\n");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
