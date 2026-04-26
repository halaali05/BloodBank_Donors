import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/donor_dashboard_controller.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';
import 'package:bloodbank_donors/models/user_model.dart' as models;

// ---------------- Mocks ----------------
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  late DonorDashboardController controller;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockCloudFunctionsService mockCloud;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockCloud = MockCloudFunctionsService();
    mockAuthService = MockAuthService();

    controller = DonorDashboardController(
      auth: mockAuth,
      cloudFunctions: mockCloud,
      authService: mockAuthService,
    );
  });


group('Auth helpers', () {
  test('getCurrentUser returns user', () {
    when(() => mockAuth.currentUser).thenReturn(mockUser);

    final result = controller.getCurrentUser();

    expect(result, mockUser);
  });

  test('getCurrentUserId returns uid', () {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    final result = controller.getCurrentUserId();

    expect(result, 'u1');
  });

  test('getCurrentUserId returns null when no user', () {
    when(() => mockAuth.currentUser).thenReturn(null);

    final result = controller.getCurrentUserId();

    expect(result, null);
  });

  test('logout calls signOut', () async {
    when(() => mockAuth.signOut()).thenAnswer((_) async {});

    await controller.logout();

    verify(() => mockAuth.signOut()).called(1);
  });
});

 
group('calculateStatistics', () {
  test('calculateStatistics returns correct values', () {
    final requests = [
      BloodRequest.fromMap
      ({'id': 'r1', 
      'bloodType': 'A+',
      'units': 2,
      'isUrgent': true},
      'r1'),
      BloodRequest.fromMap
      ({'id': 'r2',
       'bloodType': 'O-', 
       'units': 3, 
       'isUrgent': false},
       'r2'),
      BloodRequest.fromMap
      ({'id': 'r3',
      'bloodType': 'B+', 
      'units': 1,
      'isUrgent': true},'r3'),
    ];

    final stats = controller.calculateStatistics(requests);

    expect(stats['totalCount'], 3);
    expect(stats['urgentCount'], 2);
    expect(stats['normalCount'], 1);
  });

  test('calculateStatistics empty list', () {
  final stats = controller.calculateStatistics([]);

  expect(stats['totalCount'], 0);
  expect(stats['urgentCount'], 0);
  expect(stats['normalCount'], 0);
});
});
  
group('extractDonorName', () {
  test('extractDonorName returns name from userData.name', () {
    final result = controller.extractDonorName(
      {'name': 'Ali'},
      null,
    );
    expect(result, 'Ali');
  });

  test('extractDonorName returns fullName if name empty', () {
    final result = controller.extractDonorName(
      {'name': '', 'fullName': 'Ahmad'},
      null,
    );
    expect(result, 'Ahmad');
  });

  test('extractDonorName returns auth displayName if userData empty', () {
    final result = controller.extractDonorName(
      {},
      'Khaled',
    );
    expect(result, 'Khaled');
  });

  test('extractDonorName returns default when all empty', () {
    final result = controller.extractDonorName(null, null);
    expect(result, 'Donor');
  });

test('extractDonorName trims values', () {
  final result = controller.extractDonorName(
    {'name': '   Ali   '},
    null,
  );

  expect(result, 'Ali');
});

test('extractDonorName uses fullName when name null', () {
  final result = controller.extractDonorName(
    {'fullName': 'Omar'},
    null,
  );

  expect(result, 'Omar');
});

test('extractDonorName trims authDisplayName', () {
  final result = controller.extractDonorName(
    null,
    '   Sami   ',
  );

  expect(result, 'Sami');
});
});

group('getUnreadNotificationsCount', () {
  test('getUnreadNotificationsCount counts unread notifications', () async {
    when(() => mockCloud.getNotifications()).thenAnswer((_) async => {
          'notifications': [
            {'read': false},
            {'read': true},
            {'isRead': false},
          ],
        });

    final count = await controller.getUnreadNotificationsCount();

    expect(count, 2);
  });

  test('getUnreadNotificationsCount returns 0 on error', () async {
    when(() => mockCloud.getNotifications())
        .thenThrow(Exception('Network error'));

    final count = await controller.getUnreadNotificationsCount();

    expect(count, 0);
  });

test('getUnreadNotificationsCount handles empty list', () async {
  when(() => mockCloud.getNotifications())
      .thenAnswer((_) async => {'notifications': []});

  final count = await controller.getUnreadNotificationsCount();

  expect(count, 0);
});

test('getUnreadNotificationsCount treats missing flags as unread', () async {
  when(() => mockCloud.getNotifications()).thenAnswer((_) async => {
        'notifications': [
          {}, // no read/isRead
        ],
      });

  final count = await controller.getUnreadNotificationsCount();

  expect(count, 1);
});
});

  
  group('fetchRequests', () {
  test('fetchRequests returns list of BloodRequest', () async {
    when(() => mockCloud.getRequests(limit: 100)).thenAnswer((_) async => {
          'requests': [
            {
              'id': 'r1',
              'bloodType': 'A+',
              'units': 2,
              'isUrgent': true,
            }
          ],
        });

    final result = await controller.fetchRequests();

    expect(result.length, 1);
    expect(result.first.id, 'r1');
  });

  test('fetchRequests throws exception on failure', () async {
    when(() => mockCloud.getRequests(limit: 100))
        .thenThrow(Exception('Server down'));

    expect(
      () => controller.fetchRequests(),
      throwsA(isA<Exception>()),
    );
  });

test('fetchRequests returns empty list when no data', () async {
  when(() => mockCloud.getRequests(limit: 100))
      .thenAnswer((_) async => {});

  final result = await controller.fetchRequests();

  expect(result, []);
});
  });
 
   group('fetchUserProfile', () {
  test('fetchUserProfile returns user data map', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockAuthService.getUserData('u1')).thenAnswer((_) async {
      return models.User(
        uid: 'u1',
        email: 'test@test.com',
        role: models.UserRole.donor,
        fullName: 'Ali',
        location: 'Amman',
      );
    });

    final result = await controller.fetchUserProfile();

    expect(result!['fullName'], 'Ali');
    expect(result['email'], 'test@test.com');
    expect(result['location'], 'Amman');
  });

  test('fetchUserProfile returns null when no user', () async {
    when(() => mockAuth.currentUser).thenReturn(null);

    final result = await controller.fetchUserProfile();

    expect(result, isNull);
  });


test('fetchUserProfile returns null when userData null', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockAuthService.getUserData('u1'))
      .thenAnswer((_) async => null);

  final result = await controller.fetchUserProfile();

  expect(result, null);
});

test('fetchUserProfile returns null on exception', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockAuthService.getUserData('u1'))
      .thenThrow(Exception());

  final result = await controller.fetchUserProfile();

  expect(result, null);
});

   });
group('submitDonorResponse', () {
    test('throws on invalid response', () {
    expect(
      () => controller.submitDonorResponse(
        requestId: 'r1',
        response: 'maybe',
      ),
      throwsException,
    );
  });
});


}
