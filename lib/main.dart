import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'services/fcm_service.dart';
import 'services/local_notif_service.dart';

// ------------------ Global State ------------------
/// Global navigator key for navigation from anywhere in the app
/// Used by notification handlers and services that need to navigate
/// outside of a BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ------------------ Background Message Handler ------------------
/// Handles Firebase Cloud Messaging (FCM) messages when app is in background/terminated
///
/// This handler runs in a separate isolate and MUST be a top-level function.
/// It cannot access app state or use any instance methods.
///
/// Flow:
/// 1. Initialize Firebase in the background isolate
/// 2. Extract notification data from message payload
/// 3. Initialize local notification service
/// 4. Display local notification to user
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase in the background isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Extract notification content from data payload
    final requestId = message.data['requestId'] as String? ?? '';
    final title = message.data['title'] as String? ?? 'Blood Request';
    final body =
        message.data['body'] as String? ?? 'New blood request available';

    // Initialize local notification service
    // This must be done in the background handler to ensure channel exists
    await LocalNotifService.instance.init();

    // Show local notification - this will appear in system tray
    await LocalNotifService.instance.show(
      title: title,
      body: body,
      payload: requestId,
    );
  } catch (e) {
    // Error handling: Try to show a basic notification even if initialization fails
    // This ensures users still receive notifications even if there's a configuration issue
    try {
      await LocalNotifService.instance.init();
      await LocalNotifService.instance.show(
        title: 'Blood Request',
        body: 'New blood request available',
        payload: message.data['requestId'] as String? ?? '',
      );
    } catch (_) {
      // Failed to show fallback notification - silently fail
      // Background handler should not throw exceptions
    }
  }
}

// ------------------ App Initialization ------------------
/// Main entry point of the application
///
/// Initialization flow:
/// 1. Ensure Flutter bindings are initialized
/// 2. Initialize Firebase
/// 3. Register background message handler (mobile only)
/// 4. Initialize FCM service
/// 5. Run the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background message handler only on mobile platforms (not web)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize Firebase Cloud Messaging for push notifications
  await FCMService.instance.initFCM();

  runApp(const HayatApp());
}

// ------------------ App Widget ------------------
/// Root widget of the application
///
/// Configures:
/// - Global navigation key
/// - App theme and styling
/// - Initial route (WelcomeScreen)
class HayatApp extends StatelessWidget {
  const HayatApp({super.key});

  // Theme colors
  static const _primaryColor = Color(0xffe60012);
  static const _bgColor = Color(0xfff5f6fb);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Hayat',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const WelcomeScreen(),
    );
  }

  /// Builds the app theme configuration
  ThemeData _buildTheme() {
    return ThemeData(
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
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
