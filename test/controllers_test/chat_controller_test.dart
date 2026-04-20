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

  // ================= SETUP =================
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

// ================= AUTH =================
group('Auth', () {
  test('getCurrentUser returns current user', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);

    final result = controller.getCurrentUser();

    expect(result, mockUser);
  });

  test('getUserRole success', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');
    when(() => mockAuthService.getUserRole('u1'))
        .thenAnswer((_) async => 'donor');

    final result = await controller.getUserRole();

    expect(result, 'donor');
  });

  test('getUserRole returns null when no user', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);

    final result = await controller.getUserRole();

    expect(result, null);
  });

  test('getUserRole returns null on exception', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');
    when(() => mockAuthService.getUserRole('u1'))
        .thenThrow(Exception());

    final result = await controller.getUserRole();

    expect(result, null);
  });
});

// ================= FORMAT =================
group('Time Formatting', () {
  test('Just now', () {
    final result =
        controller.formatTime(DateTime.now().subtract(Duration(seconds: 10)));
    expect(result, 'Just now');
  });

  test('minutes ago', () {
    final result =
        controller.formatTime(DateTime.now().subtract(Duration(minutes: 5)));
    expect(result, '5m ago');
  });

  test('hours ago', () {
    final result =
        controller.formatTime(DateTime.now().subtract(Duration(hours: 2)));
    expect(result, '2h ago');
  });

  test('old date', () {
    final result =
        controller.formatTime(DateTime.now().subtract(Duration(days: 2)));
    expect(result.contains(':'), true);
  });

  test('null date', () {
    expect(controller.formatTime(null), '');
  });

  test('formatTimeFromMillis null', () {
    expect(controller.formatTimeFromMillis(null), '');
  });
});

// ================= FETCH =================
group('fetchMessages', () {
  test('success', () async {
    when(() => mockCloudFunctions.getMessages(
          requestId: any(named: 'requestId'),
          filterRecipientId: any(named: 'filterRecipientId'),
        )).thenAnswer((_) async => {
          'messages': [
            {'senderId': 'u1'}
          ],
          'bloodBankId': 'bank1',
        });

    final result = await controller.fetchMessages('r1');

    expect(result.messages.length, 1);
  });

  test('throws exception', () {
    when(() => mockCloudFunctions.getMessages(
          requestId: any(named: 'requestId'),
          filterRecipientId: any(named: 'filterRecipientId'),
        )).thenThrow(Exception());

    expect(() => controller.fetchMessages('r1'), throwsException);
  });
});

// ================= SEND =================
group('sendMessage', () {
  test('user not authenticated', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);

    expect(
      () => controller.sendMessage(requestId: 'r1', text: 'Hi'),
      throwsException,
    );
  });

  test('normal send (broadcast)', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('bank1');

    when(() => mockCloudFunctions.sendMessage(
          requestId: any(named: 'requestId'),
          text: any(named: 'text'),
          recipientId: any(named: 'recipientId'),
        )).thenAnswer((_) async => <String, dynamic>{});

    await controller.sendMessage(
      requestId: 'r1',
      text: 'Hi',
      requestOwnerId: 'bank1',
    );

    verify(() => mockCloudFunctions.sendMessage(
          requestId: 'r1',
          text: 'Hi',
          recipientId: null,
        )).called(1);
  });

  test('recipient provided (trimmed)', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockCloudFunctions.sendMessage(
          requestId: any(named: 'requestId'),
          text: any(named: 'text'),
          recipientId: any(named: 'recipientId'),
        )).thenAnswer((_) async => <String, dynamic>{});

    await controller.sendMessage(
      requestId: 'r1',
      text: 'Hi',
      recipientId: '   u2   ',
    );

    verify(() => mockCloudFunctions.sendMessage(
          requestId: 'r1',
          text: 'Hi',
          recipientId: 'u2',
        )).called(1);
  });

  test('donor sends to bank', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('donor1');

    when(() => mockCloudFunctions.sendMessage(
          requestId: any(named: 'requestId'),
          text: any(named: 'text'),
          recipientId: any(named: 'recipientId'),
        )).thenAnswer((_) async => <String, dynamic>{});

    await controller.sendMessage(
      requestId: 'r1',
      text: 'Hi',
      requestOwnerId: 'bank1',
    );

    verify(() => mockCloudFunctions.sendMessage(
          requestId: 'r1',
          text: 'Hi',
          recipientId: 'bank1',
        )).called(1);
  });

  test('cloud function fails', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockCloudFunctions.sendMessage(
          requestId: any(named: 'requestId'),
          text: any(named: 'text'),
          recipientId: any(named: 'recipientId'),
        )).thenThrow(Exception());

    expect(
      () => controller.sendMessage(requestId: 'r1', text: 'Hi'),
      throwsException,
    );
  });
});

// ================= PARTICIPANTS =================
group('participants', () {
  test('getChatParticipants', () async {
    when(() => mockCloudFunctions.getMessages(
          requestId: any(named: 'requestId'),
          filterRecipientId: any(named: 'filterRecipientId'),
        )).thenAnswer((_) async => {
          'messages': [
            {'senderId': 'u1'},
            {'senderId': 'u2'},
            {'senderId': 'bank1'},
          ],
          'bloodBankId': 'bank1',
        });

    final result = await controller.getChatParticipants('r1');

    expect(result.contains('u1'), true);
    expect(result.contains('bank1'), false);
  });

  test('getUnreadCountPerUser', () async {
    when(() => mockCloudFunctions.getMessages(
          requestId: any(named: 'requestId'),
          filterRecipientId: any(named: 'filterRecipientId'),
        )).thenAnswer((_) async => {
          'messages': [
            {'senderId': 'u1', 'recipientId': 'bank1'},
            {'senderId': 'u1', 'recipientId': 'bank1'},
            {'senderId': 'u2', 'recipientId': 'bank1'},
          ],
          'bloodBankId': 'bank1',
        });

    final result = await controller.getUnreadCountPerUser('r1');

    expect(result['u1'], 2);
    expect(result['u2'], 1);
  });
});
}
