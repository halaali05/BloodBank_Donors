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
}
