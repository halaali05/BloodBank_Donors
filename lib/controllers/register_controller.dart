import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/register_models.dart';
import '../shared/theme/app_theme.dart';
import '../shared/utils/jordan_phone.dart';

/// Sign-up: form validation ([validateForm]) and donor vs hospital registration.
///
/// Use [submitRegistration] from UI so validation and `_authService` calls stay in one place.
/// [validateForm] remains available for live checks or previews.
class RegisterController {
  final AuthService _authService;

  RegisterController({AuthService? authService})
    : _authService = authService ?? AuthService();

  // --- Checks ---

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Shared rules for donor vs hospital forms. Returns a user-visible error or null when OK.
  String? validateForm({
    required UserType userType,
    required String email,
    required String password,
    required String confirmPassword,
    String? name, // Donor's full name
    String? donorGender, // 'male' | 'female'
    String? donorPhoneRaw,
    String? bloodBankName, // Blood bank's name
    String? location,
    bool bloodBankHasMapPin = false,
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
      if (donorGender == null ||
          (donorGender != 'male' && donorGender != 'female')) {
        return 'Please select your gender (male or female).';
      }
      final phoneMsg = JordanPhone.validationMessage(donorPhoneRaw ?? '');
      if (phoneMsg != null) return phoneMsg;
      if (location == null || location.isEmpty) {
        return 'Please select your location.';
      }
    } else {
      // Blood bank registration
      if (bloodBankName == null || bloodBankName.trim().isEmpty) {
        return 'Please enter the blood bank name.';
      }
      if (!bloodBankHasMapPin) {
        return 'Please pin the hospital location on the map.';
      }
    }

    return null; // Valid
  }

  /// Donor onboarding: OTP field must be non-empty before [PhoneAuthService.verifyOtpAndLink].
  String? validationErrorForSmsOtp(String otp) =>
      otp.trim().isEmpty ? 'Please enter the SMS verification code.' : null;

  // --- Submit (UI entry) ---

  /// Validates, then registers. On validation failure returns
  /// [RegisterResult.success] == false without calling Firebase.
  Future<RegisterResult> submitRegistration({
    required UserType userType,
    required String email,
    required String password,
    required String confirmPassword,
    String? donorFullName,
    String? donorGender,
    String? donorPhoneRaw,
    String? bloodBankName,
    String? locationGovernorateLabel,
    bool bloodBankHasMapPin = false,
    double? exactLatitude,
    double? exactLongitude,
  }) async {
    final validationError = validateForm(
      userType: userType,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      name: userType == UserType.donor ? donorFullName : null,
      donorGender: userType == UserType.donor ? donorGender : null,
      donorPhoneRaw: userType == UserType.donor ? donorPhoneRaw : null,
      bloodBankName: userType == UserType.bloodBank ? bloodBankName : null,
      location: locationGovernorateLabel,
      bloodBankHasMapPin: bloodBankHasMapPin,
    );

    if (validationError != null) {
      return RegisterResult(
        success: false,
        errorTitle: 'Missing information',
        errorMessage: validationError,
      );
    }

    final donorLocation = userType == UserType.donor
        ? locationGovernorateLabel!.trim()
        : (locationGovernorateLabel ?? '').trim();

    return _executeRegistration(
      userType: userType,
      email: email.trim(),
      password: password,
      name: userType == UserType.donor ? donorFullName!.trim() : null,
      donorGender: donorGender,
      donorPhoneRaw: donorPhoneRaw,
      bloodBankName: userType == UserType.bloodBank
          ? bloodBankName!.trim()
          : null,
      location: donorLocation,
      exactLatitude: userType == UserType.bloodBank ? exactLatitude : null,
      exactLongitude: userType == UserType.bloodBank ? exactLongitude : null,
    );
  }

  // --- Backend sign-up ([validateForm] must already have passed) ---

  Future<RegisterResult> _executeRegistration({
    required UserType userType,
    required String email,
    required String password,
    String? name,
    String? donorGender,
    String? donorPhoneRaw,
    String? bloodBankName,
    required String location,
    double? exactLatitude,
    double? exactLongitude,
  }) async {
    try {
      Map<String, dynamic> result;

      // Prefer exact map coordinates; otherwise fall back to governorate centroid.
      final double? lat = exactLatitude ?? AppTheme.getLatitude(location);
      final double? lng = exactLongitude ?? AppTheme.getLongitude(location);

      if (userType == UserType.donor) {
        final phoneNorm = JordanPhone.normalize(donorPhoneRaw?.trim() ?? '');
        if (phoneNorm == null) {
          return RegisterResult(
            success: false,
            errorTitle: 'Invalid phone number',
            errorMessage:
                'Enter a valid Jordan mobile number (e.g. 0791234567 or +962791234567).',
          );
        }

        result = await _authService.signUpDonor(
          fullName: name!.trim(),
          email: email.trim(),
          password: password,
          location: location,
          gender: donorGender!,
          phoneNumber: phoneNorm,
          latitude: lat,
          longitude: lng,
        );
      } else {
        result = await _authService.signUpBloodBank(
          bloodBankName: bloodBankName!.trim(),
          email: email.trim(),
          password: password,
          location: location,
          latitude: lat,
          longitude: lng,
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
      } else if (errorStr.contains('gender must be') ||
          errorStr.contains('phoneNumber must be')) {
        errorTitle = 'Invalid information';
        errorMessage =
            'Please check gender and Jordan mobile number format, then try again.';
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
      } else if (errorStr.contains('invalid-argument')) {
        errorTitle = 'Invalid information';
        errorMessage =
            'Please check that all required fields are filled correctly.';
      } else if (errorStr.contains('Exception: ')) {
        errorMessage = errorStr.replaceFirst('Exception: ', '').trim();
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
    if (firebaseAuthIndicatesDeviceThrottle(e)) {
      return 'Too many verification attempts';
    }
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
    if (firebaseAuthIndicatesDeviceThrottle(e)) {
      return firebaseAuthDeviceThrottleUserMessage();
    }
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
        return firebaseAuthDeviceThrottleUserMessage();
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

/// Firebase anti-abuse: too many SMS or sign-ups from one device/IP.
bool firebaseAuthIndicatesDeviceThrottle(FirebaseAuthException e) {
  final msg = e.message?.toLowerCase() ?? '';
  return e.code == 'too-many-requests' ||
      (msg.contains('blocked') && msg.contains('device')) ||
      msg.contains('unusual activity');
}

/// Plain-language copy for [firebaseAuthIndicatesDeviceThrottle].
String firebaseAuthDeviceThrottleUserMessage() {
  return 'Firebase is temporarily blocking more verification requests from this '
      'phone or network because too many sign-in or SMS attempts happened '
      'recently. That is automatic protection, not a wrong password.\n\n'
      'Wait a few hours, try another network (mobile data vs Wi‑Fi), or open '
      'your email and complete inbox verification first—you can finish SMS '
      'later. For testing, add numbers under Firebase Console → Authentication '
      '→ Sign-in method → Phone.';
}
