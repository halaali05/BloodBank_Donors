import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/local_notif_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📬 [FCM Background] Handling background message: ${message.messageId}');
  print('📬 [FCM Background] Title: ${message.notification?.title}');
  print('📬 [FCM Background] Body: ${message.notification?.body}');
  print('📬 [FCM Background] Data: ${message.data}');
  
  // You can show a local notification here if needed
  // LocalNotifService.instance.show(
  //   title: message.notification?.title ?? 'Notification',
  //   body: message.notification?.body ?? '',
  // );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize local notifications service early
  await LocalNotifService.instance.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const HayatApp());
}

class HayatApp extends StatelessWidget {
  const HayatApp({super.key});

  static const _primaryColor = Color(0xffe60012);
  static const _bgColor = Color(0xfff5f6fb);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hayat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: _bgColor,
        colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor),
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}
