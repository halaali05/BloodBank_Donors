import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMService {
  static final FCMService instance = FCMService._();
  FCMService._();

  Future<void> initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // طلب إذن الإشعارات (مهم على iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // جلب FCM Token
      String? token = await messaging.getToken();
      print('FCM Token: $token');

      // خزنه في Firestore تحت بيانات المستخدم
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': token});
      }
    }

    // الاستماع للرسائل أثناء فتح التطبيق
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title}');
      // لو حبيت: تقدر تظهر Snackbar أو Local Notification هنا
    });

    // الاستماع للرسائل لما يضغط المستخدم على الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('User clicked notification: ${message.data}');
      // لو حبيت: تفتح صفحة معينة بناء على message.data
    });
  }
}
