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

  /// User's location (governorate name)
  final String? location;

  /// Latitude coordinate of the user's location (auto-set from governorate)
  final double? latitude;

  /// Longitude coordinate of the user's location (auto-set from governorate)
  final double? longitude;

  /// Blood type (for donors, e.g., 'A+', 'O-')
  final String? bloodType;

  /// Donor gender: `male` or `female` (from registration).
  final String? gender;

  /// Donor mobile in E.164 (e.g. +962791234567).
  final String? phoneNumber;

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
    this.latitude,
    this.longitude,
    this.bloodType,
    this.gender,
    this.phoneNumber,
    this.createdAt,
  });

  /// Factory constructor to create a [User] from Firestore/Functions data
  factory User.fromMap(Map<String, dynamic> data, String uid) {
    final roleString = (data['role'] ?? '') as String;
    final role = roleString == 'hospital' ? UserRole.hospital : UserRole.donor;

    // Parse latitude/longitude - may come as int or double from Firestore
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return User(
      uid: uid,
      email: (data['email'] ?? '') as String,
      role: role,
      fullName: data['fullName'] as String? ?? data['name'] as String?,
      bloodBankName: data['bloodBankName'] as String?,
      location: data['location'] as String?,
      latitude: parseDouble(data['latitude']),
      longitude: parseDouble(data['longitude']),
      bloodType: data['bloodType'] as String?,
      gender: data['gender'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
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
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (bloodType != null) 'bloodType': bloodType,
      if (gender != null) 'gender': gender,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };
  }
}
