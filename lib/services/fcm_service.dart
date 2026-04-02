import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../main.dart';
import '../screens/welcome_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/donor_dashboard_screen.dart';
import '../screens/blood_bank_dashboard_screen.dart';
import '../screens/chat_screen.dart';
import '../services/auth_service.dart';
import '../services/cloud_functions_service.dart';
import '../models/user_model.dart' as models;
import 'local_notif_service.dart';
import 'web_foreground_notification.dart';

class FCMService {
  static final FCMService instance = FCMService._();
  FCMService._();
  static const String _webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue:
        'BP6NQKrqARhI78tQ6LGeWRaCJYyhUTowjqux69xKKn7udmxifYwtNrKNFth53BWPhdANUAwbDwz77HbHDF0yPmQ',
  );

  bool _listenersRegistered = false;
  bool _initialLaunchMessageHandled = false;

  String _lastSyncError = '';

  /// Initializes Firebase Cloud Messaging (FCM) and sets up:
  /// - Local notification channel (Android)
  /// - Message / token listeners (registered once per process)
  /// - Permission request
  /// - Token saved to backend when user is signed in
  /// - Foreground: local notification with sound
  /// - Background: OS shows FCM notification (server sends notification + channelId)
  Future<void> initFCM() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);

    if (!kIsWeb) {
      await LocalNotifService.instance.init();
    }

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
  Future<bool> syncPushTokenWithServer() async {
    if (!kIsWeb) {
      await LocalNotifService.instance.init();
    }
    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    NotificationSettings settings;
    try {
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      _lastSyncError = 'Permission request failed: $e';
      return false;
    }
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) {
      _lastSyncError = 'Notification permission is denied.';
      return false;
    }
    return _syncTokenToServer();
  }

  Future<bool> _syncTokenToServer() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _lastSyncError = 'No authenticated user.';
        return false;
      }

      final messaging = FirebaseMessaging.instance;
      String? token = await _getToken(messaging);
      if (token == null || token.isEmpty) {
        if (!kIsWeb) {
          // Force refresh + retry on mobile.
          await messaging.deleteToken();
          await Future.delayed(const Duration(milliseconds: 500));
        }
        token = await _getToken(messaging);
      }
      if (token == null || token.isEmpty) {
        // Fallback: wait for token-refresh event once.
        try {
          token = await messaging.onTokenRefresh
              .first
              .timeout(const Duration(seconds: 8));
        } catch (_) {}
      }

      if (token != null && token.isNotEmpty) {
        await CloudFunctionsService().updateFcmToken(fcmToken: token);
        final profile = await CloudFunctionsService().getUserData(uid: user.uid);
        final savedToken = (profile['fcmToken'] ?? '').toString().trim();
        if (savedToken.isEmpty) {
          _lastSyncError =
              'Token generated locally but not saved on server user profile.';
          return false;
        }
        debugPrint('FCM: token synced for uid=${user.uid}');
        _lastSyncError = '';
        return true;
      } else {
        debugPrint('FCM: token unavailable for uid=${user.uid}');
        _lastSyncError = kIsWeb
            ? 'FCM token not generated on web. Check VAPID key/browser permission, then retry.'
            : 'FCM token not generated. Check Google Play services/network, then retry.';
        return false;
      }
    } catch (e) {
      debugPrint('FCM: failed to sync token: $e');
      _lastSyncError = e.toString();
      return false;
    }
  }

  /// Tries multiple times to ensure token is uploaded for current user.
  Future<bool> ensureTokenSynced({
    int attempts = 4,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < attempts; i++) {
      final ok = await syncPushTokenWithServer();
      if (ok) return true;
      await Future.delayed(delay);
    }
    return false;
  }

  String getLastSyncError() => _lastSyncError;

  Future<String?> _getToken(FirebaseMessaging messaging) {
    if (kIsWeb) {
      if (_webVapidKey.isEmpty) {
        _lastSyncError =
            'Missing web VAPID key. Run with --dart-define=FIREBASE_WEB_VAPID_KEY=YOUR_KEY';
        return Future.value(null);
      }
      return messaging.getToken(vapidKey: _webVapidKey);
    }
    return messaging.getToken();
  }

  Future<Map<String, String>> getTokenDiagnostics() async {
    final user = FirebaseAuth.instance.currentUser;
    String permission = 'unknown';
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      permission = settings.authorizationStatus.name;
    } catch (e) {
      permission = 'error: ${e.toString()}';
    }
    String tokenPreview = '';
    try {
      final t = await _getToken(FirebaseMessaging.instance);
      if (t != null && t.isNotEmpty) {
        tokenPreview = t.length > 24 ? '${t.substring(0, 24)}...' : t;
        // If a token exists now, clear stale previous sync errors in diagnostics.
        if (_lastSyncError.isNotEmpty) {
          _lastSyncError = '';
        }
      }
    } catch (_) {}

    String serverTokenPreview = '';
    try {
      if (user != null) {
        final profile = await CloudFunctionsService().getUserData(uid: user.uid);
        final t = (profile['fcmToken'] ?? '').toString().trim();
        if (t.isNotEmpty) {
          serverTokenPreview = t.length > 24 ? '${t.substring(0, 24)}...' : t;
        }
      }
    } catch (_) {}

    return {
      'uid': user?.uid ?? '(none)',
      'permission': permission,
      'tokenPreview': tokenPreview.isEmpty ? '(none)' : tokenPreview,
      'serverTokenPreview': serverTokenPreview.isEmpty
          ? '(none)'
          : serverTokenPreview,
      'lastError': _lastSyncError.isEmpty ? '(none)' : _lastSyncError,
    };
  }

  void _onForegroundMessage(RemoteMessage message) {
    final String requestId = message.data['requestId']?.toString() ?? '';
    final String type = message.data['type']?.toString() ?? 'request';
    final bool isUrgentRequest =
        message.data['isUrgent']?.toString().toLowerCase() == 'true';

    final String title =
        message.data['title']?.toString() ??
        message.notification?.title ??
        'Blood Request';

    final String body =
        message.data['body']?.toString() ??
        message.notification?.body ??
        'New blood request available';

    final payload = {
      'type': type,
      'requestId': requestId,
      'senderId': message.data['senderId']?.toString() ?? '',
      'recipientId': message.data['recipientId']?.toString() ?? '',
    };

    if (kIsWeb) {
      // With the tab focused, FCM is delivered here — browsers won't show a system
      // notification unless we use the Notification API.
      showWebForegroundNotification(
        title: title,
        body: body,
        data: Map<String, dynamic>.from(payload),
      );
      return;
    }

    LocalNotifService.instance.show(
      title: title,
      body: body,
      payload: jsonEncode(payload),
      isRequestNotification: type == 'request',
      isEmergencyRequest: type == 'request' && isUrgentRequest,
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

      final notificationType = data['type']?.toString() ?? 'request';
      final requestId = data['requestId']?.toString() ?? '';
      final recipientId = data['recipientId']?.toString() ?? '';
      final senderId = data['senderId']?.toString() ?? '';

      if (notificationType == 'chat' && requestId.isNotEmpty) {
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

  /// Used by web startup flow to route from payload encoded in URL query.
  void handleNotificationPayload(Map<String, dynamic> data) {
    _handleNotificationClick(data);
  }
}
