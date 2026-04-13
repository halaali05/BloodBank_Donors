import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../../services/password_reset_service.dart';
import '../../theme/app_theme.dart';

/// Screen for users who forgot their password
/// Sends a password reset email to the provided address
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _passwordResetService = PasswordResetService();
  bool _loading = false; // Show loading state while sending email

  /// Sends password reset email to the entered email address
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
        if (result.success) Navigator.pop(context);
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
      backgroundColor: AppTheme.softBg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Colors.grey[800],
                ),
              ),
            ),

            // محتوى الصفحة
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Container(
                    width: 360,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE6EAF2)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Forgot Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.deepRed,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Enter your registered email to receive a reset link.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),

                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: AppTheme.underlineInputDecoration(
                            hint: 'Email',
                            icon: Icons.mail_outline,
                          ),
                        ),

                        const SizedBox(height: 22),

                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.deepRed,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _loading ? null : _sendResetEmail,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Send Reset Link',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Back to Login',
                            style: TextStyle(color: AppTheme.deepRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
