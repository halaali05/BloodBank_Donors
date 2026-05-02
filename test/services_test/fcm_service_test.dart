import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/services/fcm_service.dart';
import 'package:bloodbank_donors/services/fcm_cloud_sync_service.dart';

// ================= MOCKS =================

class MockMessaging extends Mock implements FirebaseMessaging {}

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockCloudSync extends Mock implements FcmCloudSyncService {}

class MockRemoteMessage extends Mock implements RemoteMessage {}

class FakeDuration extends Fake implements Duration {}
// ================= HELPERS =================

NotificationSettings fakeSettings() {
  return NotificationSettings(
    authorizationStatus: AuthorizationStatus.authorized,
    alert: AppleNotificationSetting.enabled,
    badge: AppleNotificationSetting.enabled,
    sound: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.disabled,
    carPlay: AppleNotificationSetting.disabled,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.always,
    timeSensitive: AppleNotificationSetting.disabled,
    criticalAlert: AppleNotificationSetting.disabled,
    providesAppNotificationSettings: AppleNotificationSetting.disabled, // 🔥 هذا الجديد

  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMessaging mockMessaging;
  late MockAuth mockAuth;
  late MockCloudSync mockCloud;

  setUp(() {
    mockMessaging = MockMessaging();
    mockAuth = MockAuth();
    mockCloud = MockCloudSync();

    // inject dependencies
    FCMService.instance.messagingFactory = () => mockMessaging;
    FCMService.instance.authFactory = () => mockAuth;
    FCMService.instance.setCloudSync(mockCloud);
    FCMService.instance.localNotifInit = () async {};

    FCMService.instance.resetForTest();

    // مهم جدًا
    when(() => mockMessaging.onTokenRefresh)
        .thenAnswer((_) => const Stream.empty());

    when(() => mockAuth.authStateChanges())
        .thenAnswer((_) => const Stream.empty());
  });

 setUpAll(() {
  //registerFallbackValue(FakeRemoteMessage());
  registerFallbackValue(FakeDuration()); 
});
  // =========================================================
  // INIT
  // =========================================================

  group('initFCM()', () {
    test('initializes and syncs token', () async {
      when(() => mockMessaging.setAutoInitEnabled(true))
          .thenAnswer((_) async {});

      when(() => mockMessaging.getNotificationSettings())
          .thenThrow(Exception());

      when(() => mockMessaging.requestPermission(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
            provisional: any(named: 'provisional'),
          )).thenAnswer((_) async => fakeSettings());

      when(() => mockMessaging.getInitialMessage())
          .thenAnswer((_) async => null);

      when(() => mockCloud.syncTokenToBackend())
          .thenAnswer((_) async => true);

      await FCMService.instance.initFCM();

      verify(() => mockCloud.syncTokenToBackend()).called(1);
    });

    test('bootstrap runs once and then resyncs', () async {
      when(() => mockMessaging.setAutoInitEnabled(true))
          .thenAnswer((_) async {});

      when(() => mockMessaging.getNotificationSettings())
          .thenThrow(Exception());

      when(() => mockMessaging.requestPermission(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
            provisional: any(named: 'provisional'),
          )).thenAnswer((_) async => fakeSettings());

      when(() => mockMessaging.getInitialMessage())
          .thenAnswer((_) async => null);

      when(() => mockCloud.syncTokenToBackend())
          .thenAnswer((_) async => true);

      await FCMService.instance.initFCM();
      await FCMService.instance.initFCM();

      verify(() => mockCloud.syncTokenToBackend())
          .called(greaterThan(1));
    });

    test('handles initial message safely', () async {
      final message = MockRemoteMessage();
      when(() => message.data).thenReturn({'id': '123'});

      when(() => mockMessaging.setAutoInitEnabled(true))
          .thenAnswer((_) async {});

      when(() => mockMessaging.getNotificationSettings())
          .thenThrow(Exception());

      when(() => mockMessaging.requestPermission(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
            provisional: any(named: 'provisional'),
          )).thenAnswer((_) async => fakeSettings());

      when(() => mockMessaging.getInitialMessage())
          .thenAnswer((_) async => message);

      when(() => mockCloud.syncTokenToBackend())
          .thenAnswer((_) async => true);

      await FCMService.instance.initFCM();

      // wait for delayed navigation
      await Future.delayed(const Duration(milliseconds: 900));
    });
  });

  // =========================================================
  // TOKEN
  // =========================================================

  group('token sync', () {
    test('syncPushTokenWithServer returns true', () async {
      when(() => mockCloud.syncPushTokenWithServer())
          .thenAnswer((_) async => true);

      final result =
          await FCMService.instance.syncPushTokenWithServer();

      expect(result, true);
    });

    test('ensureTokenSynced delegates', () async {
      when(() => mockCloud.ensureTokenSynced(
            attempts: any(named: 'attempts'),
            delay: any(named: 'delay'),
          )).thenAnswer((_) async => true);

      final result = await FCMService.instance.ensureTokenSynced();

      expect(result, true);
    });
  });

  // =========================================================
  // AUTH LISTENER
  // =========================================================

  group('auth listener', () {
    test('triggers sync when user logs in', () async {
      final controller = StreamController<User?>();

      when(() => mockAuth.authStateChanges())
          .thenAnswer((_) => controller.stream);

      when(() => mockMessaging.setAutoInitEnabled(true))
          .thenAnswer((_) async {});

      when(() => mockMessaging.getNotificationSettings())
          .thenThrow(Exception());

      when(() => mockMessaging.requestPermission(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
            provisional: any(named: 'provisional'),
          )).thenAnswer((_) async => fakeSettings());

      when(() => mockMessaging.getInitialMessage())
          .thenAnswer((_) async => null);

      when(() => mockCloud.syncTokenToBackend())
          .thenAnswer((_) async => true);

      await FCMService.instance.initFCM();

      controller.add(MockUser());

      await Future.delayed(Duration.zero);

      verify(() => mockCloud.syncTokenToBackend())
          .called(greaterThan(0));
    });
  });

  // =========================================================
  // PAYLOAD
  // =========================================================

  group('payload handling', () {
    test('does not crash', () {
      FCMService.instance.handleNotificationPayload({'id': '123'});
    });
  });
}