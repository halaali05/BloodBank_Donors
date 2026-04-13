/// User type selection for registration
enum UserType { donor, bloodBank }

/// Result of registration operation
class RegisterResult {
  final bool success;
  final bool emailVerified;
  final String? message;
  final String? errorTitle;
  final String? errorMessage;

  RegisterResult({
    required this.success,
    this.emailVerified = false,
    this.message,
    this.errorTitle,
    this.errorMessage,
  });
}
