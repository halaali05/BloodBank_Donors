import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as models;
import '../models/login_models.dart';
import '../screens/donor_dashboard_screen.dart';
import '../screens/blood_bank_dashboard_screen.dart';

/// Controller for handling login business logic
/// Separates business logic from UI for better maintainability
class LoginController {
  final AuthService _authService;

  LoginController({AuthService? authService})
    : _authService = authService ?? AuthService();

  // ------------------ Input Validation ------------------
  /// Validates email and password input
  /// Returns true if valid, false otherwise
  bool validateInput(String email, String password) {
    return email.trim().isNotEmpty && password.isNotEmpty;
  }

  // ------------------ Login Logic ------------------
  /// Main login function that handles user authentication
  ///
  /// Security Architecture:
  /// - All database operations go through Cloud Functions (server-side)
  /// - No direct Firestore access from client
  /// - Email verification required before profile access
  ///
  /// Returns LoginResult with success status and navigation data or error
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Authenticate user with Firebase
      await _authService.login(email: email, password: password);

      // Step 2: Check if email is verified (required for login)
      // This check is performed server-side via Firebase Auth
      final isVerified = await _authService.isEmailVerified();
      if (!isVerified) {
        await _authService.logout();
        return LoginResult(
          success: false,
          errorType: LoginErrorType.emailNotVerified,
          errorMessage: 'Please verify your email before logging in.',
        );
      }

      // Step 3: Get the authenticated user
      final user = _authService.currentUser;
      if (user == null) {
        await _authService.logout();
        return LoginResult(
          success: false,
          errorType: LoginErrorType.userNotFound,
          errorMessage:
              'We could not load your account information. Please try again.',
        );
      }

      // Step 4 & 5: Run profile completion and user data fetch in parallel for faster login
      // Complete profile creation if needed (non-blocking, fast timeout)
      // This moves data from pending_profiles to users collection via Cloud Function
      // All database operations are server-side for security
      final profileCompleteFuture = _authService
          .completeProfileAfterVerification()
          .timeout(const Duration(seconds: 1))
          .then((_) => <String, dynamic>{})
          .catchError(
            (e) => <String, dynamic>{},
          ); // Ignore errors, profile may already be complete

      // Fetch user profile via Cloud Function (server-side)
      // Optimized retry with shorter delays for faster login
      models.User? userData;
      for (int i = 0; i < 2; i++) {
        userData = await _authService.getUserData(user.uid);
        if (userData != null) break;
        // Shorter delay for faster login
        if (i < 1) await Future.delayed(const Duration(milliseconds: 300));
      }

      // Don't wait for profile completion - it's non-critical and runs in background
      profileCompleteFuture.ignore();

      if (userData == null) {
        await _authService.logout();
        return LoginResult(
          success: false,
          errorType: LoginErrorType.profileNotReady,
          errorMessage:
              'Your email is verified, but your profile is still being prepared. '
              'Please wait a few seconds and try logging in again.',
        );
      }

      // Step 6: Return success with navigation data
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
      } else {
        await _authService.logout();
        return LoginResult(
          success: false,
          errorType: LoginErrorType.invalidAccountType,
          errorMessage:
              'Your account type is not set up correctly. Please contact support.',
        );
      }
    } on FirebaseAuthException catch (e) {
      return LoginResult(
        success: false,
        errorType: LoginErrorType.authException,
        errorMessage: _getAuthErrorMessage(e),
        errorTitle: _getAuthErrorTitle(e),
      );
    } catch (e) {
      // Handle Cloud Function errors or other exceptions
      String errorStr = e.toString();
      String errorMessage =
          'Something went wrong while logging you in. Please try again.';
      String errorTitle = 'Login failed';

      if (errorStr.contains('Exception: ')) {
        errorMessage = errorStr.replaceFirst('Exception: ', '').trim();

        // Map common errors to specific titles
        if (errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('connection')) {
          errorTitle = 'Connection error';
          errorMessage =
              'Unable to connect to the server. Please check your internet connection and try again.';
        } else if (errorMessage.toLowerCase().contains('not found') ||
            errorMessage.toLowerCase().contains('profile')) {
          errorTitle = 'Profile not found';
        } else if (errorMessage.toLowerCase().contains('permission')) {
          errorTitle = 'Permission denied';
        } else {
          errorTitle = 'Login error';
        }
      } else {
        errorTitle = 'Connection error';
        errorMessage =
            'Unable to connect to the server. Please check your internet connection and try again.';
      }

      return LoginResult(
        success: false,
        errorType: LoginErrorType.genericError,
        errorMessage: errorMessage,
        errorTitle: errorTitle,
      );
    }
  }

  // ------------------ Resend Verification Logic ------------------
  /// Resends email verification link
  ///
  /// SECURITY: All operations go through Firebase Auth and Cloud Functions
  /// No direct Firestore access from client side
  ///
  /// Returns ResendVerificationResult with success status or error
  Future<ResendVerificationResult> resendVerification({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Authenticate user (this works even if email not verified)
      // Firebase Auth allows sign-in with unverified emails
      await _authService.login(email: email, password: password);

      // Step 2: Send verification email (same method used during registration)
      // This is handled server-side by Firebase Auth
      await _authService.resendEmailVerification();

      // Step 3: Log out (user must verify email before full login)
      await _authService.logout();

      return ResendVerificationResult(
        success: true,
        message:
            'We sent you a new verification email. Please check your inbox and verify your email before logging in.',
      );
    } on FirebaseAuthException catch (e) {
      return ResendVerificationResult(
        success: false,
        errorTitle: _getResendVerificationErrorTitle(e),
        errorMessage: _getResendVerificationErrorMessage(e),
      );
    } catch (e) {
      return ResendVerificationResult(
        success: false,
        errorTitle: 'Error',
        errorMessage:
            'Something went wrong while sending the verification email. Please try again.',
      );
    }
  }

  // ------------------ Error Message Helpers ------------------
  String _getAuthErrorTitle(FirebaseAuthException e) {
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

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address. Please check your email or create a new account.';
      case 'wrong-password':
        return 'The password you entered is incorrect. Please check your password and try again.';
      case 'invalid-email':
        return 'The email address you entered is not valid. Please check and enter a correct email address (e.g., example@email.com).';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support for assistance.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a few minutes before trying again.';
      case 'network-request-failed':
        return 'Unable to connect to the server. Please check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password login is currently not available. Please contact support.';
      case 'invalid-credential':
        return 'The email or password you entered is incorrect. Please check your credentials and try again.';
      default:
        return 'Unable to log in. Please check your email and password and try again.';
    }
  }

  String _getResendVerificationErrorTitle(FirebaseAuthException e) {
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

  String _getResendVerificationErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address. Please check your email or create a new account.';
      case 'wrong-password':
        return 'The password you entered is incorrect. Please check your password and try again.';
      case 'invalid-email':
        return 'The email address you entered is not valid.';
      case 'too-many-requests':
        return 'Too many requests. Please wait a few minutes before requesting another verification email.';
      default:
        return 'Unable to send verification email. Please try again.';
    }
  }
}
