import 'package:firebase_auth/firebase_auth.dart';

import '../models/login_models.dart';
import '../models/user_model.dart' as models;
import '../services/auth_service.dart';
import '../shared/utils/jordan_phone.dart';
import '../views/admin/admin_dashboard_screen.dart';
import '../views/dashboard/blood_bank_dashboard_screen.dart';
import '../views/dashboard/donor_dashboard_screen.dart';

/// Email/password sign-in, or **Jordan phone + same password** (resolves to donor email).
class LoginController {
  LoginController({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool identifierLooksLikeEmail(String identifier) =>
      identifier.trim().contains('@');

  static bool isValidEmailFormat(String email) =>
      _emailRegex.hasMatch(email.trim());

  bool hasIdentifierAndPassword({
    required String identifier,
    required String password,
  }) {
    return identifier.trim().isNotEmpty && password.isNotEmpty;
  }

  Future<LoginResult> login({
    required String identifier,
    required String password,
  }) async {
    final trimmedId = identifier.trim();

    try {
      if (trimmedId.isEmpty || password.isEmpty) {
        return LoginResult(
          success: false,
          errorType: LoginErrorType.genericError,
          errorTitle: 'Missing information',
          errorMessage: 'Enter your email or phone and your password.',
        );
      }

      if (identifierLooksLikeEmail(trimmedId)) {
        if (!isValidEmailFormat(trimmedId)) {
          return LoginResult(
            success: false,
            errorType: LoginErrorType.genericError,
            errorTitle: 'Invalid email',
            errorMessage: 'Invalid email',
          );
        }
        await _authService.login(email: trimmedId, password: password);
      } else {
        final e164 = JordanPhone.normalize(trimmedId);
        if (e164 == null) {
          return LoginResult(
            success: false,
            errorType: LoginErrorType.genericError,
            errorTitle: 'Invalid Jordan phone number',
            errorMessage: 'Invalid Jordan phone number',
          );
        }

        final resolved = await _authService.resolveDonorEmailForPhoneLogin(
          e164,
        );
        if (resolved == null || resolved.isEmpty) {
          return LoginResult(
            success: false,
            errorType: LoginErrorType.userNotFound,
            errorTitle: 'Phone not registered',
            errorMessage:
                'No account found for this phone. Use the Jordan mobile on '
                'your profile (079/078/077 or 962…) or sign in with your email.',
          );
        }

        await _authService.login(email: resolved, password: password);
      }

      return await _finalizeAuthenticatedSession();
    } on FirebaseAuthException catch (e) {
      return LoginResult(
        success: false,
        errorType: LoginErrorType.authException,
        errorMessage: _authErrorMessage(e),
        errorTitle: _authErrorTitle(e),
      );
    } catch (e, _) {
      return _loginResultFromUnhandled(e);
    }
  }

  Future<LoginResult> _finalizeAuthenticatedSession() async {
    try {
      final isVerified = await _authService.isEmailVerified();
      if (!isVerified) {
        await _authService.logout();
        return LoginResult(
          success: false,
          errorType: LoginErrorType.emailNotVerified,
          errorMessage: 'Please verify your email before logging in.',
          errorTitle: 'Email verification required',
        );
      }

      final user = _authService.currentUser;
      if (user == null) {
        await _authService.logout();
        return LoginResult(
          success: false,
          errorType: LoginErrorType.userNotFound,
          errorTitle: 'Session error',
          errorMessage:
              'We could not load your account information. Please try again.',
        );
      }

      final profileCompleteFuture = _authService
          .completeProfileAfterVerification()
          .timeout(const Duration(seconds: 1))
          .then((_) => <String, dynamic>{})
          .catchError((_) => <String, dynamic>{});

      models.User? userData;
      for (var i = 0; i < 2; i++) {
        userData = await _authService.getUserData(user.uid);
        if (userData != null) break;
        if (i < 1) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }

      profileCompleteFuture.ignore();

      if (userData == null) {
        await _authService.logout();
        return LoginResult(
          success: false,
          errorType: LoginErrorType.profileNotReady,
          errorTitle: 'Profile not ready yet',
          errorMessage:
              'Your email is verified, but your profile is still being prepared. '
              'Please wait a few seconds and try logging in again.',
        );
      }

      final nav = _navigationResultForUser(userData);
      if (!nav.success) await _authService.logout();
      return nav;
    } catch (e, _) {
      await _authService.logout();
      return _loginResultFromUnhandled(e);
    }
  }

  LoginResult _navigationResultForUser(models.User userData) {
    if (userData.role == models.UserRole.donor) {
      return LoginResult(
        success: true,
        navigationRoute: const DonorDashboardScreen(),
      );
    } else if (userData.role == models.UserRole.hospital) {
      final bloodBankName = userData.bloodBankName ?? 'Blood Bank';
      final location = userData.location ?? 'Unknown';

      return LoginResult(
        success: true,
        navigationRoute: BloodBankDashboardScreen(
          bloodBankName: bloodBankName,
          location: location,
        ),
      );
    } else if (userData.role == models.UserRole.admin) {
      return LoginResult(
        success: true,
        navigationRoute: const AdminDashboardScreen(),
      );
    }

    return LoginResult(
      success: false,
      errorType: LoginErrorType.invalidAccountType,
      errorTitle: 'Invalid account',
      errorMessage:
          'Your account type is not set up correctly. Please contact support.',
    );
  }

  Future<ResendVerificationResult> resendVerification({
    required String identifier,
    required String password,
  }) async {
    try {
      final trimmedId = identifier.trim();

      if (trimmedId.isEmpty) {
        return ResendVerificationResult(
          success: false,
          errorTitle: 'Missing information',
          errorMessage: 'Enter your email or Jordan mobile.',
        );
      }

      if (password.isEmpty) {
        return ResendVerificationResult(
          success: false,
          errorTitle: 'Password required',
          errorMessage:
              'Enter your password so we can securely resend verification to your inbox.',
        );
      }

      late final String authEmail;

      if (identifierLooksLikeEmail(trimmedId)) {
        if (!isValidEmailFormat(trimmedId)) {
          return ResendVerificationResult(
            success: false,
            errorTitle: 'Invalid email',
            errorMessage: 'Invalid email',
          );
        }
        authEmail = trimmedId;
      } else {
        final e164 = JordanPhone.normalize(trimmedId);
        if (e164 == null) {
          return ResendVerificationResult(
            success: false,
            errorTitle: 'Invalid phone',
            errorMessage:
                'Enter a valid Jordan mobile (079, 078, 077 or 962…).',
          );
        }
        final resolved = await _authService.resolveDonorEmailForPhoneLogin(
          e164,
        );
        if (resolved == null || resolved.isEmpty) {
          return ResendVerificationResult(
            success: false,
            errorTitle: 'Phone not found',
            errorMessage:
                'No account uses this phone. Try your registration email or '
                'check the number (Jordan mobile: 079/078/077 or 962…).',
          );
        }
        authEmail = resolved;
      }

      await _authService.login(email: authEmail, password: password);

      await _authService.resendEmailVerification();

      await _authService.logout();

      return ResendVerificationResult(
        success: true,
        message:
            'We sent you a new verification email. Please check your inbox '
            'and verify your email before logging in.',
      );
    } on FirebaseAuthException catch (e) {
      return ResendVerificationResult(
        success: false,
        errorTitle: _resendVerificationErrorTitle(e),
        errorMessage: _resendVerificationErrorMessage(e),
      );
    } catch (e, _) {
      return ResendVerificationResult(
        success: false,
        errorTitle: 'Error',
        errorMessage:
            'Something went wrong while sending the verification email. Try again.',
      );
    }
  }

  /// Resolved email for "Forgot password" when [rawIdentifier] is email or donor phone.
  /// Returns `null` if unknown / invalid input or lookup fails.
  Future<String?> emailForForgotPassword(String rawIdentifier) async {
    final t = rawIdentifier.trim();
    if (t.isEmpty) return null;

    if (identifierLooksLikeEmail(t)) {
      return isValidEmailFormat(t) ? t : null;
    }

    final e164 = JordanPhone.normalize(t);
    if (e164 == null) return null;

    try {
      return await _authService.resolveDonorEmailForPhoneLogin(e164);
    } catch (_) {
      return null;
    }
  }

  LoginResult _loginResultFromUnhandled(Object e) {
    var errorStr = e.toString();
    var msg =
        'Something went wrong while logging you in. Please try again.';
    var title = 'Login failed';

    if (errorStr.contains('Exception: ')) {
      msg = errorStr.replaceFirst(RegExp(r'^.*?Exception:\s*'), '').trim();

      final lower = msg.toLowerCase();
      if (lower.contains('network') || lower.contains('connection')) {
        title = 'Connection error';
        msg =
            'Unable to connect to the server. Please check your internet '
            'connection and try again.';
      } else if (lower.contains('not found') || lower.contains('profile')) {
        title = 'Profile not found';
      } else if (lower.contains('permission')) {
        title = 'Permission denied';
      } else {
        title = 'Login error';
      }
    }

    return LoginResult(
      success: false,
      errorType: LoginErrorType.genericError,
      errorMessage: msg,
      errorTitle: title,
    );
  }

  static String _authErrorTitle(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Account not found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'Account disabled';
      case 'too-many-requests':
        return 'Too many attempts';
      case 'network-request-failed':
        return 'Network error';
      case 'operation-not-allowed':
        return 'Login disabled';
      case 'invalid-credential':
        return 'Invalid credentials';
      default:
        return 'Login failed';
    }
  }

  static String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address. Please check '
            'your email or create a new account.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Enter a correct email address (e.g., example@email.com).';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return 'Unable to connect. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Login is unavailable. Contact support.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return 'Unable to log in. Check your credentials and try again.';
    }
  }

  static String _resendVerificationErrorTitle(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Account not found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email';
      case 'too-many-requests':
        return 'Too many attempts';
      default:
        return 'Error';
    }
  }

  static String _resendVerificationErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account with this email. Check spelling or register.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'That email doesn\'t look valid.';
      case 'too-many-requests':
        return 'Too many requests. Wait before trying again.';
      default:
        return 'Unable to send verification email.';
    }
  }
}
