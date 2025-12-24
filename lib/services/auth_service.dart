import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart' as models;

/// Service class for handling authentication operations
/// Manages user registration, login, logout, and user data retrieval
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;
        


  /// Signs up a new donor user
  ///
  /// Creates a new donor account in Firebase Authentication and stores
  /// additional donor information in Firestore.
  ///
  /// Parameters:
  /// - [fullName]: The donor's full name
  /// - [email]: The donor's email address
  /// - [password]: The donor's password (must be at least 6 characters)
  /// - [bloodType]: The donor's blood type (e.g., 'A+', 'O-')
  /// - [location]: The donor's location
  /// - [medicalFileUrl]: Optional URL to the donor's medical file
  ///
  /// Throws [FirebaseAuthException] if registration fails
  Future<void> signUpDonor({
    required String fullName,
    required String email,
    required String password,
    required String bloodType,
    required String location,
    String? medicalFileUrl,
  }) async {
    // 1) Create account in Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;

    // 2) Send email verification
    await cred.user!.sendEmailVerification();

    // 3) Save extra data in Firestore
    await _db.collection('users').doc(uid).set({
      'role': 'donor',
      'fullName': fullName.trim(),
      'name': fullName.trim(), // Keep for backward compatibility
      'email': email.trim(),
      'bloodType': bloodType,
      'location': location.trim(),
      'medicalFileUrl': medicalFileUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Signs up a new blood bank/hospital user
  ///
  /// Creates a new blood bank account in Firebase Authentication and stores
  /// additional blood bank information in Firestore.
  ///
  /// Parameters:
  /// - [bloodBankName]: The name of the blood bank/hospital
  /// - [email]: The blood bank's email address
  /// - [password]: The blood bank's password (must be at least 6 characters)
  /// - [location]: The blood bank's location
  ///
  /// Throws [FirebaseAuthException] if registration fails
  Future<void> signUpBloodBank({
    required String bloodBankName,
    required String email,
    required String password,
    required String location,
  }) async {
    // 1) Create account in Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;

    // 2) Send email verification
    await cred.user!.sendEmailVerification();

    // 3) Save extra data in Firestore
    await _db.collection('users').doc(uid).set({
      'role': 'hospital',
      'bloodBankName': bloodBankName.trim(),
      'email': email.trim(),
      'location': location.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Logs in a user with email and password
  ///
  /// Authenticates a user using Firebase Authentication.
  ///
  /// Parameters:
  /// - [email]: The user's email address
  /// - [password]: The user's password
  ///
  /// Throws [FirebaseAuthException] if login fails (e.g., wrong password, user not found)
  Future<void> login({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Logs out the current user
  ///
  /// Signs out the currently authenticated user from Firebase Authentication.
  /// This will clear the user's session.
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Gets the user role from Firestore
  ///
  /// Retrieves the role of a user from Firestore database.
  ///
  /// Parameters:
  /// - [uid]: The unique identifier of the user
  ///
  /// Returns:
  /// - A [String] representing the user's role ('donor' or 'hospital')
  /// - Returns empty string if role is not found
  Future<String> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    return (data?['role'] ?? '') as String;
  }

  /// Gets the current authenticated user
  ///
  /// Returns the currently signed-in Firebase Auth user, or null if no user is signed in.
  ///
  /// Returns:
  /// - [User] if a user is authenticated, null otherwise
  User? get currentUser => _auth.currentUser;

  /// Gets a stream of the current authentication state
  ///
  /// Returns a stream that emits the current Firebase Auth user whenever
  /// the authentication state changes (login, logout, token refresh).
  ///
  /// Returns:
  /// - A [Stream] of [User] objects that emits null when logged out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Gets user data from Firestore
  ///
  /// Retrieves complete user profile data from Firestore database.
  ///
  /// Parameters:
  /// - [uid]: The unique identifier of the user
  ///
  /// Returns:
  /// - [models.User] object containing all user data, or null if user not found
  Future<models.User?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return models.User.fromMap(doc.data()!, uid);
  }

  /// Resends email verification
  ///
  /// Sends a new verification email to the current user's email address.
  /// Only works if the user is logged in and their email is not already verified.
  ///
  /// Throws [FirebaseAuthException] if operation fails
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Checks if the current user's email is verified
  ///
  /// Reloads the current user's data and checks if their email has been verified.
  ///
  /// Returns:
  /// - [true] if the user's email is verified, [false] otherwise
  /// - Returns [false] if no user is currently signed in
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }
}
