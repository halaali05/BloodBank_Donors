import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/chat_controller.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/services/auth_service.dart';

// ------------------ Mocks ------------------
class MockCloudFunctionsService extends Mock
    implements CloudFunctionsService {}

class MockAuthService extends Mock implements AuthService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late MockCloudFunctionsService mockCloudFunctions;
  late MockAuthService mockAuthService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;

  late ChatController controller;

  setUp(() {
    mockCloudFunctions = MockCloudFunctionsService();
    mockAuthService = MockAuthService();
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();

    controller = ChatController(
      cloudFunctions: mockCloudFunctions,
      authService: mockAuthService,
      auth: mockFirebaseAuth,
    );
  });

  // --------------------------------------------------
  // formatTime
  // --------------------------------------------------
  test('formatTime returns "Just now" for recent time', () {
    final now = DateTime.now().subtract(const Duration(seconds: 30));

    final result = controller.formatTime(now);

    expect(result, 'Just now');
  });

  test('formatTime returns minutes ago', () {
    final time = DateTime.now().subtract(const Duration(minutes: 5));

    final result = controller.formatTime(time);

    expect(result, '5m ago');
  });

  test('formatTime returns hours ago', () {
    final time = DateTime.now().subtract(const Duration(hours: 2));

    final result = controller.formatTime(time);

    expect(result, '2h ago');
  });

  // --------------------------------------------------
  // formatTimeFromMillis
  // --------------------------------------------------
  test('formatTimeFromMillis formats correctly', () {
    final millis = DateTime.now()
        .subtract(const Duration(minutes: 10))
        .millisecondsSinceEpoch;

    final result = controller.formatTimeFromMillis(millis);

    expect(result, '10m ago');
  });

  test('formatTimeFromMillis returns empty for null', () {
    final result = controller.formatTimeFromMillis(null);

    expect(result, '');
  });

  // --------------------------------------------------
  // isMessageFromCurrentUser
  // --------------------------------------------------
  test('isMessageFromCurrentUser returns true when sender matches user', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    final message = {'senderId': 'u1'};

    final result = controller.isMessageFromCurrentUser(message);

    expect(result, true);
  });

  test('isMessageFromCurrentUser returns false when sender differs', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    final message = {'senderId': 'u2'};

    final result = controller.isMessageFromCurrentUser(message);

    expect(result, false);
  });

  test('isMessageFromCurrentUser returns false when user is null', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);

    final message = {'senderId': 'u1'};

    final result = controller.isMessageFromCurrentUser(message);

    expect(result, false);
  });

  // --------------------------------------------------
  // fetchMessages
  // --------------------------------------------------
  test('fetchMessages returns list of messages on success', () async {
    when(() => mockCloudFunctions.getMessages(
          requestId: any(named: 'requestId'),
          filterRecipientId: any(named: 'filterRecipientId'),
        )).thenAnswer(
      (_) async => {
        'messages': [
          {'text': 'Hello', 'senderId': 'u1'},
          {'text': 'Hi', 'senderId': 'u2'},
        ],
      },
    );

    final result = await controller.fetchMessages('r1');

    expect(result.length, 2);
    expect(result.first['text'], 'Hello');
  });

  // --------------------------------------------------
  // sendMessage
  // --------------------------------------------------
  test('sendMessage throws error when user not authenticated', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);

    expect(
      () => controller.sendMessage(
        requestId: 'r1',
        text: 'Hello',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('sendMessage calls cloud function successfully', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockCloudFunctions.sendMessage(
          requestId: any(named: 'requestId'),
          text: any(named: 'text'),
          recipientId: any(named: 'recipientId'),
        )).thenAnswer((_) async => {'ok': true});

    await controller.sendMessage(
      requestId: 'r1',
      text: 'Hello',
    );

    verify(() => mockCloudFunctions.sendMessage(
          requestId: 'r1',
          text: 'Hello',
          recipientId: null,
        )).called(1);
  });

  test('fetchMessages throws exception when service fails', () async {
  when(() => mockCloudFunctions.getMessages(
        requestId: any(named: 'requestId'),
        filterRecipientId: any(named: 'filterRecipientId'),
      )).thenThrow(Exception('Network error'));

  expect(
    () => controller.fetchMessages('r1'),
    throwsA(isA<Exception>()),
  );
});

test('sendMessage uses recipientId when provided', () async {
  when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('u1');

  when(() => mockCloudFunctions.sendMessage(
        requestId: any(named: 'requestId'),
        text: any(named: 'text'),
        recipientId: any(named: 'recipientId'),
      )).thenAnswer((_) async => {'ok': true});

  await controller.sendMessage(
    requestId: 'r1',
    text: 'Hello',
    recipientId: 'donor123',
  );

  verify(() => mockCloudFunctions.sendMessage(
        requestId: 'r1',
        text: 'Hello',
        recipientId: 'donor123',
      )).called(1);
});


test('sendMessage routes donor message to blood bank', () async {
  when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.uid).thenReturn('donor1');

  when(() => mockCloudFunctions.sendMessage(
        requestId: any(named: 'requestId'),
        text: any(named: 'text'),
        recipientId: any(named: 'recipientId'),
      )).thenAnswer((_) async => {'ok': true});

  await controller.sendMessage(
    requestId: 'r1',
    text: 'Hello',
    requestOwnerId: 'bank1',
    currentUserRole: 'donor',
  );

  verify(() => mockCloudFunctions.sendMessage(
        requestId: 'r1',
        text: 'Hello',
        recipientId: 'bank1',
      )).called(1);
});


}
