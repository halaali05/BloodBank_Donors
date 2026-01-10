const { HttpsError } = require("firebase-functions/v2/https");

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
            : fallbackMessage || "Server error occurred.";

    return new HttpsError("internal", msg);
}

module.exports = {
    requireAuth,
    nonEmptyString,
    toHttpsError,
};
