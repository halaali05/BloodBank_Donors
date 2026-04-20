import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bloodbank_donors/models/login_models.dart';

void main() {
  group('LoginResult', () {

    test('creates success result correctly', () {
      final widget = Container();

      final result = LoginResult(
        success: true,
        navigationRoute: widget,
      );

      expect(result.success, true);
      expect(result.navigationRoute, widget);
      expect(result.errorType, null);
      expect(result.errorMessage, null);
      expect(result.errorTitle, null);
    });

    test('creates error result correctly', () {
      final result = LoginResult(
        success: false,
        errorType: LoginErrorType.userNotFound,
        errorTitle: 'User not found',
        errorMessage: 'No account exists',
      );

      expect(result.success, false);
      expect(result.navigationRoute, null);
      expect(result.errorType, LoginErrorType.userNotFound);
      expect(result.errorTitle, 'User not found');
      expect(result.errorMessage, 'No account exists');
    });

    test('handles all error types', () {
      for (final type in LoginErrorType.values) {
        final result = LoginResult(
          success: false,
          errorType: type,
        );

        expect(result.errorType, type);
      }
    });

    test('allows null optional fields', () {
      final result = LoginResult(success: true);

      expect(result.navigationRoute, null);
      expect(result.errorType, null);
      expect(result.errorMessage, null);
      expect(result.errorTitle, null);
    });
  });

  // =====================================================

  group('ResendVerificationResult', () {

    test('creates success result with message', () {
      final result = ResendVerificationResult(
        success: true,
        message: 'Email sent',
      );

      expect(result.success, true);
      expect(result.message, 'Email sent');
      expect(result.errorTitle, null);
      expect(result.errorMessage, null);
    });

    test('creates error result correctly', () {
      final result = ResendVerificationResult(
        success: false,
        errorTitle: 'Error',
        errorMessage: 'Something went wrong',
      );

      expect(result.success, false);
      expect(result.message, null);
      expect(result.errorTitle, 'Error');
      expect(result.errorMessage, 'Something went wrong');
    });

    test('allows all fields to be null except success', () {
      final result = ResendVerificationResult(success: false);

      expect(result.success, false);
      expect(result.message, null);
      expect(result.errorTitle, null);
      expect(result.errorMessage, null);
    });
  });
}