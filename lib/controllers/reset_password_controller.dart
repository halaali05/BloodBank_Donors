import 'package:firebase_auth/firebase_auth.dart';
import '../services/password_reset_service.dart';

/// New password submit after user opens the Firebase email link.
class ResetPasswordController {
  final PasswordResetService _passwordResetService;

  ResetPasswordController({PasswordResetService? passwordResetService})
    : _passwordResetService = passwordResetService ?? PasswordResetService();

  // --- Form ---

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

    return null; // validation passed
  }

  // --- Server ---

  /// Uses `code` (`oobCode` from the reset email) plus the freshly typed password.
  Future<PasswordResetResult> resetPassword({
    required String code, // oobCode extracted from Firebase email URL
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
