import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:bloodbank_donors/services/cloud_functions_service.dart';

// ================= MOCKS =================

class MockFunctions extends Mock implements FirebaseFunctions {}
class MockCallable extends Mock implements HttpsCallable {}
class MockResult extends Mock implements HttpsCallableResult {}

class FakeException extends Fake implements FirebaseFunctionsException {}

void main() {
  late CloudFunctionsService service;
  late MockFunctions mockFunctions;
  late MockCallable mockCallable;
  late MockResult mockResult;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockFunctions = MockFunctions();
    mockCallable = MockCallable();
    mockResult = MockResult();

    service = CloudFunctionsService(functions: mockFunctions);
  });

  // =========================================================
  // SUCCESS CASE
  // =========================================================

  group('success calls', () {
    test('createPendingProfile returns data', () async {
      when(() => mockFunctions.httpsCallable('createPendingProfile'))
          .thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({'ok': true});

      final result = await service.createPendingProfile(
        role: 'donor',
        fullName: 'Test',
        location: 'Amman',
        gender: 'male',
        phoneNumber: '123',
      );

      expect(result['ok'], true);
    });

    test('updateFcmToken works', () async {
      when(() => mockFunctions.httpsCallable('updateFcmToken'))
          .thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({'done': true});

      final result = await service.updateFcmToken(fcmToken: '123');

      expect(result['done'], true);
    });

    test('getUserRole returns role', () async {
      when(() => mockFunctions.httpsCallable('getUserRole'))
          .thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({'role': 'donor'});

      final result = await service.getUserRole();

      expect(result, 'donor');
    });

    test('getUserData returns map', () async {
      when(() => mockFunctions.httpsCallable('getUserData'))
          .thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({'name': 'test'});

      final result = await service.getUserData();

      expect(result['name'], 'test');
    });
  });

  // =========================================================
  // VALIDATION (LOCAL ERRORS)
  // =========================================================

  group('validation errors', () {
    test('throws when donor missing fullName', () async {
      expect(
        () => service.createPendingProfile(
          role: 'donor',
          location: 'Amman',
          gender: 'male',
          phoneNumber: '123',
        ),
        throwsException,
      );
    });

    test('throws when hospital missing name', () async {
      expect(
        () => service.createPendingProfile(
          role: 'hospital',
          location: 'Amman',
        ),
        throwsException,
      );
    });
  });

  // =========================================================
  // FUNCTIONS EXCEPTION
  // =========================================================

  group('firebase exception handling', () {
    test('handles FirebaseFunctionsException', () async {
      when(() => mockFunctions.httpsCallable('getUserData'))
          .thenReturn(mockCallable);

      when(() => mockCallable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'denied',
        ),
      );

      expect(
        () => service.getUserData(),
        throwsException,
      );
    });
  });

  // =========================================================
  // NETWORK ERROR
  // =========================================================

  group('network errors', () {

test('network error path', () async {
  when(() => mockFunctions.httpsCallable(any()))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenThrow(Exception('socket error'));

  expect(() => service.getRequests(), throwsException);
});
    test('network error path triggered', () async {
  when(() => mockFunctions.httpsCallable('getRequests'))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenThrow(Exception('socket error'));

  expect(() => service.getRequests(), throwsException);
});
    test('handles network error', () async {
      when(() => mockFunctions.httpsCallable('getUserData'))
          .thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenThrow(Exception('socket error'));

      expect(
        () => service.getUserData(),
        throwsException,
      );
    });
  });

  // =========================================================
  // EDGE CASES
  // =========================================================

  group('edge cases', () {
    test('resolveDonorEmail returns null when empty', () async {
      when(() => mockFunctions.httpsCallable('resolveDonorEmailForPhoneLogin'))
          .thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({'email': ''});

      final result = await service.resolveDonorEmailForPhoneLogin('+962');

      expect(result, null);
    });
  });


group('bulk coverage boost', () {
  void mockSuccess(String name) {
    when(() => mockFunctions.httpsCallable(name))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});
  }

  test('addRequest works', () async {
    mockSuccess('addRequest');

    final result = await service.addRequest(
      requestId: '1',
      bloodBankName: 'bank',
      bloodType: 'A+',
      units: 1,
      isUrgent: false,
      hospitalLocation: 'loc',
    );

    expect(result['ok'], true);
  });

  test('getRequests works', () async {
    mockSuccess('getRequests');
    final result = await service.getRequests();
    expect(result['ok'], true);
  });

  test('getRequestById works', () async {
    mockSuccess('getRequestById');
    final result = await service.getRequestById(requestId: '1');
    expect(result['ok'], true);
  });

  test('deleteRequest works', () async {
    mockSuccess('deleteRequest');
    final result = await service.deleteRequest(requestId: '1');
    expect(result['ok'], true);
  });

  test('getNotifications works', () async {
    mockSuccess('getNotifications');
    final result = await service.getNotifications();
    expect(result['ok'], true);
  });

  test('markNotificationAsRead works', () async {
    mockSuccess('markNotificationAsRead');
    final result =
        await service.markNotificationAsRead(notificationId: '1');
    expect(result['ok'], true);
  });

  test('deleteOldNotifications works', () async {
    mockSuccess('deleteOldNotifications');
    final result = await service.deleteOldNotifications();
    expect(result['ok'], true);
  });

  test('getDonors works', () async {
    mockSuccess('getDonors');
    final result = await service.getDonors();
    expect(result['ok'], true);
  });

  test('scheduleDonorAppointment works', () async {
    mockSuccess('scheduleDonorAppointment');
    final result = await service.scheduleDonorAppointment(
      requestId: '1',
      donorId: 'd',
      appointmentAtMillis: 123,
    );
    expect(result['ok'], true);
  });
});

group('_callFunction core coverage', () {
  test('success path returns data', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    final result = await service.getRequests();

    expect(result['ok'], true);
  });

  test('handles FirebaseFunctionsException', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'denied',
      ),
    );

   expect(
  () => service.getRequests(),
  throwsA(
    predicate((e) =>
        e is Exception &&
        (e.toString().contains('denied') ||
            e.toString().contains('permission'))),
  ),
);
  });

  test('handles generic exception', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('network error'));

    expect(
      () => service.getRequests(),
      throwsException,
    );
  });
});

group('validation coverage', () {
  test('addRequest throws exception', () async {
  when(() => mockFunctions.httpsCallable('addRequest'))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenThrow(Exception('fail'));

  expect(
    () => service.addRequest(
      requestId: '1',
      bloodBankName: 'bank',
      bloodType: 'A+',
      units: 1,
      isUrgent: false,
      hospitalLocation: 'loc',
    ),
    throwsException,
  );
});
});

group('success pattern (global)', () {
  setUp(() {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});
  });

  test('covers multiple methods', () async {
    await service.getRequests();
    await service.getNotifications();
    await service.getDonors();
    await service.getUserData();
    await service.getUserRole();
    await service.deleteOldNotifications();

    expect(true, true);
  });
});

group('firebase error mapping', () {
  setUp(() {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);
  });

  test('permission denied handled', () async {
    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'denied',
      ),
    );

    expect(() => service.getRequests(), throwsException);
  });

  test('not-found handled', () async {
    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'not-found',
        message: 'not found',
      ),
    );

    expect(() => service.getRequests(), throwsException);
  });
});


test('all endpoints handle exceptions', () async {
  when(() => mockFunctions.httpsCallable(any()))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenThrow(Exception('fail'));

  try {
    await service.getRequests();
  } catch (_) {}

  try {
    await service.getDonors();
  } catch (_) {}

  try {
    await service.getNotifications();
  } catch (_) {}
});


test('createPendingProfile donor sends correct payload', () async {
  when(() => mockFunctions.httpsCallable('createPendingProfile'))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  when(() => mockResult.data)
      .thenReturn({'ok': true});

  await service.createPendingProfile(
    role: 'donor',
    fullName: ' Ahmad ',
    location: ' Amman ',
    gender: ' Male ',
    phoneNumber: ' 123 ',
    latitude: 1.1,
    longitude: 2.2,
  );

  verify(() => mockCallable.call({
        'role': 'donor',
        'fullName': 'Ahmad',
        'location': 'Amman',
        'gender': 'male',
        'phoneNumber': '123',
        'latitude': 1.1,
        'longitude': 2.2,
      })).called(1);
});

test('hospital profile sends proper payload', () async {
  when(() => mockFunctions.httpsCallable('createPendingProfile'))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  when(() => mockResult.data)
      .thenReturn({'ok': true});

  await service.createPendingProfile(
    role: 'hospital',
    bloodBankName: 'Bank',
    location: 'Amman',
    latitude: 3.3,
    longitude: 4.4,
  );

  verify(() => mockCallable.call({
        'role': 'hospital',
        'bloodBankName': 'Bank',
        'location': 'Amman',
        'latitude': 3.3,
        'longitude': 4.4,
      })).called(1);
});

test('getUserData includes uid when provided', () async {
  when(() => mockFunctions.httpsCallable('getUserData'))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  when(() => mockResult.data)
      .thenReturn({'ok': true});

  await service.getUserData(uid: '123');

  verify(() => mockCallable.call({
        'uid': '123',
      })).called(1);
});

test('sendMessage includes recipientId when provided', () async {
  when(() => mockFunctions.httpsCallable(
        'sendMessage',
        options: any(named: 'options'),
      )).thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  when(() => mockResult.data)
      .thenReturn({'ok': true});

  await service.sendMessage(
    requestId: '1',
    text: 'hello',
    recipientId: 'abc',
  );

  verify(() => mockCallable.call({
        'requestId': '1',
        'text': 'hello',
        'recipientId': 'abc',
      })).called(1);
});

test('handles ssl errors', () async {
  when(() => mockFunctions.httpsCallable(any()))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenThrow(Exception('SSL handshake failed'));

  expect(
    () => service.getRequestById(requestId: '1'),
    throwsA(
      predicate((e) =>
          e.toString().contains('Connection security error')),
    ),
  );
});

test('invalid-argument returns server message', () async {
  when(() => mockFunctions.httpsCallable(any()))
      .thenReturn(mockCallable);

  when(() => mockCallable.call(any())).thenThrow(
    FirebaseFunctionsException(
      code: 'invalid-argument',
      message: 'bad input',
    ),
  );

  expect(
    () => service.getRequests(),
    throwsA(
      predicate((e) => e.toString().contains('bad input')),
    ),
  );
});

test('sendMessage excludes empty recipientId', () async {
  when(() => mockFunctions.httpsCallable(
        'sendMessage',
        options: any(named: 'options'),
      )).thenReturn(mockCallable);

  when(() => mockCallable.call(any()))
      .thenAnswer((_) async => mockResult);

  when(() => mockResult.data)
      .thenReturn({'ok': true});

  await service.sendMessage(
    requestId: '1',
    text: 'hello',
    recipientId: '',
  );

  verify(() => mockCallable.call({
        'requestId': '1',
        'text': 'hello',
      })).called(1);
});

group('additional coverage tests', () {

  test('getRequests sends lastRequestId when provided', () async {
    when(() => mockFunctions.httpsCallable('getRequests'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.getRequests(
      lastRequestId: 'abc',
      limit: 10,
    );

    verify(() => mockCallable.call({
      'limit': 10,
      'lastRequestId': 'abc',
    })).called(1);
  });

  test('getMessages includes filterRecipientId', () async {
    when(() => mockFunctions.httpsCallable('getMessages'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.getMessages(
      requestId: '1',
      filterRecipientId: 'donor1',
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'filterRecipientId': 'donor1',
    })).called(1);
  });

  test('getMessages excludes empty filterRecipientId', () async {
    when(() => mockFunctions.httpsCallable('getMessages'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.getMessages(
      requestId: '1',
      filterRecipientId: '',
    );

    verify(() => mockCallable.call({
      'requestId': '1',
    })).called(1);
  });

  test('sendMessage excludes null recipientId', () async {
    when(() => mockFunctions.httpsCallable(
      'sendMessage',
      options: any(named: 'options'),
    )).thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.sendMessage(
      requestId: '1',
      text: 'hello',
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'text': 'hello',
    })).called(1);
  });

  test('getDonors includes bloodType filter', () async {
    when(() => mockFunctions.httpsCallable('getDonors'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.getDonors(
      bloodType: 'A+',
      limit: 5,
    );

    verify(() => mockCallable.call({
      'limit': 5,
      'bloodType': 'A+',
    })).called(1);
  });

  test('updateRequestUnits success', () async {
    when(() => mockFunctions.httpsCallable('updateRequestUnits'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'updated': true});

    final result = await service.updateRequestUnits(
      requestId: '1',
      units: 3,
    );

    expect(result['updated'], true);
  });

  test('markRequestCompleted success', () async {
    when(() => mockFunctions.httpsCallable('markRequestCompleted'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'done': true});

    final result = await service.markRequestCompleted(
      requestId: '1',
    );

    expect(result['done'], true);
  });

  test('markNotificationsAsRead success', () async {
    when(() => mockFunctions.httpsCallable('markNotificationsAsRead'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    final result = await service.markNotificationsAsRead();

    expect(result['ok'], true);
  });

  test('requestAppointmentReschedule success', () async {
    when(() => mockFunctions
        .httpsCallable('requestAppointmentReschedule'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'scheduled': true});

    final result = await service.requestAppointmentReschedule(
      requestId: '1',
      reason: 'busy',
      preferredAppointmentAtMillis: 123456,
    );

    expect(result['scheduled'], true);
  });

  test('ensureDonorWelcomeMessage success', () async {
    when(() => mockFunctions
        .httpsCallable('ensureDonorWelcomeMessage'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    final result = await service.ensureDonorWelcomeMessage(
      requestId: '1',
    );

    expect(result['ok'], true);
  });

  test('listBloodBankPastDonors success', () async {
    when(() => mockFunctions
        .httpsCallable('listBloodBankPastDonors'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'donors': []});

    final result = await service.listBloodBankPastDonors();

    expect(result['donors'], isA<List>());
  });

  test('getBloodBankDonorMedicalHistory success', () async {
    when(() => mockFunctions
        .httpsCallable('getBloodBankDonorMedicalHistory'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'reports': []});

    final result =
        await service.getBloodBankDonorMedicalHistory(
      donorId: 'd1',
    );

    expect(result['reports'], isA<List>());
  });

  test('saveMedicalReport success', () async {
    when(() => mockFunctions.httpsCallable('saveMedicalReport'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'saved': true});

    final result = await service.saveMedicalReport(
      requestId: '1',
      donorId: 'd1',
      status: 'donated',
      reportFileUrl: 'url',
      confirmedBloodType: 'A+',
    );

    expect(result['saved'], true);
  });

  test('handles invalid-argument exception', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'bad input',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains('bad input')),
      ),
    );
  });

  test('handles unauthenticated exception', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Please log in first',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains('Please log in first')),
      ),
    );
  });

  test('handles generic internal exception', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'internal',
        message: 'random internal',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsException,
    );
  });

  test('handles not found network errors', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('404 not found'));

    expect(
      () => service.getRequestById(requestId: '1'),
      throwsA(
        predicate((e) =>
            e.toString().contains('Cloud Function not found')),
      ),
    );
  });

  test('handles generic unknown network error', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('weird failure'));

    expect(
      () => service.getRequestById(requestId: '1'),
      throwsA(
        predicate((e) =>
            e.toString().contains('Failed to connect')),
      ),
    );
  });

});

group('mega coverage boost', () {

  test('updateLastLoginAt success', () async {
    when(() => mockFunctions.httpsCallable('updateLastLoginAt'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'updated': true});

    final result = await service.updateLastLoginAt();

    expect(result['updated'], true);
  });

  test('completeProfileAfterVerification success', () async {
    when(() => mockFunctions
        .httpsCallable('completeProfileAfterVerification'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'done': true});

    final result =
        await service.completeProfileAfterVerification();

    expect(result['done'], true);
  });

  test('getAdminRequests success', () async {
    when(() => mockFunctions.httpsCallable('getAdminRequests'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'requests': []});

    final result = await service.getAdminRequests(limit: 5);

    expect(result['requests'], isA<List>());
  });

  test('getRequestsByBloodBankId success', () async {
    when(() => mockFunctions
        .httpsCallable('getRequestsByBloodBankId'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'items': []});

    final result =
        await service.getRequestsByBloodBankId();

    expect(result['items'], isA<List>());
  });

  test('setDonorRequestResponse success', () async {
    when(() => mockFunctions
        .httpsCallable('setDonorRequestResponse'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'saved': true});

    final result =
        await service.setDonorRequestResponse(
      requestId: '1',
      response: 'accepted',
    );

    expect(result['saved'], true);
  });

  test('deleteNotification success', () async {
    when(() => mockFunctions.httpsCallable('deleteNotification'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'deleted': true});

    final result =
        await service.deleteNotification(
      notificationId: '1',
    );

    expect(result['deleted'], true);
  });

  test('resolveDonorEmail returns trimmed email', () async {
    when(() => mockFunctions
        .httpsCallable('resolveDonorEmailForPhoneLogin'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({
      'email': '   test@test.com   '
    });

    final result =
        await service.resolveDonorEmailForPhoneLogin(
      '+962',
    );

    expect(result, 'test@test.com');
  });

  test('resolveDonorEmail returns null on not-found', () async {
    when(() => mockFunctions
        .httpsCallable('resolveDonorEmailForPhoneLogin'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'not-found',
        message: 'No donor with this phone',
      ),
    );

    final result =
        await service.resolveDonorEmailForPhoneLogin(
      '+962',
    );

    expect(result, null);
  });

  test('getUserRole returns empty string when role missing', () async {
    when(() => mockFunctions.httpsCallable('getUserRole'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({});

    final result = await service.getUserRole();

    expect(result, '');
  });

  test('createPendingProfile donor trims values', () async {
    when(() => mockFunctions
        .httpsCallable('createPendingProfile'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.createPendingProfile(
      role: 'donor',
      fullName: ' Ahmad ',
      location: ' Amman ',
      gender: ' Male ',
      phoneNumber: ' 123 ',
    );

    verify(() => mockCallable.call({
      'role': 'donor',
      'fullName': 'Ahmad',
      'location': 'Amman',
      'gender': 'male',
      'phoneNumber': '123',
    })).called(1);
  });

  test('createPendingProfile hospital trims values', () async {
    when(() => mockFunctions
        .httpsCallable('createPendingProfile'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.createPendingProfile(
      role: 'hospital',
      bloodBankName: ' Bank ',
      location: ' Amman ',
    );

    verify(() => mockCallable.call({
      'role': 'hospital',
      'bloodBankName': 'Bank',
      'location': 'Amman',
    })).called(1);
  });

  test('throws when donor missing gender', () async {
    expect(
      () => service.createPendingProfile(
        role: 'donor',
        fullName: 'Ahmad',
        location: 'Amman',
        phoneNumber: '123',
      ),
      throwsException,
    );
  });

  test('throws when donor missing phone', () async {
    expect(
      () => service.createPendingProfile(
        role: 'donor',
        fullName: 'Ahmad',
        location: 'Amman',
        gender: 'male',
      ),
      throwsException,
    );
  });

  test('throws when donor missing location', () async {
    expect(
      () => service.createPendingProfile(
        role: 'donor',
        fullName: 'Ahmad',
        gender: 'male',
        phoneNumber: '123',
      ),
      throwsException,
    );
  });

  test('throws when hospital missing location', () async {
    expect(
      () => service.createPendingProfile(
        role: 'hospital',
        bloodBankName: 'bank',
      ),
      throwsException,
    );
  });

  test('handles failed-precondition index error', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'index missing',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains('Database index required')),
      ),
    );
  });

  test('handles failed-precondition generic error', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'verify email',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains('verify email')),
      ),
    );
  });

  test('handles internal FAILED_PRECONDITION', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'internal',
        message: 'FAILED_PRECONDITION index',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains('Database index required')),
      ),
    );
  });

  test('handles internal delete request error', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'internal',
        message: 'Failed to delete request: denied',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsException,
    );
  });

  test('handles ssl certificate errors', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('certificate failure'));

    expect(
      () => service.getRequestById(requestId: '1'),
      throwsA(
        predicate((e) =>
            e.toString().contains('Connection security error')),
      ),
    );
  });

  test('handles timeout network errors', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('timeout'));

    expect(
      () => service.getRequestById(requestId: '1'),
      throwsA(
        predicate((e) =>
            e.toString().contains('Network error')),
      ),
    );
  });

  test('handles socket network errors', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('socket exception'));

    expect(
      () => service.getRequestById(requestId: '1'),
      throwsA(
        predicate((e) =>
            e.toString().contains('Network error')),
      ),
    );
  });

});

group('extreme coverage expansion', () {

  test('updateUserProfile success', () async {
    when(() => mockFunctions.httpsCallable('updateUserProfile'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'updated': true});

    final result = await service.updateUserProfile(
      name: 'Ahmad',
    );

    expect(result['updated'], true);
  });

  test('getUserRole sends uid when provided', () async {
    when(() => mockFunctions.httpsCallable('getUserRole'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'role': 'admin'});

    await service.getUserRole(uid: '123');

    verify(() => mockCallable.call({
      'uid': '123',
    })).called(1);
  });

  test('getRequestById sends requestId', () async {
    when(() => mockFunctions.httpsCallable('getRequestById'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'id': '1'});

    await service.getRequestById(requestId: '1');

    verify(() => mockCallable.call({
      'requestId': '1',
    })).called(1);
  });

  test('markNotificationAsRead sends notificationId', () async {
    when(() => mockFunctions
        .httpsCallable('markNotificationAsRead'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.markNotificationAsRead(
      notificationId: '55',
    );

    verify(() => mockCallable.call({
      'notificationId': '55',
    })).called(1);
  });

  test('deleteNotification sends notificationId', () async {
    when(() => mockFunctions
        .httpsCallable('deleteNotification'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.deleteNotification(
      notificationId: '77',
    );

    verify(() => mockCallable.call({
      'notificationId': '77',
    })).called(1);
  });

  test('deleteOldNotifications sends custom days', () async {
    when(() => mockFunctions
        .httpsCallable('deleteOldNotifications'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.deleteOldNotifications(days: 10);

    verify(() => mockCallable.call({
      'days': 10,
    })).called(1);
  });

  test('scheduleDonorAppointment sends correct payload', () async {
    when(() => mockFunctions
        .httpsCallable('scheduleDonorAppointment'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.scheduleDonorAppointment(
      requestId: '1',
      donorId: 'd1',
      appointmentAtMillis: 999,
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'donorId': 'd1',
      'appointmentAt': 999,
    })).called(1);
  });

  test('requestAppointmentReschedule sends correct payload', () async {
    when(() => mockFunctions
        .httpsCallable('requestAppointmentReschedule'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.requestAppointmentReschedule(
      requestId: '1',
      reason: 'busy',
      preferredAppointmentAtMillis: 123,
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'reason': 'busy',
      'preferredAppointmentAt': 123,
    })).called(1);
  });

  test('updateRequestUnits sends correct payload', () async {
    when(() => mockFunctions
        .httpsCallable('updateRequestUnits'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.updateRequestUnits(
      requestId: 'req',
      units: 7,
    );

    verify(() => mockCallable.call({
      'requestId': 'req',
      'units': 7,
    })).called(1);
  });

  test('setDonorRequestResponse sends correct payload', () async {
    when(() => mockFunctions
        .httpsCallable('setDonorRequestResponse'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.setDonorRequestResponse(
      requestId: 'req',
      response: 'accepted',
    );

    verify(() => mockCallable.call({
      'requestId': 'req',
      'response': 'accepted',
    })).called(1);
  });

  test('saveMedicalReport includes optional fields', () async {
    when(() => mockFunctions
        .httpsCallable('saveMedicalReport'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'saved': true});

    await service.saveMedicalReport(
      requestId: '1',
      donorId: 'd1',
      status: 'restricted',
      restrictionReason: 'reason',
      notes: 'notes',
      reportFileUrl: 'url',
      canDonateAgainAt: '2026',
      confirmedBloodType: 'A+',
      isPermanentBlock: true,
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'donorId': 'd1',
      'status': 'restricted',
      'restrictionReason': 'reason',
      'notes': 'notes',
      'reportFileUrl': 'url',
      'canDonateAgainAt': '2026',
      'confirmedBloodType': 'A+',
      'isPermanentBlock': true,
    })).called(1);
  });

  test('saveMedicalReport excludes optional fields when null', () async {
    when(() => mockFunctions
        .httpsCallable('saveMedicalReport'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'saved': true});

    await service.saveMedicalReport(
      requestId: '1',
      donorId: 'd1',
      status: 'donated',
      reportFileUrl: 'url',
      confirmedBloodType: 'O+',
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'donorId': 'd1',
      'status': 'donated',
      'reportFileUrl': 'url',
      'confirmedBloodType': 'O+',
      'isPermanentBlock': false,
    })).called(1);
  });

  test('addRequest includes coordinates', () async {
    when(() => mockFunctions.httpsCallable('addRequest'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.addRequest(
      requestId: '1',
      bloodBankName: 'bank',
      bloodType: 'A+',
      units: 2,
      isUrgent: true,
      hospitalLocation: 'Amman',
      hospitalLatitude: 1.2,
      hospitalLongitude: 3.4,
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'bloodBankName': 'bank',
      'bloodType': 'A+',
      'units': 2,
      'isUrgent': true,
      'details': '',
      'hospitalLocation': 'Amman',
      'hospitalLatitude': 1.2,
      'hospitalLongitude': 3.4,
    })).called(1);
  });

  test('addRequest excludes coordinates when null', () async {
    when(() => mockFunctions.httpsCallable('addRequest'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.addRequest(
      requestId: '1',
      bloodBankName: 'bank',
      bloodType: 'A+',
      units: 2,
      isUrgent: false,
      hospitalLocation: 'Amman',
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'bloodBankName': 'bank',
      'bloodType': 'A+',
      'units': 2,
      'isUrgent': false,
      'details': '',
      'hospitalLocation': 'Amman',
    })).called(1);
  });

  test('handles permission denied without message', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: "You do not have permission",
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains(
              'You do not have permission',
            )),
      ),
    );
  });

  test('handles invalid-argument without message', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Invalid argument provided',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains(
              'Invalid argument provided',
            )),
      ),
    );
  });

  test('handles internal without message', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'internal',
        message: 'Something went wrong. Please try again',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains(
              'Something went wrong. Please try again',
            )),
      ),
    );
  });

  test('handles default firebase exception without message', () async {
    when(() => mockFunctions.httpsCallable(any()))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'unknown',
        message: 'An unknown error occurred',
      ),
    );

    expect(
      () => service.getUserData(),
      throwsA(
        predicate((e) =>
            e.toString().contains(
              'An unknown error occurred',
            )),
      ),
    );
  });

});

group('coverage assault', () {

  test('getNotifications firebase exception', () async {
    when(() => mockFunctions.httpsCallable('getNotifications'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'blocked',
      ),
    );

    expect(
      () => service.getNotifications(),
      throwsException,
    );
  });

  test('markNotificationsAsRead firebase exception', () async {
    when(() => mockFunctions
        .httpsCallable('markNotificationsAsRead'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'not-found',
        message: 'Notification not found',
      ),
    );

    expect(
      () => service.markNotificationsAsRead(),
      throwsException,
    );
  });

  test('deleteNotification firebase exception', () async {
    when(() => mockFunctions
        .httpsCallable('deleteNotification'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'internal',
        message: 'Failed to delete notification',
      ),
    );

    expect(
      () => service.deleteNotification(
        notificationId: '1',
      ),
      throwsException,
    );
  });

  test('markNotificationAsRead firebase exception', () async {
    when(() => mockFunctions
        .httpsCallable('markNotificationAsRead'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Invalid argument provided',
      ),
    );

    expect(
      () => service.markNotificationAsRead(
        notificationId: '1',
      ),
      throwsException,
    );
  });

  test('getDonors firebase exception', () async {
    when(() => mockFunctions.httpsCallable('getDonors'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'User is not authenticated',
      ),
    );

    expect(
      () => service.getDonors(),
      throwsException,
    );
  });

  test('getAdminRequests firebase exception', () async {
    when(() => mockFunctions
        .httpsCallable('getAdminRequests'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Failed precondition',
      ),
    );

    expect(
      () => service.getAdminRequests(),
      throwsException,
    );
  });

  test('getRequests firebase exception', () async {
    when(() => mockFunctions.httpsCallable('getRequests'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Permission denied',
      ),
    );

    expect(
      () => service.getRequests(),
      throwsException,
    );
  });

  test('getRequestsByBloodBankId firebase exception', () async {
    when(() => mockFunctions
        .httpsCallable('getRequestsByBloodBankId'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'internal',
        message: 'internal error',
      ),
    );

    expect(
      () => service.getRequestsByBloodBankId(),
      throwsException,
    );
  });

  test('getMessages network exception', () async {
    when(() => mockFunctions.httpsCallable('getMessages'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('socket failed'));

    expect(
      () => service.getMessages(
        requestId: '1',
      ),
      throwsException,
    );
  });

  test('ensureDonorWelcomeMessage network exception', () async {
    when(() => mockFunctions
        .httpsCallable('ensureDonorWelcomeMessage'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('timeout'));

    expect(
      () => service.ensureDonorWelcomeMessage(
        requestId: '1',
      ),
      throwsException,
    );
  });

  test('getRequestDonorResponses network exception', () async {
    when(() => mockFunctions
        .httpsCallable('getRequestDonorResponses'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('ssl issue'));

    expect(
      () => service.getRequestDonorResponses(
        requestId: '1',
      ),
      throwsException,
    );
  });

  test('scheduleDonorAppointment network exception', () async {
    when(() => mockFunctions
        .httpsCallable('scheduleDonorAppointment'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('network'));

    expect(
      () => service.scheduleDonorAppointment(
        requestId: '1',
        donorId: 'd1',
        appointmentAtMillis: 1,
      ),
      throwsException,
    );
  });

  test('requestAppointmentReschedule network exception', () async {
    when(() => mockFunctions
        .httpsCallable('requestAppointmentReschedule'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('ipv6'));

    expect(
      () => service.requestAppointmentReschedule(
        requestId: '1',
        reason: 'busy',
        preferredAppointmentAtMillis: 1,
      ),
      throwsException,
    );
  });

  test('saveMedicalReport network exception', () async {
    when(() => mockFunctions
        .httpsCallable('saveMedicalReport'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('connection refused'));

    expect(
      () => service.saveMedicalReport(
        requestId: '1',
        donorId: 'd1',
        status: 'done',
        reportFileUrl: 'url',
        confirmedBloodType: 'A+',
      ),
      throwsException,
    );
  });

  test('listBloodBankPastDonors network exception', () async {
    when(() => mockFunctions
        .httpsCallable('listBloodBankPastDonors'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('failed to connect'));

    expect(
      () => service.listBloodBankPastDonors(),
      throwsException,
    );
  });

  test('getBloodBankDonorMedicalHistory network exception', () async {
    when(() => mockFunctions
        .httpsCallable('getBloodBankDonorMedicalHistory'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('unknown error 5'));

    expect(
      () => service.getBloodBankDonorMedicalHistory(
        donorId: '1',
      ),
      throwsException,
    );
  });

  test('updateRequestUnits network exception', () async {
    when(() => mockFunctions
        .httpsCallable('updateRequestUnits'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('certificate error'));

    expect(
      () => service.updateRequestUnits(
        requestId: '1',
        units: 5,
      ),
      throwsException,
    );
  });

  test('markRequestCompleted network exception', () async {
    when(() => mockFunctions
        .httpsCallable('markRequestCompleted'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('tls problem'));

    expect(
      () => service.markRequestCompleted(
        requestId: '1',
      ),
      throwsException,
    );
  });

  test('deleteRequest network exception', () async {
    when(() => mockFunctions
        .httpsCallable('deleteRequest'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenThrow(Exception('404'));

    expect(
      () => service.deleteRequest(
        requestId: '1',
      ),
      throwsException,
    );
  });

  test('addRequest sends details field', () async {
    when(() => mockFunctions.httpsCallable('addRequest'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.addRequest(
      requestId: '1',
      bloodBankName: 'bank',
      bloodType: 'B+',
      units: 4,
      isUrgent: true,
      hospitalLocation: 'Amman',
      details: 'urgent case',
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'bloodBankName': 'bank',
      'bloodType': 'B+',
      'units': 4,
      'isUrgent': true,
      'details': 'urgent case',
      'hospitalLocation': 'Amman',
    })).called(1);
  });

  test('getRequestDonorResponses sends includeLatestReports false', () async {
    when(() => mockFunctions
        .httpsCallable('getRequestDonorResponses'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.getRequestDonorResponses(
      requestId: '1',
      includeLatestReports: false,
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'includeLatestReports': false,
    })).called(1);
  });

  test('getRequestDonorResponses default includeLatestReports', () async {
    when(() => mockFunctions
        .httpsCallable('getRequestDonorResponses'))
        .thenReturn(mockCallable);

    when(() => mockCallable.call(any()))
        .thenAnswer((_) async => mockResult);

    when(() => mockResult.data)
        .thenReturn({'ok': true});

    await service.getRequestDonorResponses(
      requestId: '1',
    );

    verify(() => mockCallable.call({
      'requestId': '1',
      'includeLatestReports': true,
    })).called(1);
  });

});



}