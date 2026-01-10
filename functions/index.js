const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");

// Initialize Firebase Admin
admin.initializeApp();

// Set global options for all functions
setGlobalOptions({ region: "us-central1" });

// Import and export all functions from separate modules
const authFunctions = require("./src/auth");
const requestFunctions = require("./src/requests");
const notificationFunctions = require("./src/notifications");

// Export all authentication and user profile functions
exports.createPendingProfile = authFunctions.createPendingProfile;
exports.completeProfileAfterVerification = authFunctions.completeProfileAfterVerification;
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
exports.deleteRequest = requestFunctions.deleteRequest;
exports.sendRequestMessageToDonors = requestFunctions.sendRequestMessageToDonors;

// Export all notification and messaging functions
exports.getNotifications = notificationFunctions.getNotifications;
exports.getMessages = notificationFunctions.getMessages;
exports.markNotificationsAsRead = notificationFunctions.markNotificationsAsRead;
exports.markNotificationAsRead = notificationFunctions.markNotificationAsRead;
exports.deleteNotification = notificationFunctions.deleteNotification;
exports.sendMessage = notificationFunctions.sendMessage;
exports.cleanupOrphanNotifications = notificationFunctions.cleanupOrphanNotifications;
exports.cleanupOrphanMessages = notificationFunctions.cleanupOrphanMessages; 
