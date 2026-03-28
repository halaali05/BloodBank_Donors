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

  bool _listenersRegistered = false;
  bool _initialLaunchMessageHandled = false;

  /// Initializes Firebase Cloud Messaging (FCM) and sets up:
  /// - Local notification channel (Android)
  /// - Message / token listeners (registered once per process)
  /// - Permission request
  /// - Token saved to backend when user is signed in
  /// - Foreground: local notification with sound
  /// - Background: OS shows FCM notification (server sends notification + channelId)
  Future<void> initFCM() async {
    if (kIsWeb) return;

    await LocalNotifService.instance.init();

    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    if (!_listenersRegistered) {
      _listenersRegistered = true;
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage m) => _handleNotificationClick(m.data),
      );
      messaging.onTokenRefresh.listen(_onTokenRefresh);
    }

    final NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final bool permissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!permissionGranted) {
      debugPrint(
        'FCM: notification permission not granted; '
        'push may be limited until the user allows notifications.',
      );
    }

    await _syncTokenToServer();

    if (!_initialLaunchMessageHandled) {
      _initialLaunchMessageHandled = true;
      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 800), () {
            _handleNotificationClick(initialMessage.data);
          });
        });
      }
    }
  }

  /// Call after login (or when user becomes available) so the device token is
  /// stored under the correct account. Safe to call multiple times.
  Future<void> syncPushTokenWithServer() async {
    if (kIsWeb) return;
    await LocalNotifService.instance.init();
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _syncTokenToServer();
  }

  Future<void> _syncTokenToServer() async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null && token.isNotEmpty) {
        await CloudFunctionsService().updateFcmToken(fcmToken: token);
      }
    } catch (e) {
      debugPrint('FCM: failed to sync token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final String requestId = message.data['requestId']?.toString() ?? '';

    final String title =
        message.data['title']?.toString() ??
        message.notification?.title ??
        'Blood Request';

    final String body =
        message.data['body']?.toString() ??
        message.notification?.body ??
        'New blood request available';

    LocalNotifService.instance.show(
      title: title,
      body: body,
      payload: requestId,
    );
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await CloudFunctionsService().updateFcmToken(fcmToken: newToken);
    } catch (e) {
      debugPrint('FCM: token refresh upload failed: $e');
    }
  }

  /// Handles notification taps and navigates based on authentication state
  void _handleNotificationClick(Map<String, dynamic> data) async {
    final BuildContext? context = navigatorKey.currentContext;

    if (context == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationClick(data);
      });
      return;
    }

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

    if (!isAuthenticated || user == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
      return;
    }

    try {
      final authService = AuthService();
      final userData = await authService.getUserData(user.uid);

      if (userData == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
        return;
      }

      if (userData.role == models.UserRole.donor) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
          (route) => false,
        );
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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }
}
