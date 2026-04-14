"use strict";

/**
 * Gen2 HTTPS callables run on Cloud Run. Browsers (Flutter Web, etc.) send an
 * unauthenticated OPTIONS preflight; without invoker "public", Cloud Run returns 403.
 * Handlers still enforce Firebase Auth via request.auth.
 */
const publicCallableOpts = {
  region: "us-central1",
  invoker: "public",
  cors: true,
};

module.exports = { publicCallableOpts };
