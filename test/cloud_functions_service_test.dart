import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:bloodbank_donors/services/cloud_functions_service.dart';

// ---------- Mocks ----------
class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock
    implements HttpsCallableResult {}

void main() {
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late CloudFunctionsService service;

  setUp(() {
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();

    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    service = CloudFunctionsService(functions: mockFunctions);
  });

  group('CloudFunctionsService - Unit Tests', () {
    test('createPendingProfile returns data on success', () async {
      final mockResult = MockHttpsCallableResult();

      when(() => mockResult.data).thenReturn({
        'ok': true,
        'message': 'Profile created',
      });

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      final result = await service.createPendingProfile(
        role: 'donor',
        fullName: 'Ali',
        bloodType: 'A+',
        location: 'Amman',
      );

      expect(result['ok'], true);
      expect(result['message'], 'Profile created');
    });

    test('getUserRole returns role correctly', () async {
      final mockResult = MockHttpsCallableResult();

      when(() => mockResult.data).thenReturn({
        'role': 'hospital',
      });

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      final role = await service.getUserRole();

      expect(role, 'hospital');
    });

    test('throws user-friendly error on unauthenticated', () async {
      when(() => mockCallable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Not logged in',
        ),
      );

      expect(
        () => service.getUserData(),
        throwsA(isA<Exception>()),
      );
    });

    test('addRequest returns success', () async {
  final mockResult = MockHttpsCallableResult();

  when(() => mockResult.data).thenReturn({'ok': true});
  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  final result = await service.addRequest(
    requestId: 'r1',
    bloodBankName: 'Test Bank',
    bloodType: 'A+',
    units: 2,
    isUrgent: true,
    hospitalLocation: 'Amman',
  );

  expect(result['ok'], true);
});

test('getRequests returns list', () async {
  final mockResult = MockHttpsCallableResult();

  when(() => mockResult.data).thenReturn({
    'requests': [],
  });
  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  final result = await service.getRequests();

  expect(result['requests'], isA<List>());
});

test('markNotificationsAsRead success', () async {
  final mockResult = MockHttpsCallableResult();

  when(() => mockResult.data).thenReturn({'ok': true});
  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  final result = await service.markNotificationsAsRead();

  expect(result['ok'], true);
});

test('deleteNotification success', () async {
  final mockResult = MockHttpsCallableResult();

  when(() => mockResult.data).thenReturn({'ok': true});
  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  final result = await service.deleteNotification(
    notificationId: 'n1',
  );

  expect(result['ok'], true);
});

test('sendMessage success', () async {
  final mockResult = MockHttpsCallableResult();

  when(() => mockResult.data).thenReturn({'ok': true});
  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  final result = await service.sendMessage(
    requestId: 'r1',
    text: 'Hello',
  );

  expect(result['ok'], true);
});


test('handleFunctionsException maps permission-denied', () async {
  when(() => mockCallable.call(any())).thenThrow(
    FirebaseFunctionsException(
      code: 'permission-denied',
      message: 'No access',
    ),
  );

  expect(
    () => service.getUserRole(),
    throwsA(isA<Exception>()),
  );
});

test('handleFunctionsException maps not-found', () async {
  when(() => mockCallable.call(any())).thenThrow(
    FirebaseFunctionsException(
      code: 'not-found',
      message: 'Not found',
    ),
  );

  expect(
    () => service.getUserData(),
    throwsA(isA<Exception>()),
  );
});




  });
}
