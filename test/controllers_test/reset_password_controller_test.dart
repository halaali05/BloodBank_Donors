import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/reset_password_controller.dart';
import 'package:bloodbank_donors/services/password_reset_service.dart';

// -------------------- Mocks --------------------
class MockPasswordResetService extends Mock
    implements PasswordResetService {}

void main() {
  late MockPasswordResetService mockService;
  late ResetPasswordController controller;

  setUp(() {
    mockService = MockPasswordResetService();
    controller =
        ResetPasswordController(passwordResetService: mockService);
  });

  // =========================================================
  // VALIDATION
  // =========================================================

  test('validateForm returns error when fields are empty', () {
    final result = controller.validateForm(
      newPassword: '',
      confirmPassword: '',
    );

    expect(result, 'Please fill in both password fields.');
  });

  test('validateForm returns error when password too short', () {
    final result = controller.validateForm(
      newPassword: '123',
      confirmPassword: '123',
    );

    expect(result, 'Password must be at least 6 characters.');
  });

  test('validateForm returns error when passwords do not match', () {
    final result = controller.validateForm(
      newPassword: '123456',
      confirmPassword: '654321',
    );

    expect(result, 'The passwords do not match. Please try again.');
  });

  test('validateForm returns null when valid', () {
    final result = controller.validateForm(
      newPassword: '123456',
      confirmPassword: '123456',
    );

    expect(result, null);
  });

  // =========================================================
  // RESET PASSWORD - SUCCESS
  // =========================================================

  test('resetPassword returns success when service succeeds',
      () async {
    when(() => mockService.confirmPasswordReset(
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer(
      (_) async => const PasswordResetResult(
        success: true,
        message: 'Password updated',
      ),
    );

    final result = await controller.resetPassword(
      code: 'abc123',
      newPassword: '123456',
    );

    expect(result.success, true);
    expect(result.message, 'Password updated');
  });

  // =========================================================
  // RESET PASSWORD - FIREBASE ERRORS
  // =========================================================

  test(
      'resetPassword maps expired-action-code correctly',
      () async {
    when(() => mockService.confirmPasswordReset(
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(
      FirebaseAuthException(code: 'expired-action-code'),
    );

    final result = await controller.resetPassword(
      code: 'abc',
      newPassword: '123456',
    );

    expect(result.success, false);
    expect(
      result.message,
      'The verification code has expired. Please request a new password reset.',
    );
  });

  test(
      'resetPassword maps invalid-action-code correctly',
      () async {
    when(() => mockService.confirmPasswordReset(
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(
      FirebaseAuthException(code: 'invalid-action-code'),
    );

    final result = await controller.resetPassword(
      code: 'abc',
      newPassword: '123456',
    );

    expect(result.success, false);
    expect(
      result.message,
      'The verification code is invalid. Please check and try again.',
    );
  });

  test('resetPassword maps weak-password correctly',
      () async {
    when(() => mockService.confirmPasswordReset(
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(
      FirebaseAuthException(code: 'weak-password'),
    );

    final result = await controller.resetPassword(
      code: 'abc',
      newPassword: '123456',
    );

    expect(result.success, false);
    expect(
      result.message,
      'Password is too weak. Please use at least 6 characters.',
    );
  });

  test('resetPassword maps user-disabled correctly',
      () async {
    when(() => mockService.confirmPasswordReset(
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(
      FirebaseAuthException(code: 'user-disabled'),
    );

    final result = await controller.resetPassword(
      code: 'abc',
      newPassword: '123456',
    );

    expect(result.success, false);
    expect(
      result.message,
      'This account has been disabled. Please contact support.',
    );
  });

  test('resetPassword maps user-not-found correctly',
      () async {
    when(() => mockService.confirmPasswordReset(
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(
      FirebaseAuthException(code: 'user-not-found'),
    );

    final result = await controller.resetPassword(
      code: 'abc',
      newPassword: '123456',
    );

    expect(result.success, false);
    expect(
      result.message,
      'No account found. Please check your email address.',
    );
  });

  // =========================================================
  // RESET PASSWORD - GENERIC ERRORS
  // =========================================================

  test('resetPassword returns generic message on unknown error',
      () async {
    when(() => mockService.confirmPasswordReset(
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(Exception('network error'));

    final result = await controller.resetPassword(
      code: 'abc',
      newPassword: '123456',
    );

    expect(result.success, false);
    expect(
      result.message,
      'Something went wrong. Please try again.',
    );
  });
}
