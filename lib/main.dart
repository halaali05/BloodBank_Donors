import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'views/onboarding/welcome_screen.dart';
import 'services/fcm_service.dart';
import 'services/local_notif_service.dart';

// ------------------ Global State ------------------
/// Global navigator key for navigation from anywhere in the app
/// Used by notification handlers and services that need to navigate
/// outside of a BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// FCM when the app is in the background or fully closed.
/// Must stay a top-level function (Firebase runs it in its own isolate).
String _fcmNotificationPayloadJson(Map<String, dynamic> data) {
  return jsonEncode({
    'type': data['type']?.toString() ?? 'request',
    'requestId': data['requestId']?.toString() ?? '',
    'senderId': data['senderId']?.toString() ?? '',
    'recipientId': data['recipientId']?.toString() ?? '',
  });
}

Future<void> _showFcmBackgroundLocalNotification(
  RemoteMessage message, {
  String? titleOverride,
  String? bodyOverride,
}) async {
  final data = message.data;
  final type = data['type']?.toString() ?? 'request';
  final isUrgent = (data['isUrgent']?.toString().toLowerCase() ?? '') == 'true';
  final title =
      titleOverride ??
      data['title']?.toString() ??
      message.notification?.title ??
      'Blood Request';
  final body =
      bodyOverride ??
      data['body']?.toString() ??
      message.notification?.body ??
      'New blood request available';

  await LocalNotifService.instance.show(
    title: title,
    body: body,
    isUrgent: type == 'request' && isUrgent,
    payload: _fcmNotificationPayloadJson(data),
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await LocalNotifService.instance.init();
    await _showFcmBackgroundLocalNotification(message);
  } catch (e) {
    try {
      await LocalNotifService.instance.init();
      await _showFcmBackgroundLocalNotification(
        message,
        titleOverride: 'Blood Request',
        bodyOverride: 'New blood request available',
      );
    } catch (_) {}
  }
}

/// Web-only FCM setup (wrapped in try/catch so web builds stay stable).
Future<void> _initFcmForWeb() async {
  try {
    await FCMService.instance.initFCM();
  } catch (e, st) {
    debugPrint('FCM init (web): $e');
    debugPrint('$st');
  }
}

/// App entry for all platforms. Same `main()` is used for mobile and web builds.
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

  // Draw the first screen first; push setup runs on the next frame (mobile).
  runApp(const HayatApp());

  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initMobilePushAfterFirstFrame());
    });
  }

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

Future<void> _initMobilePushAfterFirstFrame() async {
  try {
    await LocalNotifService.instance.init();
    await FCMService.instance.initFCM();
  } catch (e, st) {
    debugPrint('Push init after first frame: $e');
    debugPrint('$st');
  }
}

/// Fallback UI if Firebase or startup crashes (useful on web during setup).
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

/// Root [MaterialApp]: theme, navigator key, and first screen ([WelcomeScreen]).
class HayatApp extends StatelessWidget {
  const HayatApp({super.key});

  static const _primaryColor = Color(0xffe60012);
  static const _bgColor = Color(0xfff5f6fb);

  /// Built once — avoids rebuilding heavy [ThemeData] every frame.
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: _bgColor,
    colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor),
    fontFamily: kIsWeb ? null : 'Roboto',
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'HAYAH',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const WelcomeScreen(),
    );
  }
}
