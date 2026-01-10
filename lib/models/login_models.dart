import 'package:flutter/material.dart';

/// Types of login errors
enum LoginErrorType {
  emailNotVerified,
  userNotFound,
  profileNotReady,
  invalidAccountType,
  authException,
  genericError,
}

/// Result of login operation
class LoginResult {
  final bool success;
  final Widget? navigationRoute;
  final LoginErrorType? errorType;
  final String? errorMessage;
  final String? errorTitle;

  LoginResult({
    required this.success,
    this.navigationRoute,
    this.errorType,
    this.errorMessage,
    this.errorTitle,
  });
}

/// Result of resend verification operation
class ResendVerificationResult {
  final bool success;
  final String? message;
  final String? errorTitle;
  final String? errorMessage;

  ResendVerificationResult({
    required this.success,
    this.message,
    this.errorTitle,
    this.errorMessage,
  });
}
