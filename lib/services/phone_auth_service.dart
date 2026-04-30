import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Sends SMS OTP to **link** phone to the current Firebase user (donor onboarding).
class PhoneAuthService {
  PhoneAuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  String? _linkVerificationId;
  int? _linkResendToken;

  String? get linkVerificationId => _linkVerificationId;

  bool get hasPendingLinkVerification => _linkVerificationId != null;

  /// Sends an OTP to link [phoneNumber] (E.164) to [FirebaseAuth.currentUser].
  Future<void> sendSmsOtpToLinkCurrentUser({
    required String phoneNumber,
    required VoidCallback onCodeSent,
    required void Function(FirebaseAuthException exception) onVerificationFailed,
    void Function(UserCredential credential)? onAutoLinked,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final normalizedPhone = phoneNumber.trim();
    if (!_isInternationalPhoneNumber(normalizedPhone)) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message:
            'Phone number must be in international format, e.g. +962791234567.',
      );
    }

    if (_firebaseAuth.currentUser == null) {
      onVerificationFailed(
        FirebaseAuthException(
          code: 'no-current-user',
          message: 'Session expired. Please sign up again or log in.',
        ),
      );
      return;
    }

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      timeout: timeout,
      forceResendingToken: _linkResendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _performLinkAuto(
          credential: credential,
          onVerificationFailed: onVerificationFailed,
          onLinked: onAutoLinked,
        );
      },
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        _linkVerificationId = verificationId;
        _linkResendToken = resendToken;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _linkVerificationId = verificationId;
        debugPrint('Phone auth auto-retrieval timed out.');
      },
    );
  }

  Future<void> _performLinkAuto({
    required PhoneAuthCredential credential,
    required void Function(FirebaseAuthException exception) onVerificationFailed,
    void Function(UserCredential credential)? onLinked,
  }) async {
    try {
      final current = _firebaseAuth.currentUser;
      if (current == null) {
        onVerificationFailed(
          FirebaseAuthException(
            code: 'no-current-user',
            message: 'Session expired. Please sign up again.',
          ),
        );
        return;
      }
      final uc = await current.linkWithCredential(credential);
      onLinked?.call(uc);
    } on FirebaseAuthException catch (e) {
      onVerificationFailed(e);
    } catch (e) {
      debugPrint('Automatic phone linking failed: $e');
      onVerificationFailed(
        FirebaseAuthException(
          code: 'auto-verification-failed',
          message:
              'Automatic verification failed. Please enter the OTP manually.',
        ),
      );
    }
  }

  /// Confirms OTP and links the phone credential to [FirebaseAuth.currentUser].
  Future<UserCredential> verifyOtpAndLink({required String smsCode}) async {
    final currentVerificationId = _linkVerificationId;
    if (currentVerificationId == null || currentVerificationId.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Please request an OTP before verifying.',
      );
    }

    final cleanedCode = smsCode.trim();
    if (cleanedCode.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-verification-code',
        message: 'Please enter the OTP code.',
      );
    }

    final current = _firebaseAuth.currentUser;
    if (current == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Session expired. Please sign up again.',
      );
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: currentVerificationId,
      smsCode: cleanedCode,
    );

    final uc = await current.linkWithCredential(credential);

    _linkVerificationId = null;
    _linkResendToken = null;

    return uc;
  }

  bool _isInternationalPhoneNumber(String value) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
  }
}
