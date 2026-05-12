import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bloodbank_donors/services/fcm_cloud_sync_service.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/services/push_session_gate.dart';

// ================= MOCKS =================

class MockFirebaseAuth extends Mock implements firebase.FirebaseAuth {}

class MockFirebaseUser extends Mock implements firebase.User {}

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

class MockNotificationSettings extends Mock implements NotificationSettings {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockAuth;
  late MockFirebaseUser mockUser;
  late MockFirebaseMessaging mockMessaging;
  late MockCloudFunctionsService mockCloud;
  late MockNotificationSettings mockSettings;

  late FcmCloudSyncService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockFirebaseAuth();
    mockUser = MockFirebaseUser();
    mockMessaging = MockFirebaseMessaging();
    mockCloud = MockCloudFunctionsService();
    mockSettings = MockNotificationSettings();

    service = FcmCloudSyncService.instance;

    service.authFactory = () => mockAuth;
    service.messagingFactory = () => mockMessaging;
    service.cloudFactory = () => mockCloud;
  });

  // ================= getToken =================

  group('getToken', () {
    test('returns token successfully', () async {
      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'TOKEN');

      final result = await service.getToken(mockMessaging);

      expect(result, 'TOKEN');
    });

    test('returns null when token unavailable', () async {
      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => null);

      final result = await service.getToken(mockMessaging);

      expect(result, null);
    });
  });

  // ================= syncPushTokenWithServer =================

  group('syncPushTokenWithServer', () {
    test('returns false when permission denied', () async {
      when(() => mockSettings.authorizationStatus)
          .thenReturn(AuthorizationStatus.denied);

      when(() => mockMessaging.setAutoInitEnabled(any()))
          .thenAnswer((_) async {});

      when(() => mockMessaging.getNotificationSettings())
          .thenAnswer((_) async => mockSettings);

      when(
        () => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          badge: any(named: 'badge'),
          sound: any(named: 'sound'),
          provisional: any(named: 'provisional'),
        ),
      ).thenAnswer((_) async => mockSettings);

      final result =
          await service.syncPushTokenWithServer();

      expect(result, false);
      expect(
        service.getLastSyncError(),
        'Notification permission is denied.',
      );
    });

    test('returns false when requestPermission throws', () async {
      when(() => mockSettings.authorizationStatus)
          .thenReturn(AuthorizationStatus.denied);

      when(() => mockMessaging.setAutoInitEnabled(any()))
          .thenAnswer((_) async {});

      when(() => mockMessaging.getNotificationSettings())
          .thenAnswer((_) async => mockSettings);

      when(
        () => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          badge: any(named: 'badge'),
          sound: any(named: 'sound'),
          provisional: any(named: 'provisional'),
        ),
      ).thenThrow(Exception('permission failed'));

      final result =
          await service.syncPushTokenWithServer();

      expect(result, false);

      expect(
        service.getLastSyncError(),
        contains('Permission request failed'),
      );
    });
  });

  // ================= syncTokenToBackend =================

  group('syncTokenToBackend', () {
    test('returns false when no authenticated user', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final result = await service.syncTokenToBackend();

      expect(result, false);

      expect(
        service.getLastSyncError(),
        'No authenticated user.',
      );
      expect(await PushSessionGate.isActive(), false);
    });

    test('uploads token successfully', () async {
      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'TOKEN');

      when(
        () => mockCloud.updateFcmToken(
          fcmToken: any(named: 'fcmToken'),
        ),
      ).thenAnswer((_) async => {});

      when(
        () => mockCloud.getUserData(
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async => {
            'fcmToken': 'TOKEN',
          });

      final result = await service.syncTokenToBackend();

      expect(result, true);

      verify(
        () => mockCloud.updateFcmToken(
          fcmToken: 'TOKEN',
        ),
      ).called(1);

      expect(await PushSessionGate.isActive(), true);
    });

    test('returns false when token empty after retries', () async {
      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => '');

      when(() => mockMessaging.deleteToken())
          .thenAnswer((_) async {});

      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());

      final result = await service.syncTokenToBackend();

      expect(result, false);

      expect(
        service.getLastSyncError(),
        contains('FCM token not generated'),
      );
    });

    test('returns false when server token missing after upload', () async {
      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'TOKEN');

      when(
        () => mockCloud.updateFcmToken(
          fcmToken: any(named: 'fcmToken'),
        ),
      ).thenAnswer((_) async => {});

      when(
        () => mockCloud.getUserData(
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async => {
            'fcmToken': '',
          });

      final result = await service.syncTokenToBackend();

      expect(result, false);

      expect(
        service.getLastSyncError(),
        contains('not saved on server'),
      );
    });

    test('returns false when updateFcmToken throws', () async {
      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'TOKEN');

      when(
        () => mockCloud.updateFcmToken(
          fcmToken: any(named: 'fcmToken'),
        ),
      ).thenThrow(Exception('upload failed'));

      final result = await service.syncTokenToBackend();

      expect(result, false);

      expect(
        service.getLastSyncError(),
        contains('upload failed'),
      );
    });
  });

  // ================= uploadRefreshedToken =================

  group('uploadRefreshedToken', () {
    test('does nothing when user is null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      await service.uploadRefreshedToken('TOKEN');

      verifyNever(
        () => mockCloud.updateFcmToken(
          fcmToken: any(named: 'fcmToken'),
        ),
      );
    });

    test('uploads refreshed token successfully', () async {
      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(
        () => mockCloud.updateFcmToken(
          fcmToken: any(named: 'fcmToken'),
        ),
      ).thenAnswer((_) async => {});

      await service.uploadRefreshedToken('TOKEN');

      verify(
        () => mockCloud.updateFcmToken(
          fcmToken: 'TOKEN',
        ),
      ).called(1);

      expect(await PushSessionGate.isActive(), true);
    });

    test('handles upload exception safely', () async {
      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(
        () => mockCloud.updateFcmToken(
          fcmToken: any(named: 'fcmToken'),
        ),
      ).thenThrow(Exception());

      await service.uploadRefreshedToken('TOKEN');

      expect(true, isTrue);
    });
  });

  // ================= onSignedOut =================

  group('onSignedOut', () {
    test('sets push session inactive', () async {
      await PushSessionGate.setActive(true);
      await service.onSignedOut();
      expect(await PushSessionGate.isActive(), false);
    });
  });

  // ================= clearTokenForLogout =================

  group('clearTokenForLogout', () {
    test('does nothing when user is null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      await service.clearTokenForLogout();

      verifyNever(() => mockCloud.clearFcmToken());
      expect(await PushSessionGate.isActive(), false);
    });

    test('calls clearFcmToken and deleteToken when user present', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockCloud.clearFcmToken()).thenAnswer(
        (_) async => {'ok': true},
      );
      when(() => mockMessaging.deleteToken()).thenAnswer((_) async {});

      await service.clearTokenForLogout();

      verify(() => mockCloud.clearFcmToken()).called(1);
      verify(() => mockMessaging.deleteToken()).called(1);
      expect(await PushSessionGate.isActive(), false);
    });

    test('still deletes local token if server clear fails', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockCloud.clearFcmToken()).thenThrow(Exception('network'));
      when(() => mockMessaging.deleteToken()).thenAnswer((_) async {});

      await service.clearTokenForLogout();

      verify(() => mockCloud.clearFcmToken()).called(1);
      verify(() => mockMessaging.deleteToken()).called(1);
      expect(await PushSessionGate.isActive(), false);
    });
  });

  // ================= getTokenDiagnostics =================

  group('getTokenDiagnostics', () {
    test('returns diagnostics successfully', () async {
      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockSettings.authorizationStatus)
          .thenReturn(AuthorizationStatus.authorized);

      when(() => mockMessaging.getNotificationSettings())
          .thenAnswer((_) async => mockSettings);

      when(() => mockMessaging.getToken())
          .thenAnswer(
            (_) async =>
                '123456789012345678901234567890',
          );

      when(
        () => mockCloud.getUserData(
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async => {
            'fcmToken':
                '123456789012345678901234567890',
          });

      final result =
          await service.getTokenDiagnostics();

      expect(result['uid'], 'u1');

      expect(
        result['permission'],
        'authorized',
      );

      expect(
        result['tokenPreview'],
        contains('...'),
      );

      expect(
        result['serverTokenPreview'],
        contains('...'),
      );
    });

    test('handles notification settings exception', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      when(() => mockMessaging.getNotificationSettings())
          .thenThrow(Exception('settings failed'));

      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => null);

      final result =
          await service.getTokenDiagnostics();

      expect(
        result['permission'],
        contains('settings failed'),
      );
    });

    test('shows none when token unavailable', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      when(() => mockSettings.authorizationStatus)
          .thenReturn(AuthorizationStatus.authorized);

      when(() => mockMessaging.getNotificationSettings())
          .thenAnswer((_) async => mockSettings);

      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => null);

      final result =
          await service.getTokenDiagnostics();

      expect(result['tokenPreview'], '(none)');
    });
  });
}