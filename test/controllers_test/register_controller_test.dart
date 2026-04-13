import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/register_controller.dart';
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/models/register_models.dart';

// -------------------- Mocks --------------------
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuth;
  late RegisterController controller;

  setUp(() {
    mockAuth = MockAuthService();
    controller = RegisterController(authService: mockAuth);
  });

  // =========================================================
  // EMAIL VALIDATION
  // =========================================================

  test('isValidEmail returns true for valid email', () {
    expect(controller.isValidEmail('a@test.com'), true);
  });

  test('isValidEmail returns false for invalid email', () {
    expect(controller.isValidEmail('invalid-email'), false);
  });

  // =========================================================
  // FORM VALIDATION
  // =========================================================

  test('validateForm returns error when email or password empty', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: '',
      password: '',
      confirmPassword: '',
      name: '',
      location: '',
    );

    expect(result, 'Please enter both email and password.');
  });

  test('validateForm returns error for invalid email', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: 'bad',
      password: '123456',
      confirmPassword: '123456',
      name: 'Ali',
      location: 'Amman',
    );

    expect(result, 'Please enter a valid email address.');
  });

  test('validateForm returns error for short password', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123',
      confirmPassword: '123',
      name: 'Ali',
      location: 'Amman',
    );

    expect(result, 'Password must be at least 6 characters.');
  });

  test('validateForm returns error when passwords do not match', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      confirmPassword: '654321',
      name: 'Ali',
      location: 'Amman',
    );

    expect(result, 'The passwords do not match. Please try again.');
  });

  test('validateForm returns error when donor name missing', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      confirmPassword: '123456',
      name: '',
      location: 'Amman',
    );

    expect(result, 'Please enter your full name.');
  });

  test('validateForm returns error when donor location missing', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      confirmPassword: '123456',
      name: 'Ali',
      location: '',
    );

    expect(result, 'Please select your location.');
  });

  test('validateForm returns error when blood bank name missing', () {
    final result = controller.validateForm(
      userType: UserType.bloodBank,
      email: 'b@test.com',
      password: '123456',
      confirmPassword: '123456',
      bloodBankName: '',
      location: 'Amman',
    );

    expect(result, 'Please enter the blood bank name.');
  });

  test('validateForm returns null when valid donor form', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      confirmPassword: '123456',
      name: 'Ali',
      location: 'Amman',
    );

    expect(result, null);
  });

  // =========================================================
  // REGISTER - DONOR SUCCESS
  // =========================================================

  test('register donor succeeds when email verified', () async {
    when(() => mockAuth.signUpDonor(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          location: any(named: 'location'),
        )).thenAnswer((_) async => {
          'emailVerified': true,
        });

    final result = await controller.register(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      name: 'Ali',
      location: 'Amman',
    );

    expect(result.success, true);
    expect(result.emailVerified, true);
  });

  // =========================================================
  // REGISTER - BLOOD BANK SUCCESS
  // =========================================================

  test('register blood bank succeeds when email not verified',
      () async {
    when(() => mockAuth.signUpBloodBank(
          bloodBankName: any(named: 'bloodBankName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          location: any(named: 'location'),
        )).thenAnswer((_) async => {
          'emailVerified': false,
        });

    final result = await controller.register(
      userType: UserType.bloodBank,
      email: 'b@test.com',
      password: '123456',
      bloodBankName: 'Central Bank',
      location: 'Amman',
    );

    expect(result.success, true);
    expect(result.emailVerified, false);
  });

  // =========================================================
  // REGISTER - MISSING REQUIRED FIELDS
  // =========================================================

  test('register donor fails when name missing', () async {
    final result = await controller.register(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      name: '',
      location: 'Amman',
    );

    expect(result.success, false);
    expect(result.errorTitle, 'Missing name');
  });

  test('register blood bank fails when bloodBankName missing',
      () async {
    final result = await controller.register(
      userType: UserType.bloodBank,
      email: 'b@test.com',
      password: '123456',
      bloodBankName: '',
      location: 'Amman',
    );

    expect(result.success, false);
    expect(result.errorTitle, 'Missing blood bank name');
  });

  // =========================================================
  // REGISTER - FIREBASE AUTH EXCEPTION
  // =========================================================

  test('register returns proper message on email-already-in-use',
      () async {
    when(() => mockAuth.signUpDonor(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          location: any(named: 'location'),
        )).thenThrow(
      FirebaseAuthException(code: 'email-already-in-use'),
    );

    final result = await controller.register(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      name: 'Ali',
      location: 'Amman',
    );

    expect(result.success, false);
    expect(result.errorTitle, 'Email already in use');
  });

  // =========================================================
  // REGISTER - GENERIC ERRORS
  // =========================================================

  test('register maps network error correctly', () async {
    when(() => mockAuth.signUpDonor(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          location: any(named: 'location'),
        )).thenThrow(Exception('network error'));

    final result = await controller.register(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      name: 'Ali',
      location: 'Amman',
    );

    expect(result.success, false);
    expect(result.errorTitle, 'Connection error');
  });

  test('register returns Sign up failed on generic invalid-argument exception',
    () async {
  when(() => mockAuth.signUpDonor(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        location: any(named: 'location'),
      )).thenThrow(Exception('invalid-argument'));

  final result = await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali',
    location: 'Amman',
  );

  expect(result.success, false);
  expect(result.errorTitle, 'Sign up failed');
});

}
