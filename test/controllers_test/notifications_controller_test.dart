import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/notifications_controller.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/services/notification_service.dart';

// ---------------- Mocks ----------------
class MockCloudFunctionsService extends Mock
    implements CloudFunctionsService {}

class MockNotificationService extends Mock
    implements NotificationService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class FakeBuildContext extends Fake implements BuildContext {}

void main() {
  late MockCloudFunctionsService mockCloud;
  late MockNotificationService mockNotifService;
  late MockFirebaseAuth mockAuth;
  late NotificationsController controller;

  setUp(() {
    mockCloud = MockCloudFunctionsService();
    mockNotifService = MockNotificationService();
    mockAuth = MockFirebaseAuth();

    controller = NotificationsController(
      cloudFunctions: mockCloud,
      notificationService: mockNotifService,
      auth: mockAuth,
    );
  });

  // =====================================================
  // getCurrentUser
  // =====================================================

  test('getCurrentUser returns current user', () {
    final user = MockUser();
    when(() => mockAuth.currentUser).thenReturn(user);

    final result = controller.getCurrentUser();

    expect(result, user);
  });

  // =====================================================
  // fetchNotifications
  // =====================================================

  test('fetchNotifications returns list on success', () async {
    when(() => mockCloud.getNotifications()).thenAnswer(
      (_) async => {
        'notifications': [
          {'id': 'n1', 'read': false},
          {'id': 'n2', 'read': true},
        ],
      },
    );

    final result = await controller.fetchNotifications();

    expect(result.length, 2);
    expect(result.first['id'], 'n1');
  });

  test('fetchNotifications throws exception on failure', () async {
    when(() => mockCloud.getNotifications())
        .thenThrow(Exception('network error'));

    expect(
      () => controller.fetchNotifications(),
      throwsA(isA<Exception>()),
    );
  });

  // =====================================================
  // markAllAsRead
  // =====================================================

  test('markAllAsRead completes successfully', () async {
    when(() => mockNotifService.markAllAsRead())
        .thenAnswer((_) async {});

    await controller.markAllAsRead();

    verify(() => mockNotifService.markAllAsRead()).called(1);
  });

  test('markAllAsRead throws on error', () async {
    when(() => mockNotifService.markAllAsRead())
        .thenThrow(Exception('fail'));

    expect(
      () => controller.markAllAsRead(),
      throwsA(isA<Exception>()),
    );
  });

  // =====================================================
  // markAsRead
  // =====================================================

  test('markAsRead completes successfully', () async {
    when(() => mockNotifService.markAsRead(any()))
        .thenAnswer((_) async {});

    await controller.markAsRead('n1');

    verify(() => mockNotifService.markAsRead('n1')).called(1);
  });

  test('markAsRead throws on error', () async {
    when(() => mockNotifService.markAsRead(any()))
        .thenThrow(Exception('fail'));

    expect(
      () => controller.markAsRead('n1'),
      throwsA(isA<Exception>()),
    );
  });

  // =====================================================
  // deleteNotification
  // =====================================================

  test('deleteNotification completes successfully', () async {
    when(() => mockNotifService.deleteNotification(any()))
        .thenAnswer((_) async {});

    await controller.deleteNotification('n1');

    verify(() => mockNotifService.deleteNotification('n1')).called(1);
  });

  test('deleteNotification throws on error', () async {
    when(() => mockNotifService.deleteNotification(any()))
        .thenThrow(Exception('fail'));

    expect(
      () => controller.deleteNotification('n1'),
      throwsA(isA<Exception>()),
    );
  });

  // =====================================================
  // getUnreadNotifications
  // =====================================================

  test('getUnreadNotifications filters unread correctly', () {
    final input = [
      {'id': 'n1', 'read': false},
      {'id': 'n2', 'read': true},
      {'id': 'n3', 'isRead': false},
    ];

    final result = controller.getUnreadNotifications(input);

    expect(result.length, 2);
    expect(result.any((n) => n['id'] == 'n1'), true);
    expect(result.any((n) => n['id'] == 'n3'), true);
  });


}
