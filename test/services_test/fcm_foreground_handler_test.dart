
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bloodbank_donors/services/fcm_foreground_handler.dart';
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/models/user_model.dart' as model;

// ================= MOCKS =================

class MockFirebaseUser extends Mock implements firebase.User {}

class MockAuth extends Mock implements firebase.FirebaseAuth {}

class MockAuthService extends Mock implements AuthService {}

class MockCloudFunctionsService extends Mock
    implements CloudFunctionsService {}

class MockRemoteMessage extends Mock implements RemoteMessage {}

class MockRemoteNotification extends Mock
    implements RemoteNotification {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuth mockAuth;
  late MockFirebaseUser mockUser;
  late MockAuthService mockAuthService;
  late MockCloudFunctionsService mockCloud;
  late MockRemoteMessage mockMessage;

  late Map<String, dynamic> shownNotification;

  setUp(() {
SharedPreferences.setMockInitialValues({
  'bloodbank_push_session_active': true,
});
    mockAuth = MockAuth();
    mockUser = MockFirebaseUser();
    mockAuthService = MockAuthService();
    mockCloud = MockCloudFunctionsService();
    mockMessage = MockRemoteMessage();

    shownNotification = {};

    FcmForegroundHandler.instance.authFactory =
        () => mockAuth;

    FcmForegroundHandler.instance.authServiceFactory =
        () => mockAuthService;

    FcmForegroundHandler.instance.cloudFactory =
        () => mockCloud;

    FcmForegroundHandler.instance.showNotification =
        ({
          required String title,
          required String body,
          String? payload,
          bool isUrgent = false,
        }) async {
          shownNotification = {
            'title': title,
            'body': body,
            'payload': payload,
            'isUrgent': isUrgent,
          };
        };
  });

  model.User buildUser(String bloodType) {
    return model.User(
      uid: 'uid_1',
      email: 'test@test.com',
      role: model.UserRole.donor,
      bloodType: bloodType,
    );
  }

  group('compatibleBloodTypes', () {
    test('returns correct compatibility for O-', () {
      final result =
          FcmForegroundHandler.compatibleBloodTypes('O-');

      expect(
        result,
        containsAll([
          'O-',
          'O+',
          'A-',
          'A+',
          'B-',
          'B+',
          'AB-',
          'AB+',
        ]),
      );
    });

    test('returns null for invalid blood type', () {
      final result =
          FcmForegroundHandler.compatibleBloodTypes('XYZ');

      expect(result, isNull);
    });

    test('trims spaces correctly', () {
      final result =
          FcmForegroundHandler.compatibleBloodTypes(' O+ ');

      expect(
        result,
        ['O+', 'A+', 'B+', 'AB+'],
      );
    });
  });

  group('foreground notifications', () {

    test('returns early if user signed out', () async {
      when(() => mockAuth.currentUser)
          .thenReturn(null);

      when(() => mockMessage.data)
          .thenReturn({
        'type': 'request',
      });

      await FcmForegroundHandler.instance
          .handleForegroundMessage(mockMessage);

      expect(shownNotification.isEmpty, true);
    });

    test('shows notification for compatible blood type',
        () async {

      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid)
          .thenReturn('u1');

      when(() => mockMessage.data)
          .thenReturn({
        'type': 'request',
        'bloodType': 'O+',
      });

      when(() => mockMessage.notification)
          .thenReturn(null);

      when(() => mockAuthService.getUserData(any()))
          .thenAnswer(
        (_) async => buildUser('O+'),
      );

      await FcmForegroundHandler.instance
          .handleForegroundMessage(mockMessage);

      expect(
        shownNotification.containsKey('title'),
        true,
      );
    });

    test('blocks incompatible blood type notification',
        () async {

      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid)
          .thenReturn('u1');

      when(() => mockMessage.data)
          .thenReturn({
        'type': 'request',
        'bloodType': 'B+',
      });

      when(() => mockMessage.notification)
          .thenReturn(null);

      when(() => mockAuthService.getUserData(any()))
          .thenAnswer(
        (_) async => buildUser('A+'),
      );

      await FcmForegroundHandler.instance
          .handleForegroundMessage(mockMessage);

      expect(shownNotification.isEmpty, true);
    });

    test('fetches request blood type from cloud',
        () async {

      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid)
          .thenReturn('u1');

      when(() => mockMessage.data)
          .thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockMessage.notification)
          .thenReturn(null);

      when(() => mockAuthService.getUserData(any()))
          .thenAnswer(
        (_) async => buildUser('O+'),
      );

      when(() => mockCloud.getRequests(limit: 100))
          .thenAnswer(
        (_) async => {
          'requests': [
            {
              'id': '123',
              'bloodType': 'O+',
            },
          ],
        },
      );

      await FcmForegroundHandler.instance
          .handleForegroundMessage(mockMessage);

      expect(
        shownNotification.containsKey('title'),
        true,
      );
    });

    test('continues when cloud fetch throws',
        () async {

      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid)
          .thenReturn('u1');

      when(() => mockMessage.data)
          .thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockMessage.notification)
          .thenReturn(null);

      when(() => mockAuthService.getUserData(any()))
          .thenAnswer(
        (_) async => buildUser('O+'),
      );

      when(() => mockCloud.getRequests(limit: 100))
          .thenThrow(Exception());

      await FcmForegroundHandler.instance
          .handleForegroundMessage(mockMessage);

      expect(
        shownNotification.containsKey('title'),
        true,
      );
    });

    test('uses notification fallback title/body',
        () async {

      final notif = MockRemoteNotification();

      when(() => notif.title)
          .thenReturn('TITLE');

      when(() => notif.body)
          .thenReturn('BODY');

      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid)
          .thenReturn('u1');

      when(() => mockMessage.notification)
          .thenReturn(notif);

      when(() => mockMessage.data)
          .thenReturn({});

      when(() => mockAuthService.getUserData(any()))
          .thenAnswer(
        (_) async => buildUser('O+'),
      );

      await FcmForegroundHandler.instance
          .handleForegroundMessage(mockMessage);

      expect(shownNotification['title'], 'TITLE');
      expect(shownNotification['body'], 'BODY');
    });

    test('uses default fallback values',
        () async {

      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid)
          .thenReturn('u1');

      when(() => mockMessage.notification)
          .thenReturn(null);

      when(() => mockMessage.data)
          .thenReturn({});

      when(() => mockAuthService.getUserData(any()))
          .thenAnswer(
        (_) async => buildUser(''),
      );

      await FcmForegroundHandler.instance
          .handleForegroundMessage(mockMessage);

      expect(
        shownNotification['title'],
        'Blood Request',
      );

      expect(
        shownNotification['body'],
        'New blood request available',
      );
    });

    test('passes urgent flag correctly',
        () async {

      when(() => mockAuth.currentUser)
          .thenReturn(mockUser);

      when(() => mockUser.uid)
          .thenReturn('u1');

      when(() => mockMessage.notification)
          .thenReturn(null);

      when(() => mockMessage.data)
          .thenReturn({
        'type': 'request',
        'isUrgent': 'true',
      });

      when(() => mockAuthService.getUserData(any()))
          .thenAnswer(
        (_) async => buildUser('O+'),
      );

      await FcmForegroundHandler.instance
          .handleForegroundMessage(mockMessage);

      expect(
        shownNotification['isUrgent'],
        true,
      );
    });
  });
}