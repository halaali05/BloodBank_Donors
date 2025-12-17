import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _db = FirebaseFirestore.instance;

  Future<void> createNotification({
    required String userId,
    required String requestId,
    required String title,
    required String body,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'requestId': requestId,
      'title': title,
      'body': body,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }
}
