import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FCMService {
  // Singleton
  static final FCMService instance = FCMService._();
  FCMService._();

  /// يهيئ FCM، يحفظ التوكن، ويستمع للرسائل
  Future<void> initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1️⃣ طلب إذن الإشعارات (مهم على iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2️⃣ جلب FCM Token
      String? token = await messaging.getToken();
      print('✅ FCM Token: $token');

      // 3️⃣ حفظ التوكن في Firestore لكل مستخدم
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': token});
        print('✅ FCM Token saved for user ${currentUser.uid}');
      }
    }

    // 4️⃣ الاستماع للرسائل أثناء فتح التطبيق
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground message received: ${message.notification?.title}');
      if (message.notification != null) {
        // مثال: تظهر Snackbar داخل التطبيق
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(message.notification!.body ?? '')),
        // );
      }
    });

    // 5️⃣ الاستماع للرسائل لما يضغط المستخدم على الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🖱️ User clicked notification: ${message.data}');
      // هنا ممكن تفتح صفحة معينة بناءً على message.data
      // مثال: فتح صفحة تفاصيل طلب الدم
      // Navigator.of(context).push(MaterialPageRoute(
      //   builder: (_) => RequestDetailsScreen(requestId: message.data['requestId']),
      // ));
    });
  }
}
