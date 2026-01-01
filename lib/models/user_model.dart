import 'package:flutter/foundation.dart';

/// Enum representing the different user roles in the system
enum UserRole {
  /// A blood donor user
  donor,

  /// A blood bank/hospital user
  hospital,
}

/// Safely parse date values coming from Cloud Functions / Firestore.
/// Accepts:
/// - int (millisecondsSinceEpoch)
/// - String (ISO-8601)
/// - DateTime
/// - Firestore Timestamp (has toDate())
/// - Map like {_seconds: ..., _nanoseconds: ...}
DateTime? _parseDate(dynamic v) {
  if (v == null) return null;

  if (v is DateTime) return v;

  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v);
  }

  if (v is String) {
    return DateTime.tryParse(v);
  }

  // Firestore Timestamp (cloud_firestore) or any object with toDate()
  try {
    // ignore: avoid_dynamic_calls
    final dt = v.toDate();
    if (dt is DateTime) return dt;
  } catch (_) {}

  // Sometimes timestamps come as a Map: {_seconds: ..., _nanoseconds: ...}
  if (v is Map && v.containsKey('_seconds')) {
    final seconds = v['_seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
  }

  return null;
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

  /// Factory constructor to create a [User] from Firestore/Functions data
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
      createdAt: _parseDate(data['createdAt']),
    );
  }

  /// Converts the [User] to a Map for Firestore storage
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
