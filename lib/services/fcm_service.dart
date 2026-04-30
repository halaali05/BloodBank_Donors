import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'fcm_cloud_sync_service.dart';
import 'fcm_foreground_handler.dart';
import 'local_notif_service.dart';
import 'notification_navigation_service.dart';

/// Firebase Cloud Messaging façade: stream wiring, token refresh, and taps.
///
/// - **Token → backend:** [FcmCloudSyncService]
/// - **Foreground UI (local + web):** [FcmForegroundHandler]
/// - **Tap routing:** [NotificationNavigationService]
class FCMService {
  static final FCMService instance = FCMService._();
  FCMService._();

  bool _listenersRegistered = false;
  bool _authStateListenerRegistered = false;
  bool _initialLaunchMessageHandled = false;

  final FcmCloudSyncService _cloudSync = FcmCloudSyncService.instance;

  /// Ensures startup wiring runs once; repeat callers await the same work and
  /// optionally refresh the server token ([syncTokenToBackend]).
  Future<void>? _bootstrapFuture;

  /// Initializes FCM listeners, local channels (non-web), permission, and token sync.
  Future<void> initFCM() async {
    final alreadyScheduled = _bootstrapFuture != null;
    _bootstrapFuture ??= _bootstrapFcmOnce();
    await _bootstrapFuture;
    if (alreadyScheduled) {
      await _cloudSync.syncTokenToBackend();
    }
  }

  Future<void> _bootstrapFcmOnce() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);

    if (!kIsWeb) {
      await LocalNotifService.instance.init();
    }

    if (!_listenersRegistered) {
      _listenersRegistered = true;
      FirebaseMessaging.onMessage.listen(
        (RemoteMessage m) =>
            FcmForegroundHandler.instance.handleForegroundMessage(m),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage m) =>
            NotificationNavigationService.instance.openFromData(m.data),
      );
      messaging.onTokenRefresh.listen(
        (String t) => _cloudSync.uploadRefreshedToken(t),
      );
    }

    if (!_authStateListenerRegistered) {
      _authStateListenerRegistered = true;
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          unawaited(_cloudSync.syncTokenToBackend());
        }
      });
    }

    NotificationSettings settings;
    var permissionGranted = false;

    try {
      settings = await messaging.getNotificationSettings();
      permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      permissionGranted = false;
    }

    if (!permissionGranted) {
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (!permissionGranted) {
      debugPrint(
        'FCM: notification permission not granted; '
        'push may be limited until the user allows notifications.',
      );
    }

    await _cloudSync.syncTokenToBackend();

    if (!_initialLaunchMessageHandled) {
      _initialLaunchMessageHandled = true;
      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 800), () {
            NotificationNavigationService.instance
                .openFromData(initialMessage.data);
          });
        });
      }
    }
  }

  Future<bool> syncPushTokenWithServer() async {
    if (!kIsWeb) {
      await LocalNotifService.instance.init();
    }
    return _cloudSync.syncPushTokenWithServer();
  }

  Future<bool> ensureTokenSynced({
    int attempts = 4,
    Duration delay = const Duration(seconds: 2),
  }) =>
      _cloudSync.ensureTokenSynced(attempts: attempts, delay: delay);

  String getLastSyncError() => _cloudSync.getLastSyncError();

  Future<Map<String, String>> getTokenDiagnostics() =>
      _cloudSync.getTokenDiagnostics();

  void handleNotificationPayload(Map<String, dynamic> data) {
    NotificationNavigationService.instance.openFromData(data);
  }
}
