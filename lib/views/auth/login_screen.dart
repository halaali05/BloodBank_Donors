import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/login_controller.dart';
import '../../models/login_models.dart';
import '../../services/fcm_service.dart';
import '../../shared/app_status/loading_status_messages.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/common/app_loading_overlay.dart';
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
  String _blockingCaption = LoadingStatusMessages.signingIn;

  /// Message for failed login / forgot-password lookup (not while busy).
  String? _authErrorText;
  bool _authErrorIsOffline = false;

  String? _resendHint;
  bool _resendHintIsError = false;
  bool _resendBusy = false;

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

  String _loginFailureMessage(LoginResult result) {
    if (result.errorType == LoginErrorType.networkOffline) {
      return LoadingStatusMessages.noInternet;
    }
    final m = result.errorMessage?.trim();
    if (m != null && m.isNotEmpty) return m;
    return LoadingStatusMessages.genericError;
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
      setState(() {
        _authErrorText = 'Please enter your password.';
        _authErrorIsOffline = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _blockingCaption = LoadingStatusMessages.signingIn;
      _authErrorText = null;
      _resendHint = null;
    });

    final result = await _loginController.login(
      identifier: identifier,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.navigationRoute != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => result.navigationRoute!),
        (route) => false,
      );
      unawaited(
        FCMService.instance
            .ensureTokenSynced(
              attempts: 4,
              delay: const Duration(seconds: 2),
            )
            .catchError((Object _, StackTrace __) => false),
      );
      return;
    }

    setState(() {
      _authErrorText = _loginFailureMessage(result);
      _authErrorIsOffline = result.errorType == LoginErrorType.networkOffline;
    });
  }

  Future<void> _handleResendVerification() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty) {
      setState(() {
        _resendHint = 'Enter your email or phone number first.';
        _resendHintIsError = true;
      });
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
      setState(() {
        _resendHint =
            'Enter your password as well — it is needed to resend verification.';
        _resendHintIsError = true;
      });
      return;
    }

    setState(() {
      _resendBusy = true;
      _resendHint = null;
      _authErrorText = null;
    });

    try {
      final result = await _loginController.resendVerification(
        identifier: identifier,
        password: password,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _resendBusy = false;
          _resendHint =
              result.message ??
              'We sent a new verification email. Check your inbox.';
          _resendHintIsError = false;
        });
      } else {
        setState(() {
          _resendBusy = false;
          _resendHint =
              result.errorMessage ??
              result.errorTitle ??
              LoadingStatusMessages.genericError;
          _resendHintIsError = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resendBusy = false;
        _resendHint = LoadingStatusMessages.genericError;
        _resendHintIsError = true;
      });
    }
  }

  Future<void> _openForgotPassword() async {
    if (_isLoading) return;

    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _authErrorText = 'Enter your email or phone number first.';
        _authErrorIsOffline = false;
      });
      return;
    }

    _syncIdentifierFieldError();
    if (_identifierError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _blockingCaption = LoadingStatusMessages.lookingUpAccount;
      _authErrorText = null;
      _resendHint = null;
    });

    String? inbox;
    if (_emailMode) {
      inbox = LoginController.isValidEmailFormat(identifier) ? identifier : null;
    } else {
      inbox = await _loginController.emailForForgotPassword(identifier);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (inbox == null || inbox.isEmpty) {
      setState(() {
        _authErrorText = _emailMode
            ? 'Could not find an account with this email. Check spelling or try your Jordan mobile.'
            : 'No account uses this mobile, or lookup failed. Try the email you registered with.';
        _authErrorIsOffline = false;
      });
      return;
    }

    if (!mounted) return;
    _navigateTo(ForgotPasswordScreen(initialEmail: inbox));
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final errColor = Colors.red.shade800;
    final offlineColor = Colors.deepOrange.shade900;

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LoginFormCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LoginAvatar(),
                        const SizedBox(height: 22),
                        TextField(
                      controller: _identifierController,
                      autocorrect: false,
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
                    if (_authErrorText != null && !_isLoading) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _authErrorIsOffline
                                ? Icons.wifi_off_rounded
                                : Icons.error_outline_rounded,
                            size: 22,
                            color: _authErrorIsOffline ? offlineColor : errColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _authErrorText!,
                              style: TextStyle(
                                color:
                                    _authErrorIsOffline ? offlineColor : errColor,
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    PrimaryButton(
                      text: 'Log In',
                      onPressed: _isLoading ? null : _handleLogin,
                      isLoading: false,
                    ),
                    const SizedBox(height: 8),
                    LinkButton(
                      text: 'Resend verification email',
                      onPressed: (!_isLoading && !_resendBusy)
                          ? _handleResendVerification
                          : null,
                    ),
                    if (_resendBusy) ...[
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        LoadingStatusMessages.syncingData,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (_resendHint != null && !_resendBusy) ...[
                      const SizedBox(height: 8),
                      Text(
                        _resendHint!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _resendHintIsError
                              ? errColor
                              : Colors.green.shade800,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                ],
              ),
            ),
          ),
          if (_isLoading)
            AppLoadingOverlay(
              visible: true,
              showProgress: true,
              message: _blockingCaption,
              progressColor: AppTheme.deepRed,
            ),
        ],
      ),
    );
  }
}
