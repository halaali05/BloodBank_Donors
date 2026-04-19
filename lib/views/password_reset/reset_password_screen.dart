import 'package:flutter/material.dart';
import '../../controllers/reset_password_controller.dart';
import '../../utils/dialog_helper.dart';

/// Reset Password Screen
///
/// FLOW OVERVIEW:
/// 1. User requests password reset from ForgotPasswordScreen
/// 2. User receives email with reset link from Firebase Auth
/// 3. User clicks link in email → Opens app with oobCode parameter
/// 4. User enters new password and confirms it
/// 5. Password is reset via Firebase Auth's confirmPasswordReset()
/// 6. User is redirected to login screen
///
/// SECURITY:
/// - All password reset operations go through Firebase Auth (server-side)
/// - oobCode from email link is validated server-side
/// - Password is updated securely on Firebase servers
///
/// NOTE: The oobCode is extracted from the email link URL parameter
/// when user clicks the reset link in their email
class ResetPasswordScreen extends StatefulWidget {
  /// Verification code (oobCode) extracted from the password reset email link
  /// This code is automatically included in the Firebase Auth reset email link
  final String code;

  /// Optional email address for display purposes
  final String? email;

  const ResetPasswordScreen({super.key, required this.code, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final ResetPasswordController _controller = ResetPasswordController();

  // Controllers for password input fields
  final _pass1 = TextEditingController(); // New password
  final _pass2 = TextEditingController(); // Confirm password
  bool _loading = false; // Loading state during password reset

  // ------------------ Password Reset Handler ------------------
  /// Handles password reset submission
  ///
  /// FLOW:
  /// 1. Validates that both password fields are filled
  /// 2. Validates password strength (min 6 characters)
  /// 3. Validates that passwords match
  /// 4. Calls Firebase Auth: confirmPasswordReset(code, newPassword)
  /// 5. Handles success/error responses
  /// 6. Navigates to login screen on success
  Future<void> _handleResetPassword() async {
    final newPassword = _pass1.text;
    final confirmPassword = _pass2.text;

    // Step 1: Validate form
    final validationError = _controller.validateForm(
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    if (validationError != null) {
      DialogHelper.showWarning(
        context: context,
        title: 'Validation Error',
        message: validationError,
      );
      return;
    }

    // Step 2: Show loading state
    setState(() => _loading = true);

    try {
      // Step 3: Call Firebase Auth to confirm password reset
      // The code (oobCode) was extracted from the email link
      // This validates the code server-side and updates the password
      final result = await _controller.resetPassword(
        code: widget.code,
        newPassword: newPassword,
      );

      if (!mounted) return;

      // Step 4: Handle result
      if (result.success) {
        // Wait for dialog to be dismissed before navigating
        await DialogHelper.showSuccess(
          context: context,
          title: 'Password updated',
          message: result.message,
        );

        // Step 5: Navigate back to login screen (first screen in stack)
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        DialogHelper.showError(
          context: context,
          title: 'Reset failed',
          message: result.message,
        );
      }
    } catch (e) {
      if (!mounted) return;
      DialogHelper.showError(
        context: context,
        title: 'Error',
        message: 'Something went wrong. Please try again.',
      );
    } finally {
      // Step 6: Reset loading state
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  // ------------------ UI Build ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Display email if provided, otherwise generic message
            Text(
              widget.email != null
                  ? 'Reset password for ${widget.email}'
                  : 'Enter your new password',
            ),
            const SizedBox(height: 12),

            // New password input field
            TextField(
              controller: _pass1,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),

            // Confirm password input field
            TextField(
              controller: _pass2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleResetPassword,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Update password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
