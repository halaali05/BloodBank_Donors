import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notif_service.dart';

class FCMService {
  // Singleton
  static final FCMService instance = FCMService._();
  FCMService._();

  /// يهيئ FCM، يحفظ التوكن، ويستمع للرسائل
  Future<void> initFCM() async {
    try {
      print('🚀 [FCM] Starting FCM initialization...');

      // Initialize local notifications service first
      await LocalNotifService.instance.init();
      print('✅ [FCM] Local notifications initialized');

      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1️⃣ طلب إذن الإشعارات (مهم على iOS)
      print('📱 [FCM] Requesting notification permissions...');
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('📱 [FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 2️⃣ جلب FCM Token
        print('🔑 [FCM] Getting FCM token...');
        String? token = await messaging.getToken();

        if (token != null) {
          print('✅ [FCM] FCM Token received: ${token.substring(0, 20)}...');
        } else {
          print('❌ [FCM] FCM Token is null!');
          return;
        }

        // 3️⃣ حفظ التوكن في Firestore لكل مستخدم
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            print('💾 [FCM] Saving token for user: ${currentUser.uid}');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .set({'fcmToken': token}, SetOptions(merge: true));
            print(
              '✅ [FCM] FCM Token saved successfully for user ${currentUser.uid}',
            );

            // Verify it was saved
            final savedDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
            final savedToken = savedDoc.data()?['fcmToken'];
            if (savedToken == token) {
              print('✅ [FCM] Token verified in Firestore');
            } else {
              print(
                '⚠️ [FCM] Token mismatch! Saved: ${savedToken?.substring(0, 20)}..., Current: ${token.substring(0, 20)}...',
              );
            }
          } catch (e, stackTrace) {
            print('❌ [FCM] Failed to save FCM token: $e');
            print('❌ [FCM] Stack trace: $stackTrace');
          }
        } else {
          print('⚠️ [FCM] No current user. User: ${currentUser?.uid}');
        }

        // 4️⃣ Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          print(
            '🔄 [FCM] FCM Token refreshed: ${newToken.substring(0, 20)}...',
          );
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .set({'fcmToken': newToken}, SetOptions(merge: true))
                .then((_) => print('✅ [FCM] Refreshed FCM Token saved'))
                .catchError(
                  (e) => print('❌ [FCM] Failed to save refreshed token: $e'),
                );
          }
        });
      } else {
        print(
          '❌ [FCM] Notification permission not granted. Status: ${settings.authorizationStatus}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ [FCM] Error initializing FCM: $e');
      print('❌ [FCM] Stack trace: $stackTrace');
    }

    // 5️⃣ الاستماع للرسائل أثناء فتح التطبيق (FOREGROUND)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 [FCM] Foreground message received!');
      print('📩 [FCM] Message ID: ${message.messageId}');
      print('📩 [FCM] Notification title: ${message.notification?.title}');
      print('📩 [FCM] Notification body: ${message.notification?.body}');
      print('📩 [FCM] Data: ${message.data}');

      // Show local notification when app is in foreground
      if (message.notification != null) {
        final title = message.notification?.title ?? 'New Notification';
        final body = message.notification?.body ?? '';

        print('📱 [FCM] Showing local notification: $title - $body');
        LocalNotifService.instance.show(title: title, body: body);
      } else if (message.data.isNotEmpty) {
        // If notification payload is missing but data exists, show from data
        final title = message.data['title'] ?? 'Blood Request';
        final body = message.data['body'] ?? 'New blood request available';

        print('📱 [FCM] Showing local notification from data: $title - $body');
        LocalNotifService.instance.show(
          title: title.toString(),
          body: body.toString(),
        );
      } else {
        print('⚠️ [FCM] Message received but no notification or data payload');
      }
    });

    // 6️⃣ الاستماع للرسائل لما يضغط المستخدم على الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🖱️ [FCM] User clicked notification!');
      print('🖱️ [FCM] Message data: ${message.data}');
      print('🖱️ [FCM] Request ID: ${message.data['requestId']}');
      // هنا ممكن تفتح صفحة معينة بناءً على message.data
      // مثال: فتح صفحة تفاصيل طلب الدم
      // Navigator.of(context).push(MaterialPageRoute(
      //   builder: (_) => RequestDetailsScreen(requestId: message.data['requestId']),
      // ));
    });

    // 7️⃣ Check if app was opened from a terminated state
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      print('🚀 [FCM] App opened from terminated state via notification');
      print('🚀 [FCM] Initial message data: ${initialMessage.data}');
    }

    print('✅ [FCM] FCM initialization completed');
  }
}
