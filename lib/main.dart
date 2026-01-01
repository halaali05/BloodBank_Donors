import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// لتلقي الرسائل حتى لو التطبيق في الخلفية أو مسكر
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // هنا ممكن تعمل أي شيء بالرسالة، حالياً بنسجلها بالـ console
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تسجيل الـ background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // طلب صلاحيات الإشعارات على iOS (Android غالباً مش مطلوب)
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
      ),
      home: const LoginScreen(),
    );
  }
}
