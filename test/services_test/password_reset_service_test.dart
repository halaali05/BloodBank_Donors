import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodbank_donors/services/password_reset_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late MockFirebaseAuth mockAuth;
  late PasswordResetService service;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    service = PasswordResetService(auth: mockAuth);
  });

              //TEST CASES//

       
      /// SUCCESS ///
  test('sends reset link successfully', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),)).thenAnswer(
              (_) async => Future.value());

    final result = await service.sendPasswordResetEmail("test@test.com");

    expect(result.success, true);
    expect(result.message,"Password reset link has been sent to your email.");

    verify(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),)).called(1);
  });

        /// USER NOT FOUND ///
  test('returns message when user not found', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),)).thenThrow(
               FirebaseAuthException(code: "user-not-found"),);

    final result = await service.sendPasswordResetEmail("test@test.com");

    expect(result.success, false);
    expect(result.message,"No account found with this email address.");
  });

          /// INVALID EMAIL ///
  test('returns message when email invalid', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),
              )).thenThrow(FirebaseAuthException(code: "invalid-email"),);

    final result = await service.sendPasswordResetEmail("bad_email");

    expect(result.success, false);
    expect(result.message, "Invalid email address.");
  });

          /// TOO MANY REQUESTS ///
  test('returns too many requests message', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),
              )).thenThrow(FirebaseAuthException(code: "too-many-requests"),);

    final result =await service.sendPasswordResetEmail("test@test.com");

    expect(result.success, false);
    expect(result.message,"Too many requests. Please try again later.");
  });

          /// OTHER ERROR ///
  test('returns failure message', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),)).thenThrow(Exception());

    final result = await service.sendPasswordResetEmail("test@test.com");

    expect(result.success, false);
    expect(result.message,"Something went wrong. Please try again.");
  });


/// EMPTY EMAIL
test('returns message if email empty', () async {
  final result = await service.sendPasswordResetEmail("");

  expect(result.success, false);
  expect(result.message, "Please enter your email address.");

  verifyNever(() =>
      mockAuth.sendPasswordResetEmail(email: any(named: "email")));
});


/// UNKNOWN FIREBASE ERROR
test('returns default failure message for unknown firebase error', () async {
  when(() => mockAuth.sendPasswordResetEmail(
        email: any(named: "email"),
      )).thenThrow(FirebaseAuthException(code: "some-random-code"));

  final result = await service.sendPasswordResetEmail("test@test.com");

  expect(result.success, false);
  expect(result.message, "Failed to send reset email. Please try again.");
});

/// ===============================
/// confirmPasswordReset TESTS
/// ===============================

/// SUCCESS CASE
test('confirms password reset successfully', () async {
  // Arrange: mock successful reset
  when(() => mockAuth.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      )).thenAnswer((_) async {});

  // Act
  final result = await service.confirmPasswordReset(
    code: 'valid_code',
    newPassword: 'newStrongPassword',
  );

  // Assert
  expect(result.success, true);
  expect(result.message, 'Your password has been successfully updated.');

  verify(() => mockAuth.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      )).called(1);
});


/// EMPTY CODE
test('returns error when verification code is empty', () async {
  final result = await service.confirmPasswordReset(
    code: '',
    newPassword: '123456',
  );

  expect(result.success, false);
  expect(result.message, 'Please enter the verification code.');

  // Firebase should NOT be called
  verifyNever(() => mockAuth.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      ));
});


/// EMPTY PASSWORD
test('returns error when password is empty', () async {
  final result = await service.confirmPasswordReset(
    code: 'code123',
    newPassword: '',
  );

  expect(result.success, false);
  expect(result.message, 'Please enter a new password.');
});


/// WEAK PASSWORD
test('returns error when password is too short', () async {
  final result = await service.confirmPasswordReset(
    code: 'code123',
    newPassword: '123',
  );

  expect(result.success, false);
  expect(result.message, 'Password must be at least 6 characters.');
});


/// EXPIRED ACTION CODE
test('returns error when action code expired', () async {
  when(() => mockAuth.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      )).thenThrow(FirebaseAuthException(code: 'expired-action-code'));

  final result = await service.confirmPasswordReset(
    code: 'expired_code',
    newPassword: '123456',
  );

  expect(result.success, false);
  expect(result.message,'The verification code has expired. Please request a new password reset.',);
});


/// INVALID ACTION CODE
test('returns error when action code invalid', () async {
  when(() => mockAuth.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      )).thenThrow(FirebaseAuthException(code: 'invalid-action-code'));

  final result = await service.confirmPasswordReset(
    code: 'invalid_code',
    newPassword: '123456',
  );

  expect(result.success, false);
  expect(result.message,'The verification code is invalid. Please check and try again.',);
});


/// UNKNOWN FIREBASE ERROR
test('returns default error for unknown firebase error during confirmation',
    () async {
  when(() => mockAuth.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      )).thenThrow(FirebaseAuthException(code: 'unknown-code'));

  final result = await service.confirmPasswordReset(
    code: 'code123',
    newPassword: '123456',
  );

  expect(result.success, false);
  expect(result.message,'Failed to reset password. Please try again.',);
});


/// GENERIC EXCEPTION
test('returns generic error when exception occurs', () async {
  when(() => mockAuth.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      )).thenThrow(Exception());

  final result = await service.confirmPasswordReset(
    code: 'code123',
    newPassword: '123456',
  );

  expect(result.success, false);
  expect(result.message, 'Something went wrong. Please try again.');
});

}