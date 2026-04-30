const {HttpsError} = require("firebase-functions/v2/https");

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
 * Normalize Jordan **mobile** to E.164 +9627xxxxxxxx.
 * Mirrors Flutter `JordanPhone` rules: digits only after stripping non-digits;
 * allowed forms 07[789] + 7 digits, or 9627[789] + 7 digits; 00962… → 962….
 * @param {*} input
 * @return {string|null}
 */
function normalizeJordanMobile(input) {
  if (typeof input !== "string") return null;
  let digits = input.replace(/\D/g, "");
  if (!digits.length) return null;
  if (digits.startsWith("00962")) digits = digits.slice(2);

  // Local mobile without leading 0: `79…`, `77…`, `78…` (9 digits → `+96279…`).
  if (/^7[789]\d{7}$/.test(digits)) {
    return "+962" + digits;
  }

  const strict = /^(07[789]\d{7}|9627[789]\d{7})$/;
  if (!strict.test(digits)) return null;
  if (digits.startsWith("07")) return "+962" + digits.slice(1);
  if (digits.startsWith("962")) return "+" + digits;
  return null;
}

/**
 * Variants historically stored on `pending_profiles.phoneNumber` / `users.phoneNumber`.
 * Queries use exact-match `==`; older rows may omit `+` or use leading `07…`.
 *
 * @param {string|null} canonical E.164 e.g. +962791234567
 * @return {string[]}
 */
function jordanMobileFirestoreLookupVariants(canonical) {
  if (typeof canonical !== "string" || !canonical.startsWith("+962")) {
    return canonical ? [canonical.trim()] : [];
  }
  const t = canonical.trim();
  /** @type {Set<string>} */
  const uniq = new Set();

  uniq.add(t);

  const noPlus = t.slice(1); // 962791234567
  uniq.add(noPlus);

  const afterCountry = t.slice(4); // 791234567 for +962XXXXXXXXX
  if (/^7[789]\d{7}$/.test(afterCountry)) {
    uniq.add(`0${afterCountry}`);
  }

  return Array.from(uniq);
}

/**
 * @param {*} v
 * @return {"male"|"female"|null}
 */
function parseDonorGender(v) {
  if (typeof v !== "string") return null;
  const g = v.trim().toLowerCase();
  if (g === "male" || g === "female") return g;
  return null;
}

module.exports = {
  requireAuth,
  nonEmptyString,
  toHttpsError,
  normalizeJordanMobile,
  jordanMobileFirestoreLookupVariants,
  parseDonorGender,
};
