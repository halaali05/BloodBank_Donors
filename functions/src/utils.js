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
 * Normalize donor mobile to E.164 +9627xxxxxxxx (Jordan).
 * Accepts 07XXXXXXXX, +9627XXXXXXXX, 9627XXXXXXXX, 00962…, optional spaces/dashes.
 * @param {*} input
 * @return {string|null}
 */
function normalizeJordanMobile(input) {
  if (typeof input !== "string") return null;
  let s = input.replace(/[\s\-.]/g, "");
  if (s === "") return null;
  if (s.startsWith("00962")) s = "+962" + s.slice(5);
  if (s.startsWith("962") && !s.startsWith("+962")) s = "+962" + s.slice(3);
  if (s.startsWith("+962")) {
    const rest = s.slice(4);
    return /^7\d{8}$/.test(rest) ? "+962" + rest : null;
  }
  if (/^07\d{8}$/.test(s)) return "+962" + s.slice(1);
  if (/^7\d{8}$/.test(s)) return "+962" + s;
  return null;
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
  parseDonorGender,
};
