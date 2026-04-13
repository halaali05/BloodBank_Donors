import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../screens/welcome_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/donor_dashboard_screen.dart';
import '../screens/blood_bank_dashboard_screen.dart';
import '../screens/chat_screen.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as models;

class LocalNotifService {
  LocalNotifService._();
  static final LocalNotifService instance = LocalNotifService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _normalChannelId = 'normal_request_channel';
  // Keep a versioned ID because Android channel vibration settings are immutable
  // once created on device. Bumping ID forces fresh channel creation.
  static const String _emergencyChannelId = 'emergency_request_channel_v4';
  static final Int64List _emergencyVibrationPattern = Int64List.fromList([
    0,
    500,
    250,
    500,
  ]);

  static final AndroidNotificationChannel _normalChannel =
      AndroidNotificationChannel(
        _normalChannelId,
        'Normal Request Notifications',
        description: 'Used for normal blood request notifications.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('normal_request'),
        enableVibration: false,
        showBadge: true,
      );

  static final AndroidNotificationChannel _emergencyChannel =
      AndroidNotificationChannel(
        _emergencyChannelId,
        'Emergency Request Notifications',
        description:
            'Used for emergency blood request notifications with vibration.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('emergency_request'),
        enableVibration: true,
        vibrationPattern: _emergencyVibrationPattern,
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
        settings: initSettings,
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
      await androidPlugin?.createNotificationChannel(_normalChannel);
      await androidPlugin?.createNotificationChannel(_emergencyChannel);

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
    bool isUrgent = false,
  }) async {
    await init();

    if (kIsWeb) return;

    final String channelId = isUrgent ? _emergencyChannelId : _normalChannelId;
    final String channelName = isUrgent
        ? _emergencyChannel.name
        : _normalChannel.name;
    final String? channelDescription = isUrgent
        ? _emergencyChannel.description
        : _normalChannel.description;
    final RawResourceAndroidNotificationSound sound = isUrgent
        ? const RawResourceAndroidNotificationSound('emergency_request')
        : const RawResourceAndroidNotificationSound('normal_request');

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          // Urgent: max importance + vibration. Normal: unchanged (high, no vibration).
          importance: isUrgent ? Importance.max : Importance.high,
          priority: isUrgent ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          sound: sound,
          enableVibration: isUrgent,
          vibrationPattern: isUrgent ? _emergencyVibrationPattern : null,
          showWhen: true,
          autoCancel: true,
          ongoing: false,
          ticker: title,
          styleInformation: BigTextStyleInformation(body),
        ),
        // iOS has no per-notification vibration pattern like Android; urgency is
        // expressed via time-sensitive interruption + custom sound (vibration follows
        // system ring/silent and notification settings).
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: isUrgent ? 'emergency_request.mp3' : 'normal_request.mp3',
          interruptionLevel: isUrgent
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      payload: payload,
    );
  }

  /// Handle notification click and navigate based on authentication state
  /// - If authenticated: Navigate to appropriate dashboard (donor or blood bank)
  /// - If not authenticated: Navigate to welcome screen
  void _handleNotificationClick(String payload) async {
    String requestId = '';
    String type = 'request';
    String senderId = '';
    String recipientId = '';
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        requestId = decoded['requestId']?.toString() ?? '';
        type = decoded['type']?.toString() ?? 'request';
        senderId = decoded['senderId']?.toString() ?? '';
        recipientId = decoded['recipientId']?.toString() ?? '';
      } else {
        requestId = payload;
      }
    } catch (_) {
      requestId = payload;
    }

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

      // Chat notifications open chat directly; request notifications open list.
      if (type == 'chat' && requestId.isNotEmpty) {
        if (userData.role == models.UserRole.donor) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
            (route) => false,
          );
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(requestId: requestId, initialMessage: ''),
                ),
              );
            }
          });
          return;
        }
        if (userData.role == models.UserRole.hospital) {
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
                  builder: (_) => ChatScreen(
                    requestId: requestId,
                    initialMessage: '',
                    recipientId: senderId.isNotEmpty
                        ? senderId
                        : (recipientId.isNotEmpty ? recipientId : null),
                  ),
                ),
              );
            }
          });
          return;
        }
      }

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
