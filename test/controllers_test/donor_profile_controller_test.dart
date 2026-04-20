import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bloodbank_donors/controllers/donor_profile_controller.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';

// ---------------- Mocks ----------------
class MockCloudFunctionsService extends Mock
    implements CloudFunctionsService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  late DonorProfileController controller;
  late MockCloudFunctionsService mockCloud;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirestore mockFirestore;

  setUp(() {
    mockCloud = MockCloudFunctionsService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockFirestore = MockFirestore();

    controller = DonorProfileController(
      cloudFunctions: mockCloud,
      auth: mockAuth,
      firestore: mockFirestore,
    );
  });

group('fetchUserProfile', () {
  test('fetchUserProfile success', () async {
    when(() => mockCloud.getUserData()).thenAnswer((_) async => {
          'uid': 'u1',
          'email': 'test@test.com',
        });

    final result = await controller.fetchUserProfile();

    expect(result['uid'], 'u1');
  });

  test('fetchUserProfile throws on error', () {
    when(() => mockCloud.getUserData()).thenThrow(Exception());

    expect(() => controller.fetchUserProfile(), throwsException);
  });
});
  
group('updateProfileName', () {
  test('updateProfileName success', () async {
    when(() => mockCloud.updateUserProfile(name: any(named: 'name')))
        .thenAnswer((_) async => {'ok': true});

    final result = await controller.updateProfileName(name: 'Ali');

    expect(result['ok'], true);
  });

  test('updateProfileName throws', () {
    when(() => mockCloud.updateUserProfile(name: any(named: 'name')))
        .thenThrow(Exception());

    expect(
      () => controller.updateProfileName(name: 'Ali'),
      throwsException,
    );
  });
});

group('fetchDonationHistory', () {
    test('returns empty when user not logged in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final result = await controller.fetchDonationHistory();

      expect(result, []);
    });

    test('handles firestore failure and still processes feed', () async {
      // user موجود
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      // Firestore fails → يدخل catch
      when(() => mockFirestore.collection(any()))
          .thenThrow(Exception());

      // Cloud function
      when(() => mockCloud.getRequests(limit: any(named: 'limit')))
          .thenAnswer((_) async => {
                'requests': [
                  {
                    'id': 'r1',
                    'myResponse': 'accepted',
                    'isCompleted': false,
                    'units': 1,
                  },
                  {
                    'id': 'r2',
                    'myResponse': 'rejected',
                    'isCompleted': false,
                    'units': 1,
                  },
                  {
                    'id': 'r3',
                    'myResponse': 'accepted',
                    'isCompleted': true,
                    'units': 1,
                  },
                ]
              });

      final result = await controller.fetchDonationHistory();

      // لازم ياخذ فقط accepted + not completed
      expect(result.any((r) => r.requestId == 'r1'), true);
      expect(result.any((r) => r.requestId == 'r2'), false);
      expect(result.any((r) => r.requestId == 'r3'), false);
    });

    test('handles cloud function failure', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockFirestore.collection(any()))
          .thenThrow(Exception());

      when(() => mockCloud.getRequests(limit: any(named: 'limit')))
          .thenThrow(Exception());

      final result = await controller.fetchDonationHistory();

      expect(result, isA<List>());
    });

    test('no duplicates added', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockFirestore.collection(any()))
          .thenThrow(Exception());

      when(() => mockCloud.getRequests(limit: any(named: 'limit')))
          .thenAnswer((_) async => {
                'requests': [
                  {
                    'id': 'r1',
                    'myResponse': 'accepted',
                    'isCompleted': false,
                    'units': 1,
                  }
                ]
              });

      final result = await controller.fetchDonationHistory();

      final count =
          result.where((r) => r.requestId == 'r1').length;

      expect(count, 1);
    });
  });

}