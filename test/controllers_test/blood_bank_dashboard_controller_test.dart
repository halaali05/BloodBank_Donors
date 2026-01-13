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

  setUp(() {
    mockCloudFunctions = MockCloudFunctionsService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('user_123');

    controller = BloodBankDashboardController(
      cloudFunctions: mockCloudFunctions,
      auth: mockAuth,
    );
  });

  // --------------------------------------------------
  group('BloodBankDashboardController - Unit Tests', () {
    // ---------------- Authentication ----------------

    test('getCurrentUserId returns current user uid', () {
      final uid = controller.getCurrentUserId();
      expect(uid, 'user_123');
    });

    test('verifyRequestOwnership returns true when owner matches', () {
      final result = controller.verifyRequestOwnership('user_123');
      expect(result, true);
    });

    test('verifyRequestOwnership returns false when owner does not match', () {
      final result = controller.verifyRequestOwnership('another_user');
      expect(result, false);
    });

    // ---------------- Delete Request ----------------

    test('deleteRequest calls cloud function and returns result', () async {
      when(() => mockCloudFunctions.deleteRequest(requestId: 'r1')).thenAnswer((_) async => {'ok': true, 'message': 'Deleted'});

      final result = await controller.deleteRequest(requestId: 'r1');

      expect(result['ok'], true);
      expect(result['message'], 'Deleted');

      verify(() => mockCloudFunctions.deleteRequest(requestId: 'r1')).called(1);
    });

    test('deleteRequest throws exception if requestId is empty', () async {

      expect(() => controller.deleteRequest(requestId: ''),throwsA(isA<Exception>()),);

    });

    // ---------------- Fetch Requests ----------------

    test('fetchRequests returns list of BloodRequest', () async {
      when(() => mockCloudFunctions.getRequestsByBloodBankId())
          .thenAnswer((_) async => {
                'requests': [
                  {
                    'id': 'r1',
                    'bloodType': 'A+',
                    'units': 2,
                    'isUrgent': true,
                  },
                  {
                    'id': 'r2',
                    'bloodType': 'O-',
                    'units': 3,
                    'isUrgent': false,
                  },
                ]
              });

      final result = await controller.fetchRequests();

      expect(result.length, 2);
      expect(result.first, isA<BloodRequest>());
      expect(result.first.units, 2);
      expect(result.first.isUrgent, true);
    });

    // ---------------- Statistics ----------------

   test('calculateStatistics returns correct values', () {
  final requests = [
    BloodRequest.fromMap({
      'id': 'r1',
      'bloodType': 'A+',
      'units': 2,
      'isUrgent': true,
    }, 'r1'),
    BloodRequest.fromMap({
      'id': 'r2',
      'bloodType': 'O-',
      'units': 3,
      'isUrgent': false,
    }, 'r2'),
    BloodRequest.fromMap({
      'id': 'r3',
      'bloodType': 'B+',
      'units': 1,
      'isUrgent': true,
    }, 'r3'),
  ];

  final stats = controller.calculateStatistics(requests);

  expect(stats['totalUnits'], 6);     
  expect(stats['activeCount'], 3);    
  expect(stats['urgentCount'], 2);    
  expect(stats['normalCount'], 1);    
});

test('verifyRequestOwnership returns true when ids match', () {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  final result = controller.verifyRequestOwnership('u1');
  expect(result, true);
});


  });
}
