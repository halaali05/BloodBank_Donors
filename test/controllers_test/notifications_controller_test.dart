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

  group('Auth', () {
    test('getCurrentUser returns current user', () {
      final user = MockUser();
      when(() => mockAuth.currentUser).thenReturn(user);

      expect(controller.getCurrentUser(), user);
    });

    test('getCurrentUser returns null when no user', () {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(controller.getCurrentUser(), null);
    });
  });

  group('fetchNotifications', () {
    test('returns list on success', () async {
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
    });

    test('returns empty when no notifications key', () async {
      when(() => mockCloud.getNotifications())
          .thenAnswer((_) async => {});

      final result = await controller.fetchNotifications();

      expect(result, []);
    });

    test('throws on failure', () {
      when(() => mockCloud.getNotifications())
          .thenThrow(Exception());

      expect(
        () => controller.fetchNotifications(),
        throwsException,
      );
    });
  });

  
  group('Notification operations', () {
    test('markAllAsRead success', () async {
      when(() => mockNotifService.markAllAsRead())
          .thenAnswer((_) async {});

      await controller.markAllAsRead();

      verify(() => mockNotifService.markAllAsRead()).called(1);
    });

    test('markAllAsRead throws', () {
      when(() => mockNotifService.markAllAsRead())
          .thenThrow(Exception());

      expect(() => controller.markAllAsRead(), throwsException);
    });

    test('markAsRead success', () async {
      when(() => mockNotifService.markAsRead(any()))
          .thenAnswer((_) async {});

      await controller.markAsRead('n1');

      verify(() => mockNotifService.markAsRead('n1')).called(1);
    });

    test('markAsRead throws', () {
      when(() => mockNotifService.markAsRead(any()))
          .thenThrow(Exception());

      expect(() => controller.markAsRead('n1'), throwsException);
    });

    test('deleteNotification success', () async {
      when(() => mockNotifService.deleteNotification(any()))
          .thenAnswer((_) async {});

      await controller.deleteNotification('n1');

      verify(() => mockNotifService.deleteNotification('n1')).called(1);
    });

    test('deleteNotification throws', () {
      when(() => mockNotifService.deleteNotification(any()))
          .thenThrow(Exception());

      expect(
        () => controller.deleteNotification('n1'),
        throwsException,
      );
    });

    test('deleteOldNotifications success', () async {
      when(() => mockNotifService.deleteOldNotifications(
            days: any(named: 'days'),
          )).thenAnswer((_) async => 5);

      final result = await controller.deleteOldNotifications(days: 10);

      expect(result, 5);
    });

    test('deleteOldNotifications throws', () {
      when(() => mockNotifService.deleteOldNotifications(
            days: any(named: 'days'),
          )).thenThrow(Exception());

      expect(
        () => controller.deleteOldNotifications(),
        throwsException,
      );
    });
  });


  group('getUnreadNotifications', () {
    test('filters unread correctly', () {
      final input = [
        {'read': false},
        {'read': true},
        {'isRead': false},
      ];

      final result = controller.getUnreadNotifications(input);

      expect(result.length, 2);
    });

    test('returns empty when all read', () {
      final input = [
        {'read': true},
        {'isRead': true},
      ];

      expect(controller.getUnreadNotifications(input), []);
    });

    test('handles empty list', () {
      expect(controller.getUnreadNotifications([]), []);
    });

    test('treats missing flags as unread', () {
      final input = [
        {'id': 'n1'}, // no read/isRead
      ];

      final result = controller.getUnreadNotifications(input);

      expect(result.length, 1);
    });
  });

  
  group('formatTime', () {
    testWidgets('returns empty for null', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Container()));
      final context = tester.element(find.byType(Container));

      final result = controller.formatTime(context, null);

      expect(result, '');
    });

    testWidgets('returns Today', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Container()));
      final context = tester.element(find.byType(Container));

      final now = DateTime.now().millisecondsSinceEpoch;

      final result = controller.formatTime(context, now);

      expect(result.contains('Today'), true);
    });

    testWidgets('returns Yesterday', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Container()));
      final context = tester.element(find.byType(Container));

      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;

      final result = controller.formatTime(context, yesterday);

      expect(result.contains('Yesterday'), true);
    });

    testWidgets('returns date for old timestamps', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Container()));
      final context = tester.element(find.byType(Container));

      final old = DateTime.now()
          .subtract(const Duration(days: 5))
          .millisecondsSinceEpoch;

      final result = controller.formatTime(context, old);

      expect(result.contains('/'), true);
    });
  });
}