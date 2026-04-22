/**
 * Post-donation cooldown & medical restriction live here (not on users/{uid}).
 * Doc id = donor Firebase Auth UID.
 */
const COLLECTION = "donorDonationSchedule";

const COOLDOWN_FIELD_KEYS = [
  "lastDonatedAt",
  "nextDonationEligibleAt",
  "restrictedUntil",
  "restrictionReason",
];

function scheduleRef(db, donorId) {
  const id = String(donorId ?? "").trim();
  return db.collection(COLLECTION).doc(id);
}

/**
 * Overlay schedule document onto user map for cooldown / restriction checks.
 * Fields present on the schedule doc override user doc (migration: user may still hold legacy copies).
 */
function mergeUserWithScheduleSnap(userData, scheduleSnap) {
  const out = { ...(userData || {}) };
  if (!scheduleSnap || !scheduleSnap.exists) return out;
  const s = scheduleSnap.data() || {};
  for (const k of COOLDOWN_FIELD_KEYS) {
    if (Object.prototype.hasOwnProperty.call(s, k)) {
      out[k] = s[k];
    }
  }
  return out;
}

module.exports = {
  COLLECTION,
  COOLDOWN_FIELD_KEYS,
  scheduleRef,
  mergeUserWithScheduleSnap,
};
