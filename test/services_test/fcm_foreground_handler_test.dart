import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  // نلتقط ما يُرسل للإشعار بدل تشغيل LocalNotifService
  late Map<String, dynamic> captured;

  setUp(() {
    mockAuth = MockAuth();
    mockUser = MockFirebaseUser();
    mockAuthService = MockAuthService();
    mockCloud = MockCloud();
    message = MockRemoteMessage();

    // inject deps
    FcmForegroundHandler.instance.authFactory = () => mockAuth;
    FcmForegroundHandler.instance.authServiceFactory = () => mockAuthService;
    FcmForegroundHandler.instance.cloudFactory = () => mockCloud;

    // stub showNotification لمنع plugin
    captured = {};
    FcmForegroundHandler.instance.showNotification = ({
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

  // ================= BASIC =================

  group('basic', () {
    test('does not crash on empty message', () async {
      when(() => message.data).thenReturn({});
      when(() => message.notification).thenReturn(null);

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      // title/body default
      expect(captured['title'], 'Blood Request');
      expect(captured['body'], 'New blood request available');
    });

    test('uses notification fallback for title/body', () async {
      final notif = MockNotification();
      when(() => notif.title).thenReturn('T');
      when(() => notif.body).thenReturn('B');

      when(() => message.notification).thenReturn(notif);
      when(() => message.data).thenReturn({});

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(captured['title'], 'T');
      expect(captured['body'], 'B');
    });
  });

  // ================= FILTER =================

  group('filter logic', () {
 
test('blocks notification if NOT compatible', () async {
  final data = <String, dynamic>{
    'type': 'request',
    'bloodType': 'B+',
    'requestId': '123',
  };

  when(() => message.data).thenReturn(data);

  when(() => mockAuth.currentUser).thenReturn(mockUser);

  // 🔥 هذا كان ناقص
  when(() => mockUser.uid).thenReturn('123');

  when(() => mockAuthService.getUserData(any()))
      .thenAnswer((_) async => user('A+'));

  await FcmForegroundHandler.instance.handleForegroundMessage(message);

  expect(captured, isEmpty);
});

    test('allows notification if compatible', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'bloodType': 'O+',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockAuthService.getUserData(any()))
          .thenAnswer((_) async => user('O+'));

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('skips filter if donor blood type empty', () async {
      when(() => message.data).thenReturn({'type': 'request'});

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockAuthService.getUserData(any()))
          .thenAnswer((_) async => user('')); // فارغ

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('works when no logged in user', () async {
      when(() => message.data).thenReturn({'type': 'request'});
      when(() => mockAuth.currentUser).thenReturn(null);

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });
  });

  // ================= CLOUD FETCH =================

  group('cloud fallback', () {
    test('fetches blood type from cloud if missing', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockAuthService.getUserData(any()))
          .thenAnswer((_) async => user('O+'));

      when(() => mockCloud.getRequests(limit: any(named: 'limit')))
          .thenAnswer((_) async => {
                'requests': [
                  {'id': '123', 'bloodType': 'O+'}
                ]
              });

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });

    test('continues if cloud fetch throws', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '123',
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockAuthService.getUserData(any()))
          .thenAnswer((_) async => user('O+'));

      when(() => mockCloud.getRequests(limit: any(named: 'limit')))
          .thenThrow(Exception());

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(captured['title'], isNotNull);
    });
  });

  // ================= PAYLOAD + FLAGS =================

  group('payload & flags', () {
    test('builds payload correctly', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'requestId': '123',
        'senderId': 's',
        'recipientId': 'r',
      });

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      final p = captured['payload'] as String;
      final decoded = jsonDecode(p);

      expect(decoded['requestId'], '123');
      expect(decoded['senderId'], 's');
      expect(decoded['recipientId'], 'r');
    });

    test('parses isUrgent correctly for request', () async {
      when(() => message.data).thenReturn({
        'type': 'request',
        'isUrgent': 'true',
      });

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(captured['isUrgent'], true);
    });

    test('non-request never urgent', () async {
      when(() => message.data).thenReturn({
        'type': 'chat',
        'isUrgent': 'true',
      });

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(captured['isUrgent'], false);
    });
  
  test('builds payload correctly', () async {
  when(() => message.data).thenReturn({
    'type': 'request',
    'requestId': '123',
    'senderId': 's',
    'recipientId': 'r',
  });

  await FcmForegroundHandler.instance.handleForegroundMessage(message);

  expect(captured['payload'], contains('123'));
});
  });

  // ================= WEB BRANCH =================

  group('web branch', () {
    test('does not crash on web path', () async {
      // لا نقدر نغيّر kIsWeb بسهولة، لكن نغطي عدم الانهيار
      when(() => message.data).thenReturn({'type': 'chat'});

      await FcmForegroundHandler.instance.handleForegroundMessage(message);

      expect(true, isTrue);
    });
  });

  // ================= COMPATIBLE BLOOD TYPES =================

group('compatibleBloodTypes', () {
  test('O- gives to all', () {
    final result = FcmForegroundHandler.compatibleBloodTypes('O-');
    expect(result, containsAll(['A+', 'B+', 'AB+']));
  });

  test('A+ gives only to A+ and AB+', () {
    final result = FcmForegroundHandler.compatibleBloodTypes('A+');
    expect(result, ['A+', 'AB+']);
  });

  test('B+ gives only to B+ and AB+', () {
    final result = FcmForegroundHandler.compatibleBloodTypes('B+');
    expect(result, ['B+', 'AB+']);
  });

  test('AB+ gives only to AB+', () {
    final result = FcmForegroundHandler.compatibleBloodTypes('AB+');
    expect(result, ['AB+']);
  });

  test('unknown returns null', () {
    final result = FcmForegroundHandler.compatibleBloodTypes('XYZ');
    expect(result, null);
  });
});

test('non-request skips filtering', () async {
  when(() => message.data).thenReturn({'type': 'chat'});

  await FcmForegroundHandler.instance.handleForegroundMessage(message);

  expect(captured['title'], isNotNull);
});

test('no user skips filtering', () async {
  when(() => message.data).thenReturn({'type': 'request'});
  when(() => mockAuth.currentUser).thenReturn(null);

  await FcmForegroundHandler.instance.handleForegroundMessage(message);

  expect(captured['title'], isNotNull);
});
}