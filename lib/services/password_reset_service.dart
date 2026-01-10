import 'package:firebase_auth/firebase_auth.dart';

/// Service class for handling password reset operations
/// Manages sending password reset emails and handling reset errors
class PasswordResetService {
  final FirebaseAuth _auth;
  PasswordResetService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  /// Sends a password reset email to the provided email address
  ///
  /// Sends a password reset link to the user's email if the email exists
  /// in the system. The email will contain a link to reset the password.
  ///
  /// Parameters:
  /// - [email]: The email address of the user requesting password reset
  ///
  /// Returns:
  /// - [PasswordResetResult] containing success status and a message
  ///   - success: true if email was sent successfully, false otherwise
  ///   - message: Human-readable message describing the result
  Future<PasswordResetResult> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      return const PasswordResetResult(
        success: false,
        message: 'Please enter your email address.',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
      return const PasswordResetResult(
        success: true,
        message: 'Password reset link has been sent to your email.',
      );
    } on FirebaseAuthException catch (e) {
      final message = _getErrorMessage(e.code);
      return PasswordResetResult(success: false, message: message);
    } catch (e) {
      return const PasswordResetResult(
        success: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Confirms password reset with oobCode and new password
  ///
  /// Uses the oobCode (out-of-band code) extracted from the password reset
  /// email link to confirm and apply the new password for the user account.
  ///
  /// The oobCode is automatically included in the Firebase Auth password
  /// reset email link as a URL parameter (e.g., ?oobCode=ABC123).
  ///
  /// Flow:
  /// 1. User requests password reset → receives email with link
  /// 2. User clicks link → app extracts oobCode from URL
  /// 3. User enters new password → this method is called with oobCode
  /// 4. Firebase validates code and updates password server-side
  ///
  /// Parameters:
  /// - [code]: The oobCode extracted from the password reset email link
  /// - [newPassword]: The new password to set
  ///
  /// Returns:
  /// - [PasswordResetResult] containing success status and a message
  Future<PasswordResetResult> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    if (code.trim().isEmpty) {
      return const PasswordResetResult(
        success: false,
        message: 'Please enter the verification code.',
      );
    }

    if (newPassword.isEmpty) {
      return const PasswordResetResult(
        success: false,
        message: 'Please enter a new password.',
      );
    }

    if (newPassword.length < 6) {
      return const PasswordResetResult(
        success: false,
        message: 'Password must be at least 6 characters.',
      );
    }

    try {
      await _auth.confirmPasswordReset(
        code: code.trim(),
        newPassword: newPassword,
      );
      return const PasswordResetResult(
        success: true,
        message: 'Your password has been successfully updated.',
      );
    } on FirebaseAuthException catch (e) {
      final message = _getConfirmResetErrorMessage(e.code);
      return PasswordResetResult(success: false, message: message);
    } catch (e) {
      return const PasswordResetResult(
        success: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Converts Firebase Auth error codes to user-friendly error messages
  ///
  /// Private helper method that maps Firebase Authentication error codes
  /// to readable error messages for display to users.
  ///
  /// Parameters:
  /// - [code]: The Firebase Auth error code (e.g., 'user-not-found', 'invalid-email')
  ///
  /// Returns:
  /// - A [String] containing a user-friendly error message
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'Failed to send reset email. Please try again.';
    }
  }

  /// Converts Firebase Auth error codes to user-friendly error messages
  /// for password reset confirmation
  ///
  /// Parameters:
  /// - [code]: The Firebase Auth error code
  ///
  /// Returns:
  /// - A [String] containing a user-friendly error message
  String _getConfirmResetErrorMessage(String code) {
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

/// Result class for password reset operations
/// Contains the success status and message for password reset attempts
class PasswordResetResult {
  /// Whether the password reset email was sent successfully
  final bool success;

  /// Human-readable message describing the result
  final String message;

  const PasswordResetResult({required this.success, required this.message});
}
