import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart' as models;
import 'cloud_functions_service.dart';

/// Custom exception for signup failures
class SignupException implements Exception {
  final String message;
  final bool shouldDeleteAuthAccount;

  SignupException(this.message, {this.shouldDeleteAuthAccount = false});

  @override
  String toString() => message;
}

/// Service class for handling authentication operations
/// Uses Firebase Auth for authentication and Cloud Functions as API layer for Firestore access.
class AuthService {
  final FirebaseAuth _auth;
  final CloudFunctionsService _cloudFunctions;

  AuthService({FirebaseAuth? auth, CloudFunctionsService? cloudFunctions})
      : _auth = auth ?? FirebaseAuth.instance,
        _cloudFunctions = cloudFunctions ?? CloudFunctionsService();

  /// Signs up a new donor user
  ///
  /// Flow:
  /// 1) Create user in Firebase Auth
  /// 2) Call Cloud Function to create pending profile (pending_profiles/{uid})
  /// 3) Send email verification (only if Cloud Function succeeds)
  ///
  /// Returns: { emailVerified: bool, message: String }
  Future<Map<String, dynamic>> signUpDonor({
    required String fullName,
    required String email,
    required String password,
    required String bloodType,
    required String location,
    String? medicalFileUrl,
  }) async {
    UserCredential cred;

    try {
      // 1) Create account in Firebase Auth
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Ensure token exists for callable auth
      await cred.user!.reload();
      await cred.user!.getIdToken(true); // force refresh

      // 2) Save pending profile FIRST (before sending email)
      print('Calling createPendingProfile Cloud Function...');
      print('  Role: donor');
      print('  FullName: $fullName');
      print('  BloodType: $bloodType');
      print('  Location: $location');
      print('  User UID: ${cred.user!.uid}');
      print('  User authenticated: ${_auth.currentUser != null}');

      final result = await _cloudFunctions.createPendingProfile(
        role: 'donor',
        fullName: fullName,
        bloodType: bloodType,
        location: location,
        medicalFileUrl: medicalFileUrl,
      );

      print('createPendingProfile succeeded: $result');

      // 3) Send verification email ONLY if Cloud Function succeeded
      await cred.user!.sendEmailVerification();

      return {
        'emailVerified': result['emailVerified'] ?? false,
        'message': result['message'] ?? 'Verification email sent',
      };
    } catch (e) {
      print('❌ Error in signUpDonor: $e');
      print('  Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Signs up a new blood bank/hospital user
  ///
  /// Flow:
  /// 1) Create user in Firebase Auth
  /// 2) Call Cloud Function to create pending profile (pending_profiles/{uid})
  /// 3) Send email verification (only if Cloud Function succeeds)
  ///
  /// Returns: { emailVerified: bool, message: String }
  Future<Map<String, dynamic>> signUpBloodBank({
    required String bloodBankName,
    required String email,
    required String password,
    required String location,
  }) async {
    UserCredential cred;

    try {
      // 1) Create account in Firebase Auth
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Ensure token exists for callable auth
      await cred.user!.reload();
      await cred.user!.getIdToken(true); // force refresh

      // 2) Save pending profile FIRST (before sending email)
      print('Calling createPendingProfile Cloud Function...');
      print('  Role: hospital');
      print('  BloodBankName: $bloodBankName');
      print('  Location: $location');
      print('  User UID: ${cred.user!.uid}');
      print('  User authenticated: ${_auth.currentUser != null}');

      final result = await _cloudFunctions.createPendingProfile(
        role: 'hospital',
        bloodBankName: bloodBankName,
        location: location,
      );

      print('createPendingProfile succeeded: $result');

      // 3) Send verification email ONLY if Cloud Function succeeded
      await cred.user!.sendEmailVerification();

      final emailVerified = result['emailVerified'] ?? false;
      return {
        'emailVerified': emailVerified,
        'message': result['message'] ?? 'Verification email sent',
      };
    } catch (e) {
      print('❌ Error in signUpBloodBank: $e');
      print('  Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Logs in a user with email and password
  Future<void> login({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Logs out the current user
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Gets the user role from Firestore via Cloud Functions
  Future<String> getUserRole([String? uid]) async {
    return await _cloudFunctions.getUserRole(uid: uid);
  }

  /// Gets the current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Authentication state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Gets user data from Firestore via Cloud Functions
  Future<models.User?> getUserData([String? uid]) async {
  try {
    final data = await _cloudFunctions.getUserData(uid: uid);
    final userUid = data['uid'] as String? ?? uid ?? _auth.currentUser?.uid;
    if (userUid == null) return null;

    return models.User.fromMap(
      Map<String, dynamic>.from(data)..remove('uid'),
      userUid,
    );
  } catch (e) {
    print('❌ getUserData failed: $e');
    return null;
  }
}


  /// Resends email verification
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Checks if current user's email is verified (reloads user)
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Completes profile creation after email verification
  ///
  /// Calls Cloud Function to move pending_profiles/{uid} -> users/{uid}
  Future<Map<String, dynamic>> completeProfileAfterVerification() async {
    final isVerified = await isEmailVerified();
    if (!isVerified) {
      throw Exception(
        'Email is not verified yet. Please verify your email first.',
      );
    }

    return await _cloudFunctions.completeProfileAfterVerification();
  }
}
