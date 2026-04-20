import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/blood_bank_dashboard_controller.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';

// ---------------- Mocks ----------------

class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  late MockCloudFunctionsService mockCloudFunctions;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late BloodBankDashboardController controller;
// ================= SETUP =================
setUp(() {
  mockCloudFunctions = MockCloudFunctionsService();
  mockAuth = MockFirebaseAuth();
  mockUser = MockUser();

  controller = BloodBankDashboardController(
    cloudFunctions: mockCloudFunctions,
    auth: mockAuth,
  );
});

// ================= AUTH =================
group('Auth', () {
  test('getCurrentUserId returns uid', () {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    expect(controller.getCurrentUserId(), 'u1');
  });

  test('getCurrentUserId returns null when no user', () {
    when(() => mockAuth.currentUser).thenReturn(null);

    expect(controller.getCurrentUserId(), null);
  });

  test('verifyRequestOwnership true', () {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    expect(controller.verifyRequestOwnership('u1'), true);
  });

  test('verifyRequestOwnership false when mismatch', () {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    expect(controller.verifyRequestOwnership('x'), false);
  });

  test('verifyRequestOwnership false when user null', () {
    when(() => mockAuth.currentUser).thenReturn(null);

    expect(controller.verifyRequestOwnership('u1'), false);
  });
});

// ================= DELETE =================
group('deleteRequest', () {
  test('success', () async {
    when(() => mockCloudFunctions.deleteRequest(requestId: 'r1'))
        .thenAnswer((_) async => {'ok': true});

    final result = await controller.deleteRequest(requestId: 'r1');

    expect(result['ok'], true);
  });

  test('empty requestId throws', () {
    expect(() => controller.deleteRequest(requestId: ''), throwsException);
  });

  test('rethrows exception', () {
    when(() => mockCloudFunctions.deleteRequest(requestId: 'r1'))
        .thenThrow(Exception('fail'));

    expect(
      () => controller.deleteRequest(requestId: 'r1'),
      throwsException,
    );
  });
});

// ================= COMPLETE =================
group('markRequestCompleted', () {
  test('success', () async {
    when(() => mockCloudFunctions.markRequestCompleted(requestId: 'r1'))
        .thenAnswer((_) async => {'ok': true});

    final result =
        await controller.markRequestCompleted(requestId: 'r1');

    expect(result['ok'], true);
  });

  test('empty requestId throws', () {
    expect(
      () => controller.markRequestCompleted(requestId: ''),
      throwsException,
    );
  });

  test('exception rethrow', () {
    when(() => mockCloudFunctions.markRequestCompleted(requestId: 'r1'))
        .thenThrow(Exception());

    expect(
      () => controller.markRequestCompleted(requestId: 'r1'),
      throwsException,
    );
  });
});

// ================= UPDATE =================
group('updateRequestUnits', () {
  test('success', () async {
    when(() => mockCloudFunctions.updateRequestUnits(
          requestId: any(named: 'requestId'),
          units: any(named: 'units'),
        )).thenAnswer((_) async => {'ok': true});

    final result = await controller.updateRequestUnits(
      requestId: 'r1',
      units: 2,
    );

    expect(result['ok'], true);
  });

  test('empty requestId throws', () {
    expect(
      () => controller.updateRequestUnits(requestId: '', units: 1),
      throwsException,
    );
  });

  test('units < 1 throws', () {
    expect(
      () => controller.updateRequestUnits(requestId: 'r1', units: 0),
      throwsException,
    );
  });

  test('exception rethrow', () {
    when(() => mockCloudFunctions.updateRequestUnits(
          requestId: any(named: 'requestId'),
          units: any(named: 'units'),
        )).thenThrow(Exception());

    expect(
      () => controller.updateRequestUnits(requestId: 'r1', units: 1),
      throwsException,
    );
  });
});

// ================= FETCH =================
group('fetchRequests', () {
  test('success', () async {
    when(() => mockCloudFunctions.getRequestsByBloodBankId())
        .thenAnswer((_) async => {
              'requests': [
                {'id': 'r1', 'units': 2, 'isUrgent': true},
              ]
            });

    final result = await controller.fetchRequests();

    expect(result.length, 1);
  });

  test('returns empty when not list', () async {
    when(() => mockCloudFunctions.getRequestsByBloodBankId())
        .thenAnswer((_) async => {'requests': 'invalid'});

    final result = await controller.fetchRequests();

    expect(result, []);
  });

  test('skips invalid map entries', () async {
    when(() => mockCloudFunctions.getRequestsByBloodBankId())
        .thenAnswer((_) async => {
              'requests': ['bad', {'id': 'r1', 'units': 1}]
            });

    final result = await controller.fetchRequests();

    expect(result.length, 1);
  });

  test('throws on exception', () {
    when(() => mockCloudFunctions.getRequestsByBloodBankId())
        .thenThrow(Exception());

    expect(() => controller.fetchRequests(), throwsException);
  });
});

// ================= STATS =================
group('statistics', () {
  test('calculateStatistics basic', () {
    final requests = [
      BloodRequest.fromMap({'units': 2, 'isUrgent': true}, 'r1'),
      BloodRequest.fromMap({'units': 3, 'isUrgent': false}, 'r2'),
    ];

    final stats = controller.calculateStatistics(requests);

    expect(stats['totalUnits'], 5);
    expect(stats['urgentCount'], 1);
    expect(stats['normalCount'], 1);
  });

  test('accepted/rejected sums', () {
    final requests = [
      BloodRequest.fromMap({
        'units': 1,
        'acceptedCount': 2,
        'rejectedCount': 3,
      }, 'r1'),
    ];

    final stats = controller.calculateStatistics(requests);

    expect(stats['totalAccepted'], 2);
    expect(stats['totalRejected'], 3);
  });
});
}