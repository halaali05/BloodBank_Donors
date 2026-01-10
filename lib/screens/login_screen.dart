import 'package:flutter/material.dart';
import '../controllers/login_controller.dart';
import '../models/login_models.dart';
import '../utils/dialog_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/login_widgets.dart';
import 'register_screen.dart';
import 'password_reset/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers for email and password input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LoginController _loginController = LoginController();

  // State variables
  bool _obscurePassword = true; // Toggle password visibility
  bool _isLoading = false; // Show loading state during login

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ------------------ Login Handler ------------------
  /// Handles login button press
  /// Delegates business logic to LoginController
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate input
    if (!_loginController.validateInput(email, password)) {
      _showValidationError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Delegate login logic to controller
      final result = await _loginController.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (result.success && result.navigationRoute != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => result.navigationRoute!),
          (route) => false,
        );
      } else {
        _showError(result);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendVerification() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_loginController.validateInput(email, password)) {
      _showValidationError();
      return;
    }

    try {
      // Delegate resend verification logic to controller
      final result = await _loginController.resendVerification(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (result.success) {
        DialogHelper.showSuccess(
          context: context,
          title: 'Verification email sent',
          message: result.message ?? '',
        );
      } else {
        DialogHelper.showError(
          context: context,
          title: result.errorTitle ?? 'Error',
          message: result.errorMessage ?? 'Failed to send verification email',
        );
      }
    } catch (e) {
      if (!mounted) return;
      DialogHelper.showError(
        context: context,
        title: 'Error',
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  // ------------------ Helpers ------------------
  void _showValidationError() {
    DialogHelper.showWarning(
      context: context,
      title: 'Missing information',
      message: 'Please enter both email and password.',
    );
  }

  void _showError(LoginResult result) {
    final errorTitle = result.errorTitle ?? 'Error';
    final errorMessage = result.errorMessage ?? 'An error occurred';

    switch (result.errorType) {
      case LoginErrorType.emailNotVerified:
        DialogHelper.showWarning(
          context: context,
          title: errorTitle,
          message: errorMessage,
        );
        break;
      case LoginErrorType.profileNotReady:
        DialogHelper.showInfo(
          context: context,
          title: errorTitle,
          message: errorMessage,
        );
        break;
      default:
        DialogHelper.showError(
          context: context,
          title: errorTitle,
          message: errorMessage,
        );
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  // ------------------ UI Build ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: LoginFormCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LoginAvatar(),
                const SizedBox(height: 22),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: AppTheme.underlineInputDecoration(
                    hint: 'Username',
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onToggleVisibility: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  text: 'Log In',
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 8),
                LinkButton(
                  text: 'Resend verification email',
                  onPressed: _isLoading ? null : _handleResendVerification,
                ),
                LinkButton(
                  text: 'Forgot password?',
                  onPressed: _isLoading
                      ? null
                      : () => _navigateTo(const ForgotPasswordScreen()),
                ),
                const SizedBox(height: 10),
                RegisterLink(onTap: () => _navigateTo(const RegisterScreen())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
