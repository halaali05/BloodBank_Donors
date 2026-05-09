import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:bloodbank_donors/services/fcm_foreground_handler.dart';
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/models/user_model.dart' as model;

// ================= MOCKS =================

class MockFirebaseUser extends Mock implements firebase.User {}

class MockAuth extends Mock implements firebase.FirebaseAuth {}

class MockAuthService extends Mock implements AuthService {}

class MockCloud extends Mock implements CloudFunctionsService {}

class MockRemoteMessage extends Mock implements RemoteMessage {}

class MockNotification extends Mock implements RemoteNotification {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuth mockAuth;
  late MockFirebaseUser mockUser;
  late MockAuthService mockAuthService;
  late MockCloud mockCloud;
  late MockRemoteMessage message;

  late Map<String, dynamic> captured;

  setUp(() {
    mockAuth = MockAuth();
    mockUser = MockFirebaseUser();
    mockAuthService = MockAuthService();
    mockCloud = MockCloud();
    message = MockRemoteMessage();

    FcmForegroundHandler.instance.authFactory = () => mockAuth;
    FcmForegroundHandler.instance.authServiceFactory =
        () => mockAuthService;
    FcmForegroundHandler.instance.cloudFactory = () => mockCloud;

    captured = {};

    FcmForegroundHandler.instance.showNotification =
        ({
          required String title,
          required String body,
          String? payload,
          bool isUrgent = false,
        }) async {
          captured = {
            'title': title,
            'body': body,
            'payload': payload,
            'isUrgent': isUrgent,
          };
        };
  });

  // ================= HELPERS =================

  model.User user(String bloodType) {
    return model.User(
      uid: '1',
      email: 't@test.com',
      role: model.UserRole.donor,
      bloodType: bloodType,
    );
  }

  // ================= COMPATIBLE BLOOD TYPES =================

  group('compatibleBloodTypes', () {
    test('A+ gives only to A+ and AB+', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('A+'),
        ['A+', 'AB+'],
      );
    });

    test('B+ gives only to B+ and AB+', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('B+'),
        ['B+', 'AB+'],
      );
    });

    test('AB+ gives only to AB+', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('AB+'),
        ['AB+'],
      );
    });

    test('AB- gives only to AB- and AB+', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('AB-'),
        ['AB-', 'AB+'],
      );
    });

    test('A- gives only to A-, A+, AB- and AB+', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('A-'),
        ['A-', 'A+', 'AB-', 'AB+'],
      );
    });

    test('B- gives only to B-, B+, AB- and AB+', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('B-'),
        ['B-', 'B+', 'AB-', 'AB+'],
      );
    });

    test('O- gives to all', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('O-'),
        containsAll([
          'A+',
          'B+',
          'AB+',
          'A-',
          'B-',
          'AB-',
          'O+',
          'O-',
        ]),
      );
    });

    test('O+ gives to A+, B+, AB+ and O+', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('O+'),
        containsAll(['A+', 'B+', 'AB+', 'O+']),
      );
    });

    test('unknown returns null', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes('XYZ'),
        null,
      );
    });

    test('returns null for empty string', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes(''),
        null,
      );
    });

    test('returns null for null input', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes(null),
        null,
      );
    });

    test('trims spaces before switch matching', () {
      expect(
        FcmForegroundHandler.compatibleBloodTypes(' O+ '),
        ['O+', 'A+', 'B+', 'AB+'],
      );
    });
  });

  // ================= BASIC NOTIFICATION HANDLING =================

  group('basic notification handling', () {
    test('does not crash on empty message', () async {
      when(() => message.data).thenReturn({});
      when(() => message.notification).thenReturn(null);

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], 'Blood Request');
      expect(
        captured['body'],
        'New blood request available',
      );
    });

    test('uses notification fallback for title/body', () async {
      final notif = MockNotification();

      when(() => notif.title).thenReturn('T');
      when(() => notif.body).thenReturn('B');

      when(() => message.notification).thenReturn(notif);
      when(() => message.data).thenReturn({});

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], 'T');
      expect(captured['body'], 'B');
    });
  });

  // ================= FOREGROUND FILTERING =================

  group('foreground filtering', () {
    test('blocks notification if NOT compatible', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'bloodType': 'B+',
        'requestId': '123',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('123');

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('A+'));

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured, isEmpty);
    });

    test('allows notification if compatible', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'bloodType': 'O+',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('O+'));

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('skips filter if donor blood type empty', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user(''));

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('works when no logged in user', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
      });

      when(() => mockAuth.currentUser).thenReturn(null);

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('allows notification when compatibleBloodTypes returns null',
        () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'bloodType': 'O+',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('UNKNOWN'));

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('allows notification when notifBloodType remains empty',
        () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('O+'));

      when(
        () => mockCloud.getRequests(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => {
            'requests': [
              {'id': '123'},
            ],
          });

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('trims donor blood type before compatibility check',
        () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'bloodType': 'A+',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user(' A+ '));

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('trims notification blood type', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'bloodType': ' O+ ',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('O+'));

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('blocks notification when fetched cloud blood type is incompatible',
        () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('A+'));

      when(
        () => mockCloud.getRequests(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => {
            'requests': [
              {
                'id': '123',
                'bloodType': 'B+',
              },
            ],
          });

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured, isEmpty);
    });
  });

  // ================= CLOUD FALLBACK =================

  group('cloud fallback', () {
    test('fetches blood type from cloud if missing', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('O+'));

      when(
        () => mockCloud.getRequests(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => {
            'requests': [
              {
                'id': '123',
                'bloodType': 'O+',
              },
            ],
          });

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('continues if cloud fetch throws', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('O+'));

      when(
        () => mockCloud.getRequests(
          limit: any(named: 'limit'),
        ),
      ).thenThrow(Exception());

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('continues when requestId not found in cloud results',
        () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '999',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('O+'));

      when(
        () => mockCloud.getRequests(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => {
            'requests': [
              {
                'id': '123',
                'bloodType': 'A+',
              },
            ],
          });

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('handles empty cloud requests list', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(
        () => mockAuthService.getUserData(any()),
      ).thenAnswer((_) async => user('O+'));

      when(
        () => mockCloud.getRequests(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => {
            'requests': [],
          });

      await FcmForegroundHandler.instance
          .handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });
  });

// ================= FILTER VERIFICATION =================

group('filter verification', () {

  test('does not call cloud when notification blood type already exists',
      () async {
    when(() => message.data).thenReturn({
      'type': 'request',
      'bloodType': 'O+',
      'requestId': '123',
    });

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(
      () => mockAuthService.getUserData(any()),
    ).thenAnswer((_) async => user('O+'));

    await FcmForegroundHandler.instance
        .handleForegroundMessage(message);

    verifyNever(
      () => mockCloud.getRequests(
        limit: any(named: 'limit'),
      ),
    );
  });

  test('calls authService with current user uid', () async {
    when(() => message.data).thenReturn({
      'type': 'request',
    });

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('USER_1');

    when(
      () => mockAuthService.getUserData(any()),
    ).thenAnswer((_) async => user('O+'));

    await FcmForegroundHandler.instance
        .handleForegroundMessage(message);

    verify(
      () => mockAuthService.getUserData('USER_1'),
    ).called(1);
  });

  test('calls cloud with limit 100', () async {
    when(() => message.data).thenReturn({
      'type': 'request',
      'requestId': '123',
    });

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(
      () => mockAuthService.getUserData(any()),
    ).thenAnswer((_) async => user('O+'));

    when(
      () => mockCloud.getRequests(
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => {
          'requests': [],
        });

    await FcmForegroundHandler.instance
        .handleForegroundMessage(message);

    verify(
      () => mockCloud.getRequests(limit: 100),
    ).called(1);
  });
});

// ================= REQUEST TYPE DEFAULTING =================

group('request type defaulting', () {

test('missing type defaults to request behavior', () async {
  when(() => message.data).thenReturn({
    'bloodType': 'B+',
  });

  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockUser.uid).thenReturn('u1');

  when(
    () => mockAuthService.getUserData(any()),
  ).thenAnswer((_) async => user('A+'));

  await FcmForegroundHandler.instance
      .handleForegroundMessage(message);

  expect(captured, isEmpty);
});
});

// ================= NOTIFICATION PRIORITY =================

group('notification priority', () {

  test('data title overrides notification title only', () async {
    final notif = MockNotification();

    when(() => notif.title).thenReturn('notif title');
    when(() => notif.body).thenReturn('notif body');

    when(() => message.notification).thenReturn(notif);

    when(() => message.data).thenReturn({
      'title': 'data title',
    });

    await FcmForegroundHandler.instance
        .handleForegroundMessage(message);

    expect(captured['title'], 'data title');
    expect(captured['body'], 'notif body');
  });

  test('data body overrides notification body only', () async {
    final notif = MockNotification();

    when(() => notif.title).thenReturn('notif title');
    when(() => notif.body).thenReturn('notif body');

    when(() => message.notification).thenReturn(notif);

    when(() => message.data).thenReturn({
      'body': 'data body',
    });

    await FcmForegroundHandler.instance
        .handleForegroundMessage(message);

    expect(captured['title'], 'notif title');
    expect(captured['body'], 'data body');
  });
});

// ================= REQUEST LOOKUP =================

group('request lookup', () {

  test('uses first matching requestId only', () async {
    when(() => message.data).thenReturn({
      'type': 'request',
      'requestId': '123',
    });

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(
      () => mockAuthService.getUserData(any()),
    ).thenAnswer((_) async => user('O+'));

    when(
      () => mockCloud.getRequests(
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => {
          'requests': [
            {
              'id': '123',
              'bloodType': 'O+',
            },
            {
              'id': '123',
              'bloodType': 'B+',
            },
          ],
        });

    await FcmForegroundHandler.instance
        .handleForegroundMessage(message);

    expect(captured['title'], isNotNull);
  });
});

// ================= NOTIFICATION EXECUTION =================

group('notification execution', () {

  test('showNotification called with urgent false by default',
      () async {
    when(() => message.data).thenReturn({
      'type': 'request',
    });

    await FcmForegroundHandler.instance
        .handleForegroundMessage(message);

    expect(captured['isUrgent'], false);
  });

 
});

}