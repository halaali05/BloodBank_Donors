import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/welcome_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/donor_dashboard_screen.dart';
import '../screens/blood_bank_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../services/cloud_functions_service.dart';
import '../models/user_model.dart' as models;
import 'local_notif_service.dart';

class FCMService {
  static final FCMService instance = FCMService._();
  FCMService._();

  /// Initializes Firebase Cloud Messaging (FCM) and sets up:
  /// - Notification permission request
  /// - Local notifications channel/config (Android/iOS)
  /// - Token retrieval + saving to Firestore
  /// - Token refresh listener
  /// - Foreground message listener (shows a local notification)
  /// - Notification click handlers (background + terminated)
  Future<void> initFCM() async {
    // Web has limited/background support for FCM in many setups, so we skip here.
    if (kIsWeb) return;

    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request notification permissions (iOS required, Android 13+ required).
    final NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Only continue if the user granted permission (or provisional permission on iOS).
    final bool permissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!permissionGranted) return;

    // Initialize local notifications BEFORE listening/handling messages,
    // so notification channels/config are ready.
    await LocalNotifService.instance.init();

    // Get the current device token and store it via Cloud Functions
    final String? token = await messaging.getToken();
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null && token != null) {
      // Update FCM token through Cloud Functions (server-side)
      try {
        final cloudFunctions = CloudFunctionsService();
        await cloudFunctions.updateFcmToken(fcmToken: token);
      } catch (e) {
        // Non-critical error - continue even if token update fails
        debugPrint('Failed to update FCM token: $e');
      }
    }

    // Listen for token updates (e.g., reinstall, security refresh, etc.)
    // and update via Cloud Functions
    messaging.onTokenRefresh.listen((String newToken) async {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Update FCM token through Cloud Functions (server-side)
      try {
        final cloudFunctions = CloudFunctionsService();
        await cloudFunctions.updateFcmToken(fcmToken: newToken);
      } catch (e) {
        // Non-critical error - continue even if token update fails
        debugPrint('Failed to update FCM token on refresh: $e');
      }
    });

    // Foreground messages:
    // FCM does NOT always show a system notification automatically in foreground,
    // so we manually display a local notification.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final String requestId = (message.data['requestId'] as String?) ?? '';

      // For data-only messages, title/body are commonly stored inside data.
      // Fallback to notification payload if present.
      final String title =
          (message.data['title'] as String?) ??
          message.notification?.title ??
          'Blood Request';

      final String body =
          (message.data['body'] as String?) ??
          message.notification?.body ??
          'New blood request available';

      // Show a local notification so it appears in the system tray.
      LocalNotifService.instance.show(
        title: title,
        body: body,
        payload: requestId, // Used for navigation when user taps.
      );
    });

    // When the user taps a notification while the app is in background:
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data);
    });

    // If the app was launched from a terminated state by tapping a notification:
    final RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      // Delay navigation until after the first frame to ensure:
      // - navigatorKey has a context
      // - Firebase/Auth state is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationClick(initialMessage.data);
        });
      });
    }
  }

  /// Handles notification taps and navigates based on authentication state
  /// - If authenticated: Navigate to appropriate dashboard (donor or blood bank)
  /// - If not authenticated: Navigate to welcome screen
  void _handleNotificationClick(Map<String, dynamic> data) async {
    final BuildContext? context = navigatorKey.currentContext;

    // If the Navigator context is not ready yet, retry shortly.
    if (context == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationClick(data);
      });
      return;
    }

    // Determine whether the user is truly authenticated.
    // Checking only `currentUser != null` is not always enough,
    // so we also attempt to fetch a valid ID token.
    bool isAuthenticated = false;
    User? user;

    try {
      user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        try {
          await user.getIdToken();
          isAuthenticated = true;
        } catch (_) {
          isAuthenticated = false;
          user = null;
        }
      }

      // If no valid user immediately, wait briefly for auth state to resolve.
      if (!isAuthenticated && user == null) {
        try {
          user = await FirebaseAuth.instance
              .authStateChanges()
              .timeout(const Duration(seconds: 1))
              .first;

          if (user != null) {
            try {
              await user.getIdToken();
              isAuthenticated = true;
            } catch (_) {
              isAuthenticated = false;
              user = null;
            }
          }
        } catch (_) {
          isAuthenticated = false;
          user = null;
        }
      }
    } catch (_) {
      isAuthenticated = false;
      user = null;
    }

    // If not authenticated, navigate to welcome screen
    if (!isAuthenticated || user == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
      return;
    }

    // If authenticated, navigate to notifications screen with Unread tab selected
    try {
      final authService = AuthService();
      final userData = await authService.getUserData(user.uid);

      if (userData == null) {
        // If user data not found, go to welcome screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
        return;
      }

      // Navigate to dashboard first, then push notifications screen on top
      // This ensures back button works properly
      if (userData.role == models.UserRole.donor) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
          (route) => false,
        );
        // Push notifications screen on top after a short delay to ensure dashboard is built
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(initialTabIndex: 1),
              ),
            );
          }
        });
      } else if (userData.role == models.UserRole.hospital) {
        final bloodBankName = userData.bloodBankName ?? 'Blood Bank';
        final location = userData.location ?? 'Unknown';
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BloodBankDashboardScreen(
              bloodBankName: bloodBankName,
              location: location,
            ),
          ),
          (route) => false,
        );
        // Push notifications screen on top after a short delay to ensure dashboard is built
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(initialTabIndex: 1),
              ),
            );
          }
        });
      } else {
        // Unknown role, go to welcome screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      // If role lookup fails, navigate to welcome screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }
}
