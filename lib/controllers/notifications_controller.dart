import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/cloud_functions_service.dart';
import '../services/notification_service.dart';

/// In-app notification list + mark-read/delete helpers (all via backend functions).
///
/// Logic stays out of widgets.
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

  User? getCurrentUser() {
    return _auth.currentUser;
  }

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

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  Future<int> deleteOldNotifications({int days = 30}) async {
    try {
      return await _notificationService.deleteOldNotifications(days: days);
    } catch (e) {
      throw Exception('Failed to delete old notifications: $e');
    }
  }

  List<Map<String, dynamic>> getUnreadNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    return notifications.where((n) {
      final isRead = n['isRead'] == true || n['read'] == true;
      return !isRead;
    }).toList();
  }

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
