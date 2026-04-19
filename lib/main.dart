import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'views/welcome_screen.dart';
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

    final requestId = message.data['requestId']?.toString() ?? '';
    final bool isUrgent =
        (message.data['isUrgent']?.toString().toLowerCase() ?? '') == 'true';
    final String type = message.data['type']?.toString() ?? 'request';
    final title =
        message.data['title']?.toString() ??
        message.notification?.title ??
        'Blood Request';
    final body =
        message.data['body']?.toString() ??
        message.notification?.body ??
        'New blood request available';

    // Initialize local notification service
    // This must be done in the background handler to ensure channel exists
    await LocalNotifService.instance.init();

    // Show local notification - this will appear in system tray
    await LocalNotifService.instance.show(
      title: title,
      body: body,
      isUrgent: type == 'request' && isUrgent,
      payload: jsonEncode({
        'type': type,
        'requestId': requestId,
        'senderId': message.data['senderId']?.toString() ?? '',
        'recipientId': message.data['recipientId']?.toString() ?? '',
      }),
    );
  } catch (e) {
    // Error handling: Try to show a basic notification even if initialization fails
    // This ensures users still receive notifications even if there's a configuration issue
    try {
      await LocalNotifService.instance.init();
      await LocalNotifService.instance.show(
        title: 'Blood Request',
        body: 'New blood request available',
        isUrgent:
            (message.data['type']?.toString() ?? 'request') == 'request' &&
            (message.data['isUrgent']?.toString().toLowerCase() ?? '') ==
                'true',
        payload: jsonEncode({
          'type': message.data['type']?.toString() ?? 'request',
          'requestId': message.data['requestId']?.toString() ?? '',
          'senderId': message.data['senderId']?.toString() ?? '',
          'recipientId': message.data['recipientId']?.toString() ?? '',
        }),
      );
    } catch (_) {
      // Failed to show fallback notification - silently fail
      // Background handler should not throw exceptions
    }
  }
}

/// Web-only FCM startup; use try/catch instead of [Future.catchError] so the
/// error handler return type cannot trip `Future<void>` / JS interop.
Future<void> _initFcmForWeb() async {
  try {
    await FCMService.instance.initFCM();
  } catch (e, st) {
    debugPrint('FCM init (web): $e');
    debugPrint('$st');
  }
}

// ------------------ App Initialization ------------------
/// **Single entry point** for every platform Flutter supports here
/// (Android, iOS, Web, Windows, Linux, macOS). Do not add a separate
/// `main` for web; `flutter run` / `flutter build` use this file by default.
///
/// Initialization flow:
/// 1. Ensure Flutter bindings are initialized
/// 2. Initialize Firebase
/// 3. Register background message handler (mobile only)
/// 4. Initialize FCM service
/// 5. Run the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(details.exceptionAsString());
  };

  try {
    await _bootstrapApp();
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(_StartupFailureApp(message: '$e'));
  }
}

Future<void> _bootstrapApp() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  if (!kIsWeb) {
    await LocalNotifService.instance.init();
    await FCMService.instance.initFCM();
  }

  runApp(const HayatApp());

  if (kIsWeb) {
    unawaited(_initFcmForWeb());

    final encodedPayload = Uri.base.queryParameters['notificationData'];
    if (encodedPayload != null && encodedPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(encodedPayload);
        if (decoded is Map<String, dynamic>) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 600), () {
              FCMService.instance.handleNotificationPayload(decoded);
            });
          });
        }
      } catch (_) {}
    }
  }
}

/// Shown if Firebase/bootstrap throws before [HayatApp] can run (helps debug web).
class _StartupFailureApp extends StatelessWidget {
  final String message;

  const _StartupFailureApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'App failed to start.\n\n$message',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
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
      title: 'HAYAH',
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
      // Web: bundled "Roboto" is not included; unspecified uses a good system UI font.
      fontFamily: kIsWeb ? null : 'Roboto',
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
