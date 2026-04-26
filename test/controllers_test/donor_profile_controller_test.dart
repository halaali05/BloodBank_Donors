import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/donor_profile_controller.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';

// ---------------- Mocks ----------------
class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late DonorProfileController controller;
  late MockCloudFunctionsService mockCloud;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockCloud = MockCloudFunctionsService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    controller = DonorProfileController(
      cloudFunctions: mockCloud,
      auth: mockAuth,
    );
  });

  group('fetchUserProfile', () {
    test('fetchUserProfile success', () async {
      when(
        () => mockCloud.getUserData(),
      ).thenAnswer((_) async => {'uid': 'u1', 'email': 'test@test.com'});

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
      when(
        () => mockCloud.updateUserProfile(name: any(named: 'name')),
      ).thenAnswer((_) async => {'ok': true});

      final result = await controller.updateProfileName(name: 'Ali');

      expect(result['ok'], true);
    });

    test('updateProfileName throws', () {
      when(
        () => mockCloud.updateUserProfile(name: any(named: 'name')),
      ).thenThrow(Exception());

      expect(() => controller.updateProfileName(name: 'Ali'), throwsException);
    });
  });

  group('fetchDonationHistory', () {
    test('returns empty when user not logged in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final result = await controller.fetchDonationHistory();

      expect(result, []);
    });

    test('returns reports from donation history callable', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockCloud.getDonationHistory()).thenAnswer(
        (_) async => {
          'reports': [
            {
              'id': 'r1',
              'requestId': 'request-1',
              'bloodBankId': 'bank-1',
              'bloodBankName': 'Bank 1',
              'bloodType': 'A+',
              'isUrgent': false,
              'status': 'donated',
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
            {
              'id': 'r2',
              'requestId': 'request-2',
              'bloodBankId': 'bank-2',
              'bloodBankName': 'Bank 2',
              'bloodType': 'O-',
              'isUrgent': true,
              'status': 'scheduled',
              'createdAt': '2026-01-02T00:00:00.000Z',
            },
          ],
        },
      );
      when(
        () => mockCloud.getRequests(limit: any(named: 'limit')),
      ).thenAnswer((_) async => {'requests': [], 'hasMore': false});

      final result = await controller.fetchDonationHistory();

      expect(result.map((r) => r.requestId), ['request-2', 'request-1']);
      verify(() => mockCloud.getDonationHistory()).called(1);
    });

    test('handles cloud function failure', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockCloud.getDonationHistory()).thenThrow(Exception());
      when(
        () => mockCloud.getRequests(limit: any(named: 'limit')),
      ).thenAnswer((_) async => {'requests': [], 'hasMore': false});

      final result = await controller.fetchDonationHistory();

      expect(result, isA<List>());
    });

    test('empty reports payload returns empty list', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(
        () => mockCloud.getDonationHistory(),
      ).thenAnswer((_) async => {'reports': []});
      when(
        () => mockCloud.getRequests(limit: any(named: 'limit')),
      ).thenAnswer((_) async => {'requests': [], 'hasMore': false});

      final result = await controller.fetchDonationHistory();

      expect(result, isEmpty);
    });

    test('adds active accepted request progress from requests callable',
      () async {
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn('u1');

        when(
          () => mockCloud.getDonationHistory(),
        ).thenAnswer((_) async => {'reports': []});
        when(
          () => mockCloud.getRequests(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => {
            'requests': [
              {
                'id': 'active-request',
                'bloodBankId': 'bank-1',
                'bloodBankName': 'Bank 1',
                'bloodType': 'A+',
                'units': 1,
                'isUrgent': false,
                'myResponse': 'accepted',
                'isCompleted': false,
                'createdAt': 1767225600000,
              },
            ],
            'hasMore': false,
          },
        );

        final result = await controller.fetchDonationHistory();

        expect(result.single.requestId, 'active-request');
        expect(result.single.reportFileUrl, isNull);
      },
    );
  
  test('fetchDonationHistory without active progress', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockCloud.getDonationHistory(
        includeActiveProgress: false,
      )).thenAnswer((_) async => {
        'reports': [],
      });

  final result = await controller.fetchDonationHistory(
    includeActiveProgress: false,
  );

  verify(() => mockCloud.getDonationHistory(
        includeActiveProgress: false,
      )).called(1);

  expect(result, isEmpty);
});

test('fetchDonationHistory rethrows when includeActiveProgress = false', () {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockCloud.getDonationHistory(
        includeActiveProgress: false,
      )).thenThrow(Exception());

  expect(
    () => controller.fetchDonationHistory(
      includeActiveProgress: false,
    ),
    throwsException,
  );
});

  });

  group('_waitForCurrentUser (indirect)', () {
  test('waits for authStateChanges when currentUser is null', () async {
    when(() => mockAuth.currentUser).thenReturn(null);

    // stream يرجع user
    when(() => mockAuth.authStateChanges()).thenAnswer(
      (_) => Stream.value(mockUser),
    );
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockCloud.getDonationHistory())
        .thenAnswer((_) async => {'reports': []});
    when(() => mockCloud.getRequests(limit: any(named: 'limit')))
        .thenAnswer((_) async => {'requests': []});

    final result = await controller.fetchDonationHistory();

    expect(result, isA<List>());
  });

  test('waitForCurrentUser timeout returns currentUser fallback', () async {
  when(() => mockAuth.currentUser).thenReturn(null);

  // stream ما برجع user → يعمل timeout
  when(() => mockAuth.authStateChanges())
      .thenAnswer((_) => const Stream<User?>.empty());

  when(() => mockCloud.getDonationHistory())
      .thenAnswer((_) async => {'reports': []});
  when(() => mockCloud.getRequests(limit: any(named: 'limit')))
      .thenAnswer((_) async => {'requests': []});

  final result = await controller.fetchDonationHistory();

  expect(result, isA<List>());
});

});

group('mergeActiveDonationProgress', () {
test('mergeActiveDonationProgress ignores non-accepted', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockCloud.getDonationHistory())
      .thenAnswer((_) async => {'reports': []});

  when(() => mockCloud.getRequests(limit: any(named: 'limit')))
      .thenAnswer((_) async => {
            'requests': [
              {
                'id': 'r1',
                'myResponse': 'rejected', // ignored
                'isCompleted': false,
              }
            ]
          });

  final result = await controller.fetchDonationHistory();

  expect(result, isEmpty);
});

test('mergeActiveDonationProgress ignores completed requests', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockCloud.getDonationHistory())
      .thenAnswer((_) async => {'reports': []});

  when(() => mockCloud.getRequests(limit: any(named: 'limit')))
      .thenAnswer((_) async => {
            'requests': [
              {
                'id': 'r1',
                'myResponse': 'accepted',
                'isCompleted': true, // ignored
              }
            ]
          });

  final result = await controller.fetchDonationHistory();

  expect(result, isEmpty);
});

test('mergeActiveDonationProgress ignores duplicate requestIds', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockCloud.getDonationHistory()).thenAnswer(
    (_) async => {
      'reports': [
        {
          'id': 'r1',
          'requestId': 'same-id',
          'bloodBankId': 'b',
          'bloodBankName': 'Bank',
          'bloodType': 'A+',
          'isUrgent': false,
          'status': 'donated',
          'createdAt': '2026-01-01T00:00:00.000Z',
        }
      ]
    },
  );

  when(() => mockCloud.getRequests(limit: any(named: 'limit')))
      .thenAnswer((_) async => {
            'requests': [
              {
                'id': 'same-id', // duplicate
                'myResponse': 'accepted',
                'isCompleted': false,
              }
            ]
          });

  final result = await controller.fetchDonationHistory();

  expect(result.length, 1);
});
});

test('reports are sorted by createdAt descending', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockCloud.getDonationHistory()).thenAnswer(
    (_) async => {
      'reports': [
        {
          'id': 'r1',
          'requestId': 'r1',
          'bloodBankId': 'b',
          'bloodBankName': 'Bank',
          'bloodType': 'A+',
          'isUrgent': false,
          'status': 'donated',
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
        {
          'id': 'r2',
          'requestId': 'r2',
          'bloodBankId': 'b',
          'bloodBankName': 'Bank',
          'bloodType': 'A+',
          'isUrgent': false,
          'status': 'donated',
          'createdAt': '2026-02-01T00:00:00.000Z',
        },
      ]
    },
  );

  when(() => mockCloud.getRequests(limit: any(named: 'limit')))
      .thenAnswer((_) async => {'requests': []});

  final result = await controller.fetchDonationHistory();

  expect(result.first.requestId, 'r2');
});



}
