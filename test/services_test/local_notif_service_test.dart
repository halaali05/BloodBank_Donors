import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:bloodbank_donors/services/local_notif_service.dart';

// ================= MOCKS =================

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

// ================= FAKES =================

class FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class FakeAndroidNotificationChannel extends Fake
    implements AndroidNotificationChannel {}

class FakeNotificationDetails extends Fake
    implements NotificationDetails {}

void main() {
  late MockPlugin mockPlugin;
  late MockAndroidPlugin mockAndroid;
  late LocalNotifService service;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(FakeAndroidNotificationChannel());
    registerFallbackValue(FakeNotificationDetails());
  });

  setUp(() {
    mockPlugin = MockPlugin();
    mockAndroid = MockAndroidPlugin();
    service = LocalNotifService.test(mockPlugin);
  });

  // =========================================================
  // INIT
  // =========================================================

  group('init()', () {
    test('initializes successfully', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);

      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroid);

      when(() => mockAndroid.requestNotificationsPermission())
          .thenAnswer((_) async => true);

      when(() => mockAndroid.createNotificationChannel(any()))
          .thenAnswer((_) async {});

      await service.init();

      verify(() => mockAndroid.createNotificationChannel(any())).called(2);
    });

    test('does not reinitialize if already initialized', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);

      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroid);

      when(() => mockAndroid.requestNotificationsPermission())
          .thenAnswer((_) async => true);

      when(() => mockAndroid.createNotificationChannel(any()))
          .thenAnswer((_) async {});

      await service.init();

      clearInteractions(mockPlugin);
      clearInteractions(mockAndroid);

      await service.init();

      verifyNever(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          ));
    });

    test('works when android plugin is null', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);

      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      await service.init();
    });

    test('continues if permission request fails', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);

      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroid);

      when(() => mockAndroid.requestNotificationsPermission())
          .thenThrow(Exception());

      when(() => mockAndroid.createNotificationChannel(any()))
          .thenAnswer((_) async {});

      await service.init();
    });

    test('rethrows on failure', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenThrow(Exception());

      expect(() => service.init(), throwsException);
    });

    test('notification click callback executes safely', () async {
  late Function(NotificationResponse) callback;

  when(() => mockPlugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse:
            any(named: 'onDidReceiveNotificationResponse'),
      )).thenAnswer((invocation) async {
    callback =
        invocation.namedArguments[#onDidReceiveNotificationResponse];
    return true;
  });

  when(() => mockPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>())
      .thenReturn(mockAndroid);

  when(() => mockAndroid.createNotificationChannel(any()))
      .thenAnswer((_) async {});

  await service.init();

  final response = NotificationResponse(
    notificationResponseType: NotificationResponseType.selectedNotification,
    payload: '{"requestId":"123"}',
  );

  expect(() => callback(response), returnsNormally);
}); });

  // =========================================================
  // SHOW
  // =========================================================

  group('show()', () {
    setUp(() {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);

      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroid);

      when(() => mockAndroid.requestNotificationsPermission())
          .thenAnswer((_) async => true);

      when(() => mockAndroid.createNotificationChannel(any()))
          .thenAnswer((_) async {});

      when(() => mockPlugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});
    });

    test('calls init automatically', () async {
      await service.show(title: 't', body: 'b');

      verify(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).called(1);
    });

    test('sends normal notification', () async {
      await service.show(title: 'Test', body: 'Body');

      verify(() => mockPlugin.show(
            id: any(named: 'id'),
            title: 'Test',
            body: 'Body',
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('sends urgent notification', () async {
      await service.show(title: 'Urgent', body: 'Body', isUrgent: true);

      verify(() => mockPlugin.show(
            id: any(named: 'id'),
            title: 'Urgent',
            body: 'Body',
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('handles null payload', () async {
      await service.show(title: 't', body: 'b', payload: null);

      verify(() => mockPlugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: null,
          )).called(1);
    });

    test('handles empty payload', () async {
      await service.show(title: 't', body: 'b', payload: '');

      verify(() => mockPlugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: '',
          )).called(1);
    });

    test('passes payload correctly', () async {
      String? captured;

      when(() => mockPlugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          )).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#payload];
      });

      await service.show(title: 't', body: 'b', payload: '123');

      expect(captured, '123');
    });
  });
}