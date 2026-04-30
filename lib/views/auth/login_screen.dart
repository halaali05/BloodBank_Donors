import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/login_controller.dart';
import '../../models/login_models.dart';
import '../../services/fcm_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/dialog_helper.dart';
import '../../shared/utils/jordan_phone.dart';
import '../../shared/widgets/auth/login_widgets.dart';
import 'password_reset/forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LoginController _loginController = LoginController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  /// Live error under unified identifier field.
  String? _identifierError;

  bool get _emailMode =>
      LoginController.identifierLooksLikeEmail(_identifierController.text);

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_syncIdentifierFieldError);
  }

  void _syncIdentifierFieldError() {
    final raw = _identifierController.text;

    void apply(String? err) {
      if (!mounted) return;
      if (err != _identifierError) {
        setState(() => _identifierError = err);
      }
    }

    if (_emailMode) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || !trimmed.contains('@')) {
        apply(null);
        return;
      }
      if (!LoginController.isValidEmailFormat(trimmed)) {
        apply('Invalid email');
        return;
      }
      apply(null);
      return;
    }

    final trimmedNoAt = raw.trim();
    final looksLikePartialEmail =
        trimmedNoAt.isNotEmpty &&
        RegExp(r'[a-zA-Z]').hasMatch(trimmedNoAt);
    if (looksLikePartialEmail) {
      apply(null);
      return;
    }

    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      apply(null);
      return;
    }
    apply(JordanPhone.liveDigitsOnlyError(digitsOnly));
  }

  @override
  void dispose() {
    _identifierController.removeListener(_syncIdentifierFieldError);
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty) {
      setState(() => _identifierError = 'Enter your email or phone number.');
      return;
    }

    _syncIdentifierFieldError();
    if (_identifierError != null) {
      return;
    }

    if (!_loginController.hasIdentifierAndPassword(
      identifier: identifier,
      password: password,
    )) {
      DialogHelper.showWarning(
        context: context,
        title: 'Missing information',
        message: 'Please enter your password.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _loginController.login(
      identifier: identifier,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    await _applyLoginOutcome(result);
  }

  Future<void> _applyLoginOutcome(LoginResult result) async {
    if (!mounted) return;

    if (result.success && result.navigationRoute != null) {
      try {
        await FCMService.instance.ensureTokenSynced(
          attempts: 5,
          delay: const Duration(seconds: 1),
        );
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => result.navigationRoute!),
        (route) => false,
      );
    } else {
      _showError(result);
    }
  }

  Future<void> _handleResendVerification() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty) {
      DialogHelper.showWarning(
        context: context,
        title: 'Missing information',
        message: 'Enter your email or phone number first.',
      );
      return;
    }

    _syncIdentifierFieldError();
    if (_identifierError != null) {
      return;
    }

    if (!_loginController.hasIdentifierAndPassword(
      identifier: identifier,
      password: password,
    )) {
      DialogHelper.showWarning(
        context: context,
        title: 'Missing information',
        message:
            'Enter your password as well — it is needed to send another verification email.',
      );
      return;
    }

    try {
      final result = await _loginController.resendVerification(
        identifier: identifier,
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
    } catch (_) {
      if (!mounted) return;
      DialogHelper.showError(
        context: context,
        title: 'Error',
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> _openForgotPassword() async {
    if (_isLoading) return;

    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      DialogHelper.showWarning(
        context: context,
        title: 'Missing information',
        message: 'Enter your email or phone number first.',
      );
      return;
    }

    _syncIdentifierFieldError();
    if (_identifierError != null) {
      return;
    }

    setState(() => _isLoading = true);

    String? inbox;
    if (_emailMode) {
      inbox = LoginController.isValidEmailFormat(identifier) ? identifier : null;
    } else {
      inbox = await _loginController.emailForForgotPassword(identifier);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (inbox == null || inbox.isEmpty) {
      DialogHelper.showError(
        context: context,
        title: 'Could not find inbox',
        message: _emailMode
            ? 'Check the email spelling, or enter your Jordan mobile '
                'if your account uses phone login.'
            : 'No donor account uses this mobile, or verification failed. '
                'Try entering the email you registered with.',
      );
      return;
    }

    if (!mounted) return;
    _navigateTo(ForgotPasswordScreen(initialEmail: inbox));
  }

  void _showError(LoginResult result) {
    final errorTitle = result.errorTitle ?? 'Error';
    final errorMessage = result.errorMessage ?? 'An error occurred';

    switch (result.errorType) {
      case LoginErrorType.emailNotVerified:
        DialogHelper.showWarning(
          context: context,
          title: errorTitle,
          message: '$errorMessage Tap “Resend verification email” below (phone '
              'numbers work too, with your password).',
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
                  controller: _identifierController,
                  autocorrect: false,
                  /// One field for email or Jordan mobile: full keyboard avoids being
                  /// stuck on email-only layout when signing in with a number.
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9@._+\- \t()]'),
                    ),
                    LengthLimitingTextInputFormatter(128),
                  ],
                  decoration: AppTheme.underlineInputDecoration(
                    hint: 'Enter your email or phone number',
                    icon: Icons.person_outline,
                  ).copyWith(
                    labelText: 'Email or Phone Number',
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    errorText: _identifierError,
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
                  onPressed: !_isLoading ? _handleResendVerification : null,
                ),
                LinkButton(
                  text: 'Forgot password?',
                  onPressed: !_isLoading ? _openForgotPassword : null,
                ),
                const SizedBox(height: 10),
                RegisterLink(
                  onTap: () => _navigateTo(const RegisterScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
