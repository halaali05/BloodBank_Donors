import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db;

  NotificationService._() : _db = FirebaseFirestore.instance;

  NotificationService.test(this._db);

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
