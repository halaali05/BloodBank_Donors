import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Turns thrown values into short, safe UI copy (never stack traces).
class ErrorMessageHelper {
  ErrorMessageHelper._();

  static String humanize(Object error) {
    if (error is FirebaseAuthException) {
      return _authMessage(error);
    }
    if (error is FirebaseFunctionsException) {
      final m = error.message?.trim();
      if (m != null && m.isNotEmpty) return _trimForUi(m);
      return 'Something went wrong. Try again.';
    }

    if (error is FirebaseException) {
      final m = error.message?.trim();
      if (m != null && m.isNotEmpty && m.length < 120) {
        return _trimForUi(m);
      }
      return _firebaseStorageCodeMessage(error.code);
    }

    final raw = error.toString().trim();
    final stripped = raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
    final lower = stripped.toLowerCase();

    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('failed host lookup') ||
        lower.contains('timeout')) {
      return 'Network problem. Check your connection and try again.';
    }

    if (stripped.isEmpty) return 'Something went wrong. Try again.';
    return _trimForUi(stripped);
  }

  static String _trimForUi(String message) {
    const max = 180;
    if (message.length <= max) return message;
    final cut = message.substring(0, max).trimRight();
    return '$cut…';
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Account not found. Check email or phone, or register.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Try again or reset.';
      case 'invalid-email':
        return 'That email doesn’t look valid.';
      case 'user-disabled':
        return 'This account is disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Wait and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method isn’t available.';
      case 'network-request-failed':
      case 'internal-error':
      default:
        return 'Sign-in didn’t complete. Try again.';
    }
  }

  static String _firebaseStorageCodeMessage(String code) {
    final c = code.toLowerCase();
    if (c.contains('unauthorized') || c.contains('permission')) {
      return 'Upload blocked. Check your connection or try again later.';
    }
    return 'Upload failed. Try again.';
  }
}
