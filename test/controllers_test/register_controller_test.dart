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
  group('EMAIL VALIDATION', () {
    test('valid email', () {
      expect(controller.isValidEmail('a@test.com'), true);
    });

    test('invalid email', () {
      expect(controller.isValidEmail('bad'), false);
    });

    test('trims email', () {
      expect(controller.isValidEmail('  a@test.com  '), true);
    });
  });

  // =========================================================
  // FORM VALIDATION
  // =========================================================
  group('FORM VALIDATION', () {
    test('empty email/password', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: '',
        password: '',
        confirmPassword: '',
      );
      expect(r, 'Please enter both email and password.');
    });

    test('invalid email', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: 'bad',
        password: '123456',
        confirmPassword: '123456',
      );
      expect(r, 'Please enter a valid email address.');
    });

    test('password too short', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123',
        confirmPassword: '123',
      );
      expect(r, 'Password must be at least 6 characters.');
    });

    test('password mismatch', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '000000',
      );
      expect(r, 'The passwords do not match. Please try again.');
    });

    // DONOR
    test('donor missing name', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        name: '',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        location: 'Amman',
      );
      expect(r, 'Please enter your full name.');
    });

    test('donor invalid gender', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        name: 'Ali',
        donorGender: 'x',
        donorPhoneRaw: '0791234567',
        location: 'Amman',
      );
      expect(r, 'Please select your gender (male or female).');
    });

    test('donor invalid phone', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        name: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '123',
        location: 'Amman',
      );
      expect(r, contains('079'));
    });

    test('donor missing location', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        name: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        location: '',
      );
      expect(r, 'Please select your location.');
    });

    // BLOOD BANK
    test('blood bank missing name', () {
      final r = controller.validateForm(
        userType: UserType.bloodBank,
        email: 'b@test.com',
        password: '123456',
        confirmPassword: '123456',
        bloodBankName: '',
        location: 'Amman',
      );
      expect(r, 'Please enter the blood bank name.');
    });

    test('blood bank missing map pin', () {
      final r = controller.validateForm(
        userType: UserType.bloodBank,
        email: 'b@test.com',
        password: '123456',
        confirmPassword: '123456',
        bloodBankName: 'Bank',
        location: 'Amman',
        bloodBankHasMapPin: false,
      );
      expect(r, 'Please pin the hospital location on the map.');
    });

    test('valid donor form', () {
      final r = controller.validateForm(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        name: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        location: 'Amman',
      );
      expect(r, null);
    });
  });

  group('SMS OTP helper', () {
    test('empty code', () {
      expect(
        controller.validationErrorForSmsOtp(''),
        'Please enter the SMS verification code.',
      );
    });

    test('non-empty clears error', () {
      expect(controller.validationErrorForSmsOtp('123456'), null);
      expect(controller.validationErrorForSmsOtp('   42  '), null);
    });
  });

  group('SUBMIT REGISTRATION', () {
    test('validation failure skips auth service', () async {
      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: '',
        password: '123456',
        confirmPassword: '123456',
      );
      expect(r.success, false);
      expect(r.errorTitle, 'Missing information');
      verifyNever(
        () => mockAuth.signUpDonor(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          location: any(named: 'location'),
          gender: any(named: 'gender'),
          phoneNumber: any(named: 'phoneNumber'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );
    });
  });

  // =========================================================
  // REGISTER SUCCESS
  // =========================================================
  group('REGISTER SUCCESS', () {
    test('donor success verified', () async {
      when(() => mockAuth.signUpDonor(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            location: any(named: 'location'),
            gender: any(named: 'gender'),
            phoneNumber: any(named: 'phoneNumber'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => {'emailVerified': true});

      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        donorFullName: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        locationGovernorateLabel: 'Amman',
      );

      expect(r.success, true);
      expect(r.emailVerified, true);
    });

    test('emailVerified defaults to false', () async {
      when(() => mockAuth.signUpDonor(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            location: any(named: 'location'),
            gender: any(named: 'gender'),
            phoneNumber: any(named: 'phoneNumber'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => {});

      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        donorFullName: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        locationGovernorateLabel: 'Amman',
      );

      expect(r.emailVerified, false);
    });
  });

  // =========================================================
  // AUTH ERRORS
  // =========================================================
  group('AUTH ERRORS', () {
    test('email already in use', () async {
      when(() => mockAuth.signUpDonor(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            location: any(named: 'location'),
            gender: any(named: 'gender'),
            phoneNumber: any(named: 'phoneNumber'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        donorFullName: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        locationGovernorateLabel: 'Amman',
      );

      expect(r.errorTitle, 'Email already in use');
    });

    test('unknown firebase error', () async {
      when(() => mockAuth.signUpDonor(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            location: any(named: 'location'),
            gender: any(named: 'gender'),
            phoneNumber: any(named: 'phoneNumber'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenThrow(FirebaseAuthException(code: 'unknown'));

      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        donorFullName: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        locationGovernorateLabel: 'Amman',
      );

      expect(r.errorTitle, 'Registration failed');
    });
  });

  // =========================================================
  // GENERIC ERRORS (CRITICAL)
  // =========================================================
  group('GENERIC ERRORS', () {
    test('missing location', () async {
      when(() => mockAuth.signUpDonor(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            location: any(named: 'location'),
            gender: any(named: 'gender'),
            phoneNumber: any(named: 'phoneNumber'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenThrow(Exception('location is required'));

      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        donorFullName: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        locationGovernorateLabel: 'Amman',
      );

      expect(r.errorTitle, 'Missing information');
    });

    test('invalid phoneNumber error', () async {
      when(() => mockAuth.signUpDonor(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            location: any(named: 'location'),
            gender: any(named: 'gender'),
            phoneNumber: any(named: 'phoneNumber'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenThrow(Exception('phoneNumber must be'));

      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        donorFullName: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        locationGovernorateLabel: 'Amman',
      );

      expect(r.errorTitle, 'Invalid information');
    });

    test('invalid-argument', () async {
      when(() => mockAuth.signUpDonor(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            location: any(named: 'location'),
            gender: any(named: 'gender'),
            phoneNumber: any(named: 'phoneNumber'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenThrow(Exception('invalid-argument'));

      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        donorFullName: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        locationGovernorateLabel: 'Amman',
      );

      expect(r.errorTitle, 'Invalid information');
    });

    test('fallback generic error', () async {
      when(() => mockAuth.signUpDonor(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            location: any(named: 'location'),
            gender: any(named: 'gender'),
            phoneNumber: any(named: 'phoneNumber'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenThrow(Exception('random'));

      final r = await controller.submitRegistration(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        confirmPassword: '123456',
        donorFullName: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        locationGovernorateLabel: 'Amman',
      );

      expect(r.errorTitle, 'Sign up failed');
    });
  });
}
