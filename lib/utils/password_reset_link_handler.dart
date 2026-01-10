import 'package:flutter/material.dart';
import '../screens/password_reset/reset_password_screen.dart';

/// Utility class for handling password reset email links
///
/// Firebase Auth sends password reset emails with links containing:
/// - mode=resetPassword
/// - oobCode=VERIFICATION_CODE
///
/// This class extracts the oobCode from the URL and navigates to
/// the reset password screen.
class PasswordResetLinkHandler {
  /// Extracts oobCode from Firebase Auth password reset link
  ///
  /// Example URL format:
  /// https://your-app.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=ABC123&continueUrl=...
  ///
  /// Parameters:
  /// - [url]: The full URL from the password reset email link
  ///
  /// Returns:
  /// - The oobCode if found, null otherwise
  static String? extractOobCode(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['oobCode'];
    } catch (e) {
      return null;
    }
  }

  /// Checks if the URL is a password reset link
  ///
  /// Parameters:
  /// - [url]: The URL to check
  ///
  /// Returns:
  /// - true if URL contains mode=resetPassword, false otherwise
  static bool isPasswordResetLink(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['mode'] == 'resetPassword';
    } catch (e) {
      return false;
    }
  }

  /// Handles password reset link and navigates to reset password screen
  ///
  /// This should be called when the app receives a deep link from
  /// a password reset email.
  ///
  /// Parameters:
  /// - [context]: BuildContext for navigation
  /// - [url]: The password reset link URL from the email
  ///
  /// Returns:
  /// - true if link was handled successfully, false otherwise
  static bool handlePasswordResetLink(BuildContext context, String url) {
    if (!isPasswordResetLink(url)) {
      return false;
    }

    final oobCode = extractOobCode(url);
    if (oobCode == null || oobCode.isEmpty) {
      return false;
    }

    // Extract email from URL if available (optional)
    String? email;
    try {
      final uri = Uri.parse(url);
      email = uri.queryParameters['email'];
    } catch (e) {
      // Email not required, continue without it
    }

    // Navigate to reset password screen with the oobCode
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(code: oobCode, email: email),
      ),
    );

    return true;
  }
}
