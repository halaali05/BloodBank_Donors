import 'cloud_functions_service.dart';

/// Service class for managing notifications
/// Uses Cloud Functions as a secure layer for all write operations
class NotificationService {
  static final NotificationService instance = NotificationService._();

  final CloudFunctionsService _cloudFunctions;

  NotificationService._() : _cloudFunctions = CloudFunctionsService();

  NotificationService.test(CloudFunctionsService? cloudFunctions)
    : _cloudFunctions = cloudFunctions ?? CloudFunctionsService();

  /// Marks all unread notifications as read via Cloud Functions
  Future<void> markAllAsRead() async {
    await _cloudFunctions.markNotificationsAsRead();
  }

  /// Deletes a specific notification via Cloud Functions
  Future<void> deleteNotification(String notificationId) async {
    await _cloudFunctions.deleteNotification(notificationId: notificationId);
  }

  // Note: createNotification is now handled by Cloud Functions
  // when addRequest is called with isUrgent = true
}