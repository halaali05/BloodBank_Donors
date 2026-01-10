import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/cloud_functions_service.dart';
import '../services/notification_service.dart';

/// Controller for notifications screen business logic
/// Separates business logic from UI for better maintainability
///
/// SECURITY ARCHITECTURE:
/// - All reads go through Cloud Functions (server-side)
/// - All writes go through Cloud Functions (server-side)
/// - Server validates user authentication
/// - Server ensures users can only access their own notifications
class NotificationsController {
  final CloudFunctionsService _cloudFunctions;
  final NotificationService _notificationService;
  final FirebaseAuth _auth;

  NotificationsController({
    CloudFunctionsService? cloudFunctions,
    NotificationService? notificationService,
    FirebaseAuth? auth,
  }) : _cloudFunctions = cloudFunctions ?? CloudFunctionsService(),
       _notificationService =
           notificationService ?? NotificationService.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // ------------------ Authentication ------------------
  /// Gets the current authenticated user
  /// Returns null if user is not authenticated
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ------------------ Data Fetching ------------------
  /// Fetches all notifications for the authenticated user via Cloud Functions
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures users can only view their own notifications
  ///
  /// Returns:
  /// - List of notification maps
  ///
  /// Throws:
  /// - Exception if fetch fails
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final result = await _cloudFunctions.getNotifications();
      final notificationsData = result['notifications'] as List<dynamic>? ?? [];

      return notificationsData
          .map((n) => Map<String, dynamic>.from(n))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  // ------------------ Notification Operations ------------------
  /// Marks all unread notifications as read
  ///
  /// Security Architecture:
  /// - All writes go through Cloud Functions (server-side)
  /// - Server validates user authentication
  ///
  /// Throws:
  /// - Exception if operation fails
  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  /// Marks a single notification as read
  ///
  /// Security Architecture:
  /// - All writes go through Cloud Functions (server-side)
  /// - Server validates user authentication
  ///
  /// Parameters:
  /// - [notificationId]: The ID of the notification to mark as read
  ///
  /// Throws:
  /// - Exception if operation fails
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Deletes a specific notification
  ///
  /// Security Architecture:
  /// - All writes go through Cloud Functions (server-side)
  /// - Server validates user authentication
  ///
  /// Parameters:
  /// - [notificationId]: The ID of the notification to delete
  ///
  /// Throws:
  /// - Exception if operation fails
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  // ------------------ Data Processing ------------------
  /// Filters notifications to get only unread ones
  ///
  /// Parameters:
  /// - [notifications]: List of all notifications
  ///
  /// Returns:
  /// - List of unread notifications
  List<Map<String, dynamic>> getUnreadNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    return notifications.where((n) {
      final isRead = n['isRead'] == true || n['read'] == true;
      return !isRead;
    }).toList();
  }

  /// Formats timestamp to readable text (Today, Yesterday, or date)
  ///
  /// Parameters:
  /// - [timestampMillis]: Timestamp in milliseconds
  /// - [context]: BuildContext for time formatting
  ///
  /// Returns:
  /// - Formatted time string
  String formatTime(BuildContext context, int? timestampMillis) {
    if (timestampMillis == null) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    final t = TimeOfDay.fromDateTime(dateTime).format(context);

    if (diff.inDays == 0) return 'Today • $t';
    if (diff.inDays == 1) return 'Yesterday • $t';
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }
}
