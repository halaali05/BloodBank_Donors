import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/register_models.dart';

/// Controller for handling registration business logic
/// Separates business logic from UI for better maintainability
class RegisterController {
  final AuthService _authService;

  RegisterController({AuthService? authService})
    : _authService = authService ?? AuthService();

  // ------------------ Validation ------------------
  /// Validates email format using regex
  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Validates registration form based on user type
  ///
  /// Parameters:
  /// - [name]: Required for donor registration (full name)
  /// - [bloodBankName]: Required for blood bank registration (blood bank name)
  /// - [location]: Required for both user types
  ///
  /// Returns validation error message or null if valid
  String? validateForm({
    required UserType userType,
    required String email,
    required String password,
    required String confirmPassword,
    String? name, // Donor's full name
    String? bloodBankName, // Blood bank's name
    String? location,
  }) {
    if (email.isEmpty || password.isEmpty) {
      return 'Please enter both email and password.';
    }

    if (!isValidEmail(email)) {
      return 'Please enter a valid email address.';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    if (password != confirmPassword) {
      return 'The passwords do not match. Please try again.';
    }

    if (userType == UserType.donor) {
      if (name == null || name.trim().isEmpty) {
        return 'Please enter your full name.';
      }
      if (location == null || location.isEmpty) {
        return 'Please select your location.';
      }
    } else {
      // Blood bank registration
      if (bloodBankName == null || bloodBankName.trim().isEmpty) {
        return 'Please enter the blood bank name.';
      }
      if (location == null || location.isEmpty) {
        return 'Please select the blood bank location.';
      }
    }

    return null; // Valid
  }

  // ------------------ Registration Logic ------------------
  /// Handles user registration
  ///
  /// Security Architecture:
  /// - All database operations go through Cloud Functions (server-side)
  /// - No direct Firestore access from client
  ///
  /// Returns RegisterResult with success status and email verification status
  Future<RegisterResult> register({
    required UserType userType,
    required String email,
    required String password,
    String? name,
    String? bloodBankName,
    required String location,
  }) async {
    try {
      Map<String, dynamic> result;

      if (userType == UserType.donor) {
        if (name == null || name.trim().isEmpty) {
          return RegisterResult(
            success: false,
            errorTitle: 'Missing name',
            errorMessage: 'Please enter your full name.',
          );
        }

        result = await _authService.signUpDonor(
          fullName: name.trim(),
          email: email.trim(),
          password: password,
          location: location,
        );
      } else {
        // Blood bank registration
        if (bloodBankName == null || bloodBankName.trim().isEmpty) {
          return RegisterResult(
            success: false,
            errorTitle: 'Missing blood bank name',
            errorMessage: 'Please enter the blood bank name.',
          );
        }

        result = await _authService.signUpBloodBank(
          bloodBankName: bloodBankName.trim(),
          email: email.trim(),
          password: password,
          location: location,
        );
      }

      final emailVerified = result['emailVerified'] ?? false;

      return RegisterResult(
        success: true,
        emailVerified: emailVerified,
        message: emailVerified
            ? 'Your account has been created successfully. You can now log in.'
            : 'We sent you a verification email. Please check your inbox and click the link to verify your email.',
      );
    } on FirebaseAuthException catch (e) {
      return RegisterResult(
        success: false,
        errorTitle: _getAuthErrorTitle(e),
        errorMessage: _getAuthErrorMessage(e),
      );
    } catch (e) {
      // Handle Cloud Function errors or other exceptions
      final errorStr = e.toString();
      String errorMessage =
          'Something went wrong while creating your account. Please try again.';
      String errorTitle = 'Sign up failed';

      if (errorStr.contains('fullName is required') ||
          errorStr.contains('location is required') ||
          errorStr.contains('Full name is required') ||
          errorStr.contains('Location is required')) {
        errorTitle = 'Missing information';
        errorMessage =
            'Please fill in all required fields (name and location).';
      } else if (errorStr.contains('bloodType is required') ||
          errorStr.contains('blood type')) {
        errorTitle = 'Registration error';
        errorMessage =
            'There was an issue with account creation. Please try again or contact support.';
      } else if (errorStr.contains('network') ||
          errorStr.contains('connection')) {
        errorTitle = 'Connection error';
        errorMessage =
            'Unable to connect to the server. Please check your internet connection.';
      } else if (errorStr.contains('Exception: ')) {
        errorMessage = errorStr.replaceFirst('Exception: ', '').trim();
      } else if (errorStr.contains('invalid-argument')) {
        errorTitle = 'Invalid information';
        errorMessage =
            'Please check that all required fields are filled correctly.';
      }

      return RegisterResult(
        success: false,
        errorTitle: errorTitle,
        errorMessage: errorMessage,
      );
    }
  }

  // ------------------ Error Message Helpers ------------------
  String _getAuthErrorTitle(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'network-request-failed':
        return 'Network error';
      case 'too-many-requests':
        return 'Too many requests';
      default:
        return 'Registration failed';
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email address is already registered. Try logging in.';
      case 'weak-password':
        return 'Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a correct email.';
      case 'network-request-failed':
        return 'Check your internet and try again.';
      case 'too-many-requests':
        return 'Too many registration attempts. Please wait a few minutes and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
