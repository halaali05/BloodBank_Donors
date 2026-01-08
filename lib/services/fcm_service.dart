import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notif_service.dart';

class FCMService {
  static final FCMService instance = FCMService._();
  FCMService._();

  Future<void> initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // طلب إذن الإشعارات
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('📱 Notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // تهيئة إشعارات محلية
      await LocalNotifService.instance.init();

      // جلب التوكن وحفظه في Firestore
      String? token = await messaging.getToken();
      print('🔑 FCM Token: $token');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));

        // التحقق من حفظ التوكن
        final savedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final savedToken = savedDoc.data()?['fcmToken'];
        if (savedToken == token) {
          print('✅ Token verified in Firestore');
        } else {
          print('⚠️ Token mismatch! Saved: $savedToken, Current: $token');
        }
      }

      // الاستماع لتحديث التوكن
      messaging.onTokenRefresh.listen((newToken) async {
        print('🔄 FCM Token refreshed: $newToken');
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set({'fcmToken': newToken}, SetOptions(merge: true));
          print('✅ Refreshed FCM Token saved');
        }
      });

      // الاستماع للرسائل أثناء فتح التطبيق
      FirebaseMessaging.onMessage.listen((message) {
        print('📩 Foreground message received: ${message.data}');
        if (message.notification != null) {
          LocalNotifService.instance.show(
            title: message.notification?.title ?? 'New Notification',
            body: message.notification?.body ?? '',
          );
        } else if (message.data.isNotEmpty) {
          LocalNotifService.instance.show(
            title: message.data['title'] ?? 'Blood Request',
            body: message.data['body'] ?? 'New blood request available',
          );
        }
      });

      // الاستماع عند الضغط على الإشعار
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('🖱️ Notification clicked. Data: ${message.data}');
      });

      // التحقق إذا فتح التطبيق من حالة الإغلاق عبر إشعار
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App opened from terminated state via notification');
        print('🚀 Initial message data: ${initialMessage.data}');
      }
    } else {
      print('❌ Notification permission not granted');
    }
  }
}
