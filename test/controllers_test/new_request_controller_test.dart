import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/new_request_controller.dart';
import 'package:bloodbank_donors/services/requests_service.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';

// ---------------- Mocks ----------------

class MockRequestsService extends Mock implements RequestsService {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

class FakeBloodRequest extends Fake implements BloodRequest {}

void main() {
  late NewRequestController controller;
  late MockRequestsService mockRequestsService;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(FakeBloodRequest());
  });

  setUp(() {
    mockRequestsService = MockRequestsService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    controller = NewRequestController(
      requestsService: mockRequestsService,
      auth: mockAuth,
    );
  });

  // =====================================================
  // validateLocation
  // =====================================================

  test('validateLocation returns error when location is null', () {
    final result = controller.validateLocation(null);
    expect(result, 'Please select hospital location');
  });

  test('validateLocation returns error when location is empty', () {
    final result = controller.validateLocation('');
    expect(result, 'Please select hospital location');
  });

  test('validateLocation returns null when location is valid', () {
    final result = controller.validateLocation('Amman');
    expect(result, null);
  });

  // =====================================================
  // validateRequest
  // =====================================================

  test('validateRequest returns location error when location missing', () {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    final result = controller.validateRequest(hospitalLocation: null);
    expect(result, 'Please select hospital location');
  });

  // =====================================================
  // createRequest - validation failures
  // =====================================================

  test('createRequest returns error when location missing', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    final result = await controller.createRequest(
      bloodBankName: 'Jordan Hospital',
      bloodType: 'A+',
      units: 2,
      isUrgent: true,
      hospitalLocation: '',
    );

    expect(result['success'], false);
    expect(result['errorMessage'], 'Please select hospital location');
  });

  // =====================================================
  // createRequest - success
  // =====================================================

  test('createRequest succeeds when all data valid', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockRequestsService.addRequest(any()))
        .thenAnswer((_) async {});

    final result = await controller.createRequest(
      bloodBankName: 'Jordan Hospital',
      bloodType: 'A+',
      units: 3,
      isUrgent: true,
      hospitalLocation: 'Amman',
      details: 'Emergency case',
    );

    expect(result['success'], true);

    verify(() => mockRequestsService.addRequest(any())).called(1);
  });

  // =====================================================
  // Error handling
  // =====================================================

  test('createRequest handles permission error correctly', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockRequestsService.addRequest(any()))
        .thenThrow(Exception('permission-denied'));

    final result = await controller.createRequest(
      bloodBankName: 'Jordan Hospital',
      bloodType: 'A+',
      units: 1,
      isUrgent: false,
      hospitalLocation: 'Amman',
    );

    expect(result['success'], false);
    expect(
      result['errorMessage'],
      'You do not have permission to create requests. Only hospitals can create requests.',
    );
  });

  test('createRequest handles invalid argument error correctly', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockRequestsService.addRequest(any()))
        .thenThrow(Exception('invalid-argument'));

    final result = await controller.createRequest(
      bloodBankName: 'Jordan Hospital',
      bloodType: 'A+',
      units: 1,
      isUrgent: false,
      hospitalLocation: 'Amman',
    );

    expect(result['success'], false);
    expect(result['errorMessage'],
      'Please check your request details and try again.',
    );
  });

  test('createRequest handles network error correctly', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockRequestsService.addRequest(any()))
        .thenThrow(Exception('network timeout'));

    final result = await controller.createRequest(
      bloodBankName: 'Jordan Hospital',
      bloodType: 'A+',
      units: 1,
      isUrgent: false,
      hospitalLocation: 'Amman',
    );

    expect(result['success'], false);
    expect(result['errorMessage'],
      'Network error. Please check your internet connection and try again.',
    );
  });

  test('createRequest handles server error correctly', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockRequestsService.addRequest(any()))
        .thenThrow(Exception('internal server error'));

    final result = await controller.createRequest(
      bloodBankName: 'Jordan Hospital',
      bloodType: 'A+',
      units: 1,
      isUrgent: false,
      hospitalLocation: 'Amman',
    );

    expect(result['success'], false);
    expect(
      result['errorMessage'],
      'Server error occurred. Please try again later.',
    );
  });

  test('createRequest handles unknown error correctly', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');

    when(() => mockRequestsService.addRequest(any()))
        .thenThrow(Exception('Failed to create request. Please try again.'));

    final result = await controller.createRequest(
      bloodBankName: 'Jordan Hospital',
      bloodType: 'A+',
      units: 1,
      isUrgent: false,
      hospitalLocation: 'Amman',
    );

    expect(result['success'], false);
    expect(result['errorMessage'], contains('Failed to create request. Please try again.'));
  });
}
