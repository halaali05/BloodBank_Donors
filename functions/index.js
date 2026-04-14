const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");

// Initialize Firebase Admin
admin.initializeApp();

// Set global options for all functions
// invoker: "public" — required for Gen2 callables from Flutter Web / browsers (OPTIONS
// preflight hits Cloud Run without end-user IAM). Handlers still enforce Firebase Auth.
setGlobalOptions({ region: "us-central1", invoker: "public" });

// Import and export all functions from separate modules
const authFunctions = require("./src/auth");
const requestFunctions = require("./src/requests");
const notificationFunctions = require("./src/notifications");
const donorMgmt = require("./donor_management_functions");

// Export all authentication and user profile functions
exports.createPendingProfile = authFunctions.createPendingProfile;
exports.completeProfileAfterVerification =
  authFunctions.completeProfileAfterVerification;
exports.getUserData = authFunctions.getUserData;
exports.getUserRole = authFunctions.getUserRole;
exports.updateLastLoginAt = authFunctions.updateLastLoginAt;
exports.updateFcmToken = authFunctions.updateFcmToken;
exports.updateUserProfile = authFunctions.updateUserProfile;
exports.cleanupUnverifiedUsers = authFunctions.cleanupUnverifiedUsers;

// Export all request and donor management functions
exports.addRequest = requestFunctions.addRequest;
exports.getDonors = requestFunctions.getDonors;
exports.getRequests = requestFunctions.getRequests;
exports.getRequestsByBloodBankId = requestFunctions.getRequestsByBloodBankId;
exports.setDonorRequestResponse = requestFunctions.setDonorRequestResponse;
exports.markRequestCompleted = requestFunctions.markRequestCompleted;
exports.updateRequestUnits = requestFunctions.updateRequestUnits;
exports.getRequestDonorResponses = requestFunctions.getRequestDonorResponses;
exports.deleteRequest = requestFunctions.deleteRequest;
exports.cleanupExpiredRequests = requestFunctions.cleanupExpiredRequests;

// Export all notification and messaging functions
exports.getNotifications = notificationFunctions.getNotifications;
exports.getMessages = notificationFunctions.getMessages;
exports.ensureDonorWelcomeMessage =
  notificationFunctions.ensureDonorWelcomeMessage;
exports.markNotificationsAsRead = notificationFunctions.markNotificationsAsRead;
exports.markNotificationAsRead = notificationFunctions.markNotificationAsRead;
exports.deleteNotification = notificationFunctions.deleteNotification;
exports.deleteOldNotifications = notificationFunctions.deleteOldNotifications;
exports.sendMessage = notificationFunctions.sendMessage;
exports.cleanupOrphanNotifications =
  notificationFunctions.cleanupOrphanNotifications;
exports.cleanupOrphanMessages = notificationFunctions.cleanupOrphanMessages;

// Export donor management functions
exports.scheduleDonorAppointment = donorMgmt.scheduleDonorAppointment;
exports.saveMedicalReport = donorMgmt.saveMedicalReport;
exports.getDonationHistory = donorMgmt.getDonationHistory;
