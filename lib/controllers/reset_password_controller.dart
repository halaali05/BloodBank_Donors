import 'package:firebase_auth/firebase_auth.dart';
import '../services/password_reset_service.dart';

/// Controller for handling password reset business logic
/// Separates business logic from UI for better maintainability
class ResetPasswordController {
  final PasswordResetService _passwordResetService;

  ResetPasswordController({PasswordResetService? passwordResetService})
    : _passwordResetService = passwordResetService ?? PasswordResetService();

  // ------------------ Validation ------------------
  /// Validates password reset form
  /// Returns validation error message or null if valid
  String? validateForm({
    required String newPassword,
    required String confirmPassword,
  }) {
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      return 'Please fill in both password fields.';
    }

    if (newPassword.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    if (newPassword != confirmPassword) {
      return 'The passwords do not match. Please try again.';
    }

    return null; // Valid
  }

  // ------------------ Password Reset Logic ------------------
  /// Confirms password reset with oobCode from email link
  ///
  /// Flow:
  /// 1. User requests password reset → receives email with link
  /// 2. User clicks link in email → app extracts oobCode from URL
  /// 3. User enters new password → this method is called
  /// 4. Firebase validates oobCode and updates password server-side
  ///
  /// Security Architecture:
  /// - Uses Firebase Auth's confirmPasswordReset() method
  /// - oobCode is validated server-side (from email link)
  /// - Password is updated securely on Firebase servers
  /// - No code entry required - code comes from email link automatically
  ///
  /// Parameters:
  /// - [code]: The oobCode extracted from the password reset email link
  /// - [newPassword]: The new password to set
  ///
  /// Returns PasswordResetResult with success status and message
  Future<PasswordResetResult> resetPassword({
    required String code, // oobCode from email link
    required String newPassword,
  }) async {
    try {
      return await _passwordResetService.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
    } catch (e) {
      // Handle unexpected errors
      if (e is FirebaseAuthException) {
        return PasswordResetResult(
          success: false,
          message: _getErrorMessage(e.code),
        );
      }
      return const PasswordResetResult(
        success: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  // ------------------ Error Message Helpers ------------------
  String _getErrorMessage(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'The verification code has expired. Please request a new password reset.';
      case 'invalid-action-code':
        return 'The verification code is invalid. Please check and try again.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found. Please check your email address.';
      default:
        return 'Failed to reset password. Please try again.';
    }
  }
}
