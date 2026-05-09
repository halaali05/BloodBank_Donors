import 'package:flutter/foundation.dart';

/// Enum representing the different user roles in the system
enum UserRole {
  /// A blood donor user
  donor,

  /// A blood bank/hospital user
  hospital,

  /// System administrator
  admin,
}

/// Safely parse date values coming from Cloud Functions / Firestore.
DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  try {
    // ignore: avoid_dynamic_calls
    final dt = v.toDate();
    if (dt is DateTime) return dt;
  } catch (_) {}
  if (v is Map && v.containsKey('_seconds')) {
    final seconds = v['_seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
  }
  return null;
}

/// Model class representing a user in the system
@immutable
class User {
  final String uid;
  final String email;
  final String? fullName;
  final String? bloodBankName;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? bloodType;
  final String? gender;
  final DateTime? nextDonationEligibleAt;
  final DateTime? lastDonatedAt;
  final DateTime? restrictedUntil;
  final bool isPermanentlyBlocked;
  final String? phoneNumber;
  final UserRole role;
  final DateTime? createdAt;

  /// ← جديد: هل تم الموافقة على حساب بنك الدم من الأدمن؟
  /// null = مش hospital أو مش مطلوب، false = ينتظر، true = موافق عليه
  final bool? isApproved;

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
    this.nextDonationEligibleAt,
    this.lastDonatedAt,
    this.restrictedUntil,
    this.isPermanentlyBlocked = false,
    this.phoneNumber,
    this.createdAt,
    this.isApproved, // ← جديد
  });

  /// Factory constructor to create a [User] from Firestore/Functions data
  factory User.fromMap(Map<String, dynamic> data, String uid) {
    final roleString = (data['role'] ?? '') as String;
    final role = roleString == 'hospital'
        ? UserRole.hospital
        : roleString == 'admin'
        ? UserRole.admin
        : UserRole.donor;

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
      nextDonationEligibleAt: _parseDate(data['nextDonationEligibleAt']),
      lastDonatedAt: _parseDate(data['lastDonatedAt']),
      restrictedUntil: _parseDate(data['restrictedUntil']),
      isPermanentlyBlocked: data['isPermanentlyBlocked'] == true,
      phoneNumber: data['phoneNumber'] as String?,
      createdAt: _parseDate(data['createdAt']),
      isApproved: data['isApproved'] as bool?, // ← جديد
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
      if (isApproved != null) 'isApproved': isApproved, // ← جديد
    };
  }
}
