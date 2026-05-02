import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bloodbank_donors/services/notification_service.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';

/// Mock class for CloudFunctionsService
/// نستخدمها بدل Cloud Functions الحقيقية أثناء الاختبار
class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

void main() {
  late MockCloudFunctionsService mockCloudFunctions;
  late NotificationService notificationService;

  setUp(() {
    
    mockCloudFunctions = MockCloudFunctionsService();

    notificationService = NotificationService.test(mockCloudFunctions);
  });

group('mark all as read', () {
  test('markAllAsRead() should call markNotificationsAsRead() once', () async {
   
    when(() => mockCloudFunctions.markNotificationsAsRead()).thenAnswer((_) async => {'ok': true});

    await notificationService.markAllAsRead();

    verify(() => mockCloudFunctions.markNotificationsAsRead()).called(1);
  });

  test('markAsRead() should call markNotificationAsRead() with correct id', () async {
    // Arrange
    const notificationId = 'notif_123';

    when(() => mockCloudFunctions.markNotificationAsRead(notificationId: notificationId,
        )).thenAnswer((_) async => {'ok': true});

    // Act
    await notificationService.markAsRead(notificationId);

    // Assert
    verify(() => mockCloudFunctions.markNotificationAsRead(notificationId: notificationId,)).called(1);
  });

test('markAllAsRead rethrows on failure', () async {
  when(() => mockCloudFunctions.markNotificationsAsRead())
      .thenThrow(Exception('fail'));

  expect(
    () => notificationService.markAllAsRead(),
    throwsException,
  );
});

test('markAsRead rethrows on failure', () async {
  when(() => mockCloudFunctions.markNotificationAsRead(
        notificationId: any(named: 'notificationId'),
      )).thenThrow(Exception());

  expect(
    () => notificationService.markAsRead('id'),
    throwsException,
  );
});

test('markAsRead completes successfully', () async {
  when(() => mockCloudFunctions.markNotificationAsRead(
        notificationId: any(named: 'notificationId'),
      )).thenAnswer((_) async => {'ok': true});

  await expectLater(
    notificationService.markAsRead('id'),
    completes,
  );
});

test('markAllAsRead completes successfully', () async {
  when(() => mockCloudFunctions.markNotificationsAsRead())
      .thenAnswer((_) async => {'ok': true});

  await expectLater(
    notificationService.markAllAsRead(),
    completes,
  );
});

test('markAllAsRead only calls correct method', () async {
  when(() => mockCloudFunctions.markNotificationsAsRead())
      .thenAnswer((_) async => {'ok': true});

  await notificationService.markAllAsRead();

  verify(() => mockCloudFunctions.markNotificationsAsRead()).called(1);
  verifyNoMoreInteractions(mockCloudFunctions);
});

});
  
group('delete Notification ', () {
  test('deleteNotification() should call deleteNotification() with correct id',() async {
    // Arrange
    const notificationId = 'notif_456';

    when(() => mockCloudFunctions.deleteNotification(notificationId: notificationId,
        )).thenAnswer((_) async => {'ok': true});

    // Act
    await notificationService.deleteNotification(notificationId);

    // Assert
    verify(() => mockCloudFunctions.deleteNotification(notificationId: notificationId,)).called(1);
  });

  test('deleteOldNotifications returns int when deletedCount is int', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((_) async => {'deletedCount': 5});

  final result = await notificationService.deleteOldNotifications();

  expect(result, 5);
});

  test('deleteOldNotifications converts num to int', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((_) async => {'deletedCount': 5.8});

  final result = await notificationService.deleteOldNotifications();

  expect(result, 5); // truncated
});

  test('deleteOldNotifications returns 0 when deletedCount is invalid', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((_) async => {'deletedCount': 'invalid'});

  final result = await notificationService.deleteOldNotifications();

  expect(result, 0);
});

  test('deleteOldNotifications returns 0 when deletedCount is missing', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((_) async => {});

  final result = await notificationService.deleteOldNotifications();

  expect(result, 0);
});

  test('deleteOldNotifications passes custom days parameter', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((invocation) async {
    expect(invocation.namedArguments[#days], 7);
    return {'deletedCount': 1};
  });

  await notificationService.deleteOldNotifications(days: 7);
});

  test('deleteOldNotifications rethrows on error', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenThrow(Exception('fail'));

  expect(
    () => notificationService.deleteOldNotifications(),
    throwsException,
  );
});

test('deleteNotification rethrows on failure', () async {
  when(() => mockCloudFunctions.deleteNotification(
        notificationId: any(named: 'notificationId'),
      )).thenThrow(Exception());

  expect(
    () => notificationService.deleteNotification('id'),
    throwsException,
  );
});

test('deleteOldNotifications handles negative days', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((_) async => {'deletedCount': 0});

  final result = await notificationService.deleteOldNotifications(days: -5);

  expect(result, 0);
});

test('deleteOldNotifications returns 0 when deletedCount is null', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((_) async => {'deletedCount': null});

  final result = await notificationService.deleteOldNotifications();

  expect(result, 0);
});

test('deleteOldNotifications handles negative count', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((_) async => {'deletedCount': -3});

  final result = await notificationService.deleteOldNotifications();

  expect(result, -3);
});

test('deleteOldNotifications uses default days = 30', () async {
  when(() => mockCloudFunctions.deleteOldNotifications(days: any(named: 'days')))
      .thenAnswer((invocation) async {
    expect(invocation.namedArguments[#days], 30);
    return {'deletedCount': 1};
  });

  await notificationService.deleteOldNotifications();
});


test('deleteNotification completes successfully', () async {
  when(() => mockCloudFunctions.deleteNotification(
        notificationId: any(named: 'notificationId'),
      )).thenAnswer((_) async => {'ok': true});

  await expectLater(
    notificationService.deleteNotification('id'),
    completes,
  );
});


});

}
