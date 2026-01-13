import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/login_controller.dart';
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/models/login_models.dart';
import 'package:bloodbank_donors/models/user_model.dart' as models;

// ------------------ Mocks ------------------
class MockAuthService extends Mock implements AuthService {}
class MockUser extends Mock implements User {}

void main() {
  late MockAuthService mockAuth;
  late LoginController controller;

  setUp(() {
    mockAuth = MockAuthService();
    controller = LoginController(authService: mockAuth);
  });

  // =========================================================
  // validateInput
  // =========================================================
  group('validateInput', () {
    test('valid input returns true', () {
      expect(controller.validateInput('a@test.com', '123456'), true);
    });

    test('empty email returns false', () {
      expect(controller.validateInput('', '123456'), false);
    });

    test('empty password returns false', () {
      expect(controller.validateInput('a@test.com', ''), false);
    });

    test('email with spaces is accepted', () {
      expect(controller.validateInput('   a@test.com   ', '123456'), true);
    });
  });

  // =========================================================
  // login — negative flows
  // =========================================================
  group('login - negative cases', () {
    test('email not verified', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => false);
      when(() => mockAuth.logout()).thenAnswer((_) async {});

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.emailNotVerified);
    });

    test('currentUser is null', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
      when(() => mockAuth.currentUser).thenReturn(null);
      when(() => mockAuth.logout()).thenAnswer((_) async {});

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.userNotFound);
    });

    test('profile not ready', () async {
      final user = MockUser();

      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u3');

      when(() => mockAuth.completeProfileAfterVerification())
          .thenAnswer((_) async => {});
      when(() => mockAuth.getUserData('u3')).thenAnswer((_) async => null);
      when(() => mockAuth.logout()).thenAnswer((_) async {});

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.profileNotReady);
    });
  });

  // =========================================================
  // login — success flows
  // =========================================================
  group('login - success cases', () {
    test('donor login success', () async {
      final user = MockUser();

      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');

      when(() => mockAuth.completeProfileAfterVerification())
          .thenAnswer((_) async => {});
      when(() => mockAuth.getUserData('u1'))
          .thenAnswer((_) async => models.User(
                uid: 'u1',
                email: 'a@test.com',
                role: models.UserRole.donor,
              ));

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, true);
      expect(r.navigationRoute, isNotNull);
    });

    test('hospital login success', () async {
      final user = MockUser();

      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u2');

      when(() => mockAuth.completeProfileAfterVerification())
          .thenAnswer((_) async => {});
      when(() => mockAuth.getUserData('u2'))
          .thenAnswer((_) async => models.User(
                uid: 'u2',
                email: 'h@test.com',
                role: models.UserRole.hospital,
                bloodBankName: 'Central Bank',
                location: 'Amman',
              ));

      final r = await controller.login(
        email: 'h@test.com',
        password: '123456',
      );

      expect(r.success, true);
      expect(r.navigationRoute, isNotNull);
    });
  });

  // =========================================================
  // login — FirebaseAuthException mapping
  // =========================================================
  group('login - auth exceptions', () {
    test('wrong-password → authException', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      final r = await controller.login(
        email: 'a@test.com',
        password: 'wrong',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.authException);
    });

    test('invalid-email → title mapped', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      final r = await controller.login(
        email: 'bad',
        password: '123',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.authException);
      expect(r.errorTitle, 'Invalid email address');
    });

    test('user-disabled → title mapped', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'user-disabled'));

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.authException);
      expect(r.errorTitle, 'Account disabled');
    });
  });

  // =========================================================
  // login — generic exception paths
  // =========================================================
  group('login - generic exceptions', () {
    test('network error → genericError with Connection title', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(Exception('network timeout'));

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.genericError);
      expect(r.errorTitle, isNotNull);
    });

    test('unknown error → genericError', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(Exception('boom'));

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.genericError);
    });
  });

  // =========================================================
  // resendVerification
  // =========================================================
  group('resendVerification', () {
    test('success path', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.resendEmailVerification())
          .thenAnswer((_) async {});
      when(() => mockAuth.logout()).thenAnswer((_) async {});

      final r = await controller.resendVerification(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, true);
      expect(r.message, isNotNull);
    });

    test('FirebaseAuthException mapped', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      final r = await controller.resendVerification(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorTitle, isNotNull);
    });

    test('generic exception', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(Exception('boom'));

      final r = await controller.resendVerification(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorTitle, 'Error');
    });
  });
}
