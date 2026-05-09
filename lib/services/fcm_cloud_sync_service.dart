import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'cloud_functions_service.dart';

/// Uploads and verifies the FCM device token via **Cloud Functions** only.
/// Keeps network/backend concerns out of [FCMService] and [LocalNotifService].
class FcmCloudSyncService {
  FcmCloudSyncService._();
  static final FcmCloudSyncService instance = FcmCloudSyncService._();

  FirebaseMessaging Function() messagingFactory =  () => FirebaseMessaging.instance;

  FirebaseAuth Function() authFactory = () => FirebaseAuth.instance;

  CloudFunctionsService Function() cloudFactory = () => CloudFunctionsService();

  static const String _webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue:
        'BP6NQKrqARhI78tQ6LGeWRaCJYyhUTowjqux69xKKn7udmxifYwtNrKNFth53BWPhdANUAwbDwz77HbHDF0yPmQ',
  );

  String _lastSyncError = '';

  String getLastSyncError() => _lastSyncError;

  Future<String?> getToken(FirebaseMessaging messaging) async {
    if (kIsWeb) {
      if (_webVapidKey.isEmpty) {
        _lastSyncError =
            'Missing web VAPID key. Run with --dart-define=FIREBASE_WEB_VAPID_KEY=YOUR_KEY';
        return null;
      }
      return messaging.getToken(vapidKey: _webVapidKey);
    }
    return messaging.getToken();
  }

  /// Full permission + token fetch + [CloudFunctionsService.updateFcmToken].
  ///
  /// Uses [FirebaseMessaging.getNotificationSettings] first so repeat calls
  /// after [FCMService.initFCM] do not re-prompt and stay fast on hot paths.
  Future<bool> syncPushTokenWithServer() async {
    final messaging = messagingFactory();
    await messaging.setAutoInitEnabled(true);

    NotificationSettings settings;
    bool granted = false;

    try {
      settings = await messaging.getNotificationSettings();
      granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e, st) {
      debugPrint('FCM: getNotificationSettings failed: $e\n$st');
    }

    if (!granted) {
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
      granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (!granted) {
      _lastSyncError = 'Notification permission is denied.';
      return false;
    }
    return syncTokenToBackend();
  }

  /// Upload FCM token for the signed-in user (no permission re-prompt).
  Future<bool> syncTokenToBackend() async {
    try {
      final User? user = authFactory().currentUser;
      if (user == null) {
        _lastSyncError = 'No authenticated user.';
        return false;
      }

      final messaging = messagingFactory();
      String? token = await getToken(messaging);
      if (token == null || token.isEmpty) {
        if (!kIsWeb) {
          await messaging.deleteToken();
          await Future.delayed(const Duration(milliseconds: 500));
        }
        token = await getToken(messaging);
      }
      if (token == null || token.isEmpty) {
        try {
          token = await messaging.onTokenRefresh.first.timeout(
            const Duration(seconds: 8),
          );
        } catch (_) {}
      }

      if (token != null && token.isNotEmpty) {
        await cloudFactory().updateFcmToken(fcmToken: token);
        final profile = await cloudFactory().getUserData(
          uid: user.uid,
        );
        final savedToken = (profile['fcmToken'] ?? '').toString().trim();
        if (savedToken.isEmpty) {
          _lastSyncError =
              'Token generated locally but not saved on server user profile.';
          return false;
        }
        debugPrint('FCM cloud sync: token saved for uid=${user.uid}');
        _lastSyncError = '';
        return true;
      } else {
        debugPrint('FCM cloud sync: token unavailable for uid=${user.uid}');
        _lastSyncError = kIsWeb
            ? 'FCM token not generated on web. Check VAPID key/browser permission, then retry.'
            : 'FCM token not generated. Check Google Play services/network, then retry.';
        return false;
      }
    } catch (e) {
      debugPrint('FCM cloud sync failed: $e');
      _lastSyncError = e.toString();
      return false;
    }
  }

  Future<void> uploadRefreshedToken(String newToken) async {
    final User? currentUser = authFactory().currentUser;
    if (currentUser == null) return;
    try {
      await cloudFactory().updateFcmToken(fcmToken: newToken);
    } catch (e) {
      debugPrint('FCM cloud sync: token refresh upload failed: $e');
    }
  }

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

  Future<Map<String, String>> getTokenDiagnostics() async {
    final user = authFactory().currentUser;
    String permission = 'unknown';
    try {
      final settings = await messagingFactory()
          .getNotificationSettings();
      permission = settings.authorizationStatus.name;
    } catch (e) {
      permission = 'error: ${e.toString()}';
    }
    String tokenPreview = '';
    try {
      final t = await getToken(messagingFactory());
      if (t != null && t.isNotEmpty) {
        tokenPreview = t.length > 24 ? '${t.substring(0, 24)}...' : t;
        if (_lastSyncError.isNotEmpty) {
          _lastSyncError = '';
        }
      }
    } catch (_) {}

    String serverTokenPreview = '';
    try {
      if (user != null) {
        final profile = await cloudFactory().getUserData(
          uid: user.uid,
        );
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
}