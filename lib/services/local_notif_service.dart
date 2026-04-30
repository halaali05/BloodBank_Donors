import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_navigation_service.dart';

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
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              NotificationNavigationService.instance.openFromPayloadJson(
                payload,
              );
            } catch (_) {}
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
}
