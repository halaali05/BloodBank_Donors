import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../screens/welcome_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/donor_dashboard_screen.dart';
import '../screens/blood_bank_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as models;

class LocalNotifService {
  LocalNotifService._();
  static final LocalNotifService instance = LocalNotifService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;

    if (kIsWeb) {
      _inited = true;
      return;
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      // Handle notification click - only set if we have navigator context
      // In background handler, this might be null, which is okay
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            // Only handle click if app is running
            try {
              _handleNotificationClick(response.payload!);
            } catch (e) {
              // Could not handle notification click
            }
          }
        },
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // ✅ Android 13+ permission prompt (may fail in background, that's okay)
      try {
        await androidPlugin?.requestNotificationsPermission();
      } catch (e) {
        // Could not request permission (may be in background)
      }

      // ✅ Create channel - This is CRITICAL for notifications to appear
      // The channel must exist before any notifications can be displayed
      // This works even when app is closed
      await androidPlugin?.createNotificationChannel(_channel);

      _inited = true;
    } catch (e) {
      // Error initializing LocalNotifService
      // Don't set _inited = true on error, so we can retry
      rethrow;
    }
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    if (kIsWeb) return;

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          showWhen: true,
          autoCancel: true,
          ongoing: false,
          styleInformation: const BigTextStyleInformation(''),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Handle notification click and navigate based on authentication state
  /// - If authenticated: Navigate to appropriate dashboard (donor or blood bank)
  /// - If not authenticated: Navigate to welcome screen
  void _handleNotificationClick(String requestId) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      // Navigator context not available yet - retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationClick(requestId);
      });
      return;
    }

    // Verify user is actually authenticated by checking if we can get a valid ID token
    // This is more reliable than just checking currentUser or reloading
    bool isAuthenticated = false;
    User? user;

    try {
      // First check immediately
      user = FirebaseAuth.instance.currentUser;

      // If user exists, verify we can get a valid ID token
      if (user != null) {
        try {
          // Try to get ID token - this will fail if user is not authenticated
          await user.getIdToken();
          isAuthenticated = true;
        } catch (e) {
          // Can't get token - user is not authenticated
          isAuthenticated = false;
          user = null;
        }
      }

      // If no user found, wait briefly for auth state (with timeout)
      if (!isAuthenticated && user == null) {
        try {
          // Wait for auth state changes with timeout
          user = await FirebaseAuth.instance
              .authStateChanges()
              .timeout(const Duration(seconds: 1))
              .first;

          // If we got a user from the stream, verify we can get a token
          if (user != null) {
            try {
              await user.getIdToken();
              isAuthenticated = true;
            } catch (e) {
              isAuthenticated = false;
              user = null;
            }
          }
        } catch (e) {
          isAuthenticated = false;
          user = null;
        }
      }
    } catch (e) {
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
    } catch (e) {
      // Failed to get user role - navigate to welcome screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }
}
