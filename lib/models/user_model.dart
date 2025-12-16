import 'package:flutter/foundation.dart';

/// Enum representing the different user roles in the system
enum UserRole {
  /// A blood donor user
  donor,

  /// A blood bank/hospital user
  hospital,
}

/// Model class representing a user in the system
/// Contains all user profile information for both donors and blood banks
@immutable
class User {
  /// Unique identifier from Firebase Authentication
  final String uid;

  /// User's email address
  final String email;

  /// Full name of the user (for donors)
  final String? fullName;

  /// Name of the blood bank (for hospital users)
  final String? bloodBankName;

  /// User's location
  final String? location;

  /// Blood type (for donors, e.g., 'A+', 'O-')
  final String? bloodType;

  /// URL to medical file/document (for donors)
  final String? medicalFileUrl;

  /// The role of the user (donor or hospital)
  final UserRole role;

  /// Timestamp when the user account was created
  final DateTime? createdAt;

  const User({
    required this.uid,
    required this.email,
    required this.role,
    this.fullName,
    this.bloodBankName,
    this.location,
    this.bloodType,
    this.medicalFileUrl,
    this.createdAt,
  });

  /// Factory constructor to create a [User] from Firestore data
  ///
  /// Converts a Firestore document map into a [User] object.
  /// Handles conversion of role string to [UserRole] enum and
  /// timestamp conversion.
  ///
  /// Parameters:
  /// - [data]: A [Map] containing the Firestore document data
  /// - [uid]: The user's unique identifier from Firebase Auth
  ///
  /// Returns:
  /// - A new [User] instance with data from Firestore
  factory User.fromMap(Map<String, dynamic> data, String uid) {
    final roleString = (data['role'] ?? '') as String;
    final role = roleString == 'hospital' ? UserRole.hospital : UserRole.donor;

    return User(
      uid: uid,
      email: (data['email'] ?? '') as String,
      role: role,
      fullName: data['fullName'] as String? ?? data['name'] as String?,
      bloodBankName: data['bloodBankName'] as String?,
      location: data['location'] as String?,
      bloodType: data['bloodType'] as String?,
      medicalFileUrl: data['medicalFileUrl'] as String?,
      createdAt: (data['createdAt'] as dynamic)?.toDate(),
    );
  }

  /// Converts the [User] to a Map for Firestore storage
  ///
  /// Serializes the [User] object into a format that can be
  /// saved to Firestore. Only includes non-null fields.
  ///
  /// Returns:
  /// - A [Map] containing all user data ready for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role == UserRole.hospital ? 'hospital' : 'donor',
      if (fullName != null) 'fullName': fullName,
      if (bloodBankName != null) 'bloodBankName': bloodBankName,
      if (location != null) 'location': location,
      if (bloodType != null) 'bloodType': bloodType,
      if (medicalFileUrl != null) 'medicalFileUrl': medicalFileUrl,
    };
  }
}
