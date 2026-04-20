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


group('EMAIL VALIDATION', () {
  test('isValidEmail returns true for valid email', () {
    expect(controller.isValidEmail('a@test.com'), true);
  });

  test('isValidEmail returns false for invalid email', () {
    expect(controller.isValidEmail('invalid-email'), false);
  });
});
 
 group('FORM VALIDATION', () {
  test('validateForm returns error when email or password empty', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: '',
      password: '',
      confirmPassword: '',
      name: '',
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
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
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
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
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
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
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
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
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
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
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
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
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
      location: 'Amman',
    );

    expect(result, null);
  });

  test('validateForm returns error when donor gender missing', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      confirmPassword: '123456',
      name: 'Ali',
      donorGender: null,
      donorPhoneRaw: '0791234567',
      location: 'Amman',
    );

    expect(result, 'Please select your gender (male or female).');
  });

  test('validateForm returns error when donor phone invalid', () {
    final result = controller.validateForm(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      confirmPassword: '123456',
      name: 'Ali',
      donorGender: 'female',
      donorPhoneRaw: '12345',
      location: 'Amman',
    );

    expect(
      result,
      'Enter a valid Jordan mobile number (e.g. 0791234567 or +962791234567).',
    );
  });

test('validateForm returns error when blood bank map pin missing', () {
  final result = controller.validateForm(
    userType: UserType.bloodBank,
    email: 'b@test.com',
    password: '123456',
    confirmPassword: '123456',
    bloodBankName: 'Bank',
    location: 'Amman',
    bloodBankHasMapPin: false,
  );

  expect(result, 'Please pin the hospital location on the map.');
});

test('validateForm returns error when donor gender invalid value', () {
  final result = controller.validateForm(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    confirmPassword: '123456',
    name: 'Ali',
    donorGender: 'unknown',
    donorPhoneRaw: '0791234567',
    location: 'Amman',
  );

  expect(result, 'Please select your gender (male or female).');
});

});
 
 group('REGISTER - DONOR SUCCESS', () {
  test('register donor succeeds when email verified', () async {
    when(
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
    ).thenAnswer((_) async => {'emailVerified': true});

    final result = await controller.register(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      name: 'Ali',
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
      location: 'Amman',
    );

    expect(result.success, true);
    expect(result.emailVerified, true);
  });

  test('register donor fails when gender invalid', () async {
  final result = await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali',
    donorGender: 'wrong',
    donorPhoneRaw: '0791234567',
    location: 'Amman',
  );

  expect(result.success, false);
  expect(result.errorTitle, 'Missing gender');
});

  test('register donor fails when phone invalid after normalize', () async {
  final result = await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali',
    donorGender: 'male',
    donorPhoneRaw: '123', // invalid
    location: 'Amman',
  );

  expect(result.success, false);
  expect(result.errorTitle, 'Invalid phone number');
});
 });  
 
 
group('REGISTER - BLOOD BANK SUCCESS', () {
  test('register blood bank succeeds when email not verified', () async {
    when(
      () => mockAuth.signUpBloodBank(
        bloodBankName: any(named: 'bloodBankName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        location: any(named: 'location'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => {'emailVerified': false});

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

  test('register uses exact coordinates when provided', () async {
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

  await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali',
    donorGender: 'male',
    donorPhoneRaw: '0791234567',
    location: 'Amman',
    exactLatitude: 10,
    exactLongitude: 20,
  );

  verify(() => mockAuth.signUpDonor(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
        latitude: 10,
        longitude: 20,
      )).called(1);
});
});

  
group('REGISTER - MISSING REQUIRED FIELDS', () {
  test('register donor fails when name missing', () async {
    final result = await controller.register(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      name: '',
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
      location: 'Amman',
    );

    expect(result.success, false);
    expect(result.errorTitle, 'Missing name');
  });

  test('register blood bank fails when bloodBankName missing', () async {
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
});


group('REGISTER - FIREBASE AUTH EXCEPTION', () {
  test('register returns proper message on email-already-in-use', () async {
    when(
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
    ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

    final result = await controller.register(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      name: 'Ali',
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
      location: 'Amman',
    );

    expect(result.success, false);
    expect(result.errorTitle, 'Email already in use');
  });

test('register maps weak-password', () async {
  when(() => mockAuth.signUpDonor(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      )).thenThrow(FirebaseAuthException(code: 'weak-password'));

  final result = await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali',
    donorGender: 'male',
    donorPhoneRaw: '0791234567',
    location: 'Amman',
  );

  expect(result.errorTitle, 'Password too weak');
});
});
 
 
group('REGISTER - GENERIC ERRORS', () {
  test('register maps network error correctly', () async {
    when(
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
    ).thenThrow(Exception('network error'));

    final result = await controller.register(
      userType: UserType.donor,
      email: 'a@test.com',
      password: '123456',
      name: 'Ali',
      donorGender: 'male',
      donorPhoneRaw: '0791234567',
      location: 'Amman',
    );

    expect(result.success, false);
    expect(result.errorTitle, 'Connection error');
  });

  test('register returns Sign up failed on generic invalid-argument exception',() async {
      when(
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
      ).thenThrow(Exception('invalid-argument'));

      final result = await controller.register(
        userType: UserType.donor,
        email: 'a@test.com',
        password: '123456',
        name: 'Ali',
        donorGender: 'male',
        donorPhoneRaw: '0791234567',
        location: 'Amman',
      );

      expect(result.success, false);
      expect(result.errorTitle, 'Sign up failed');
    },
  );

test('maps blood type error', () async {
  when(() => mockAuth.signUpDonor(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      )).thenThrow(Exception('bloodType is required'));

  final r = await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali',
    donorGender: 'male',
    donorPhoneRaw: '0791234567',
    location: 'Amman',
  );

  expect(r.success, false);
  expect(r.errorTitle, 'Registration error');
});

  test('Exception prefix parsing', () async {
  when(() => mockAuth.signUpDonor(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      )).thenThrow(Exception('Exception: custom error'));

  final r = await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali',
    donorGender: 'male',
    donorPhoneRaw: '0791234567',
    location: 'Amman',
  );

  expect(r.success, false);
  expect(r.errorMessage, contains('custom error'));
});

test('maps invalid gender/phone error', () async {
  when(() => mockAuth.signUpDonor(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      )).thenThrow(Exception('gender must be male'));

  final r = await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali',
    donorGender: 'male', // مهم تكون valid
    donorPhoneRaw: '0791234567',
    location: 'Amman',
  );

  expect(r.success, false);
  expect(r.errorTitle, 'Invalid information');
});

test('maps missing info error', () async {
  when(() => mockAuth.signUpDonor(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      )).thenThrow(Exception('fullName is required'));

  final r = await controller.register(
    userType: UserType.donor,
    email: 'a@test.com',
    password: '123456',
    name: 'Ali', // لازم valid
    donorGender: 'male',
    donorPhoneRaw: '0791234567',
    location: 'Amman',
  );

  expect(r.success, false);
  expect(r.errorTitle, 'Missing information');
});
});

}
