import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../services/password_reset_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _passwordResetService = PasswordResetService();
  bool _loading = false;

  /// Sends a password reset email to the user
  ///
  /// Validates the email input and calls the password reset service
  /// to send a password reset link. Shows success/error messages via SnackBar.
  /// Navigates back to the previous screen on success.
  ///
  /// Sets loading state during the operation.
  Future<void> _sendResetEmail() async {
    final email = _email.text.trim();

    if (email.isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        customHeader: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.orange,
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        title: 'Missing email',
        desc: 'Please enter your email address.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    setState(() => _loading = true);

    final result = await _passwordResetService.sendPasswordResetEmail(email);

    if (!mounted) return;

    AwesomeDialog(
      context: context,
      dialogType: result.success ? DialogType.success : DialogType.error,
      animType: AnimType.bottomSlide,
      customHeader: CircleAvatar(
        radius: 30,
        backgroundColor: result.success ? Colors.green : Colors.red,
        child: Icon(
          result.success ? Icons.check_circle : Icons.error_outline,
          color: Colors.white,
          size: 30,
        ),
      ),
      title: result.success ? 'Email sent' : 'Reset failed',
      desc: result.message,
      btnOkOnPress: () {
        if (result.success) {
          Navigator.pop(context);
        }
      },
    ).show();

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendResetEmail,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Send Reset Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
