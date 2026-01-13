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

  // --------------------------------------------------
  // calculateStatistics
  // --------------------------------------------------
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

  // --------------------------------------------------
  // extractDonorName
  // --------------------------------------------------
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

  // --------------------------------------------------
  // getUnreadNotificationsCount
  // --------------------------------------------------
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

  // --------------------------------------------------
  // fetchRequests
  // --------------------------------------------------
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

  // --------------------------------------------------
  // fetchUserProfile
  // --------------------------------------------------
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
}
