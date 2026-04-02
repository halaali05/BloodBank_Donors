import 'package:flutter/foundation.dart';

import 'donor_response_entry.dart';

/// Model class representing a blood donation request
@immutable
class BloodRequest {
  final String id;
  final String bloodBankId;
  final String bloodBankName;
  final String bloodType;
  final int units;
  final bool isUrgent;
  final bool isVerified;
  final String details;
  final String hospitalLocation;
  final double? hospitalLatitude;
  final double? hospitalLongitude;

  /// Donors who tapped Accept (maintained server-side).
  final int acceptedCount;

  /// Donors who tapped Reject (maintained server-side).
  final int rejectedCount;

  /// Current donor's response for this request: `accepted`, `rejected`, or null (from getRequests only).
  final String? myResponse;

  /// Whether this request has been marked completed by the blood bank.
  final bool isCompleted;

  /// Donors who accepted (name + email) — from getRequestsByBloodBankId for hospitals.
  final List<DonorResponseEntry> acceptedDonors;

  /// Donors who rejected (name + email) — from getRequestsByBloodBankId for hospitals.
  final List<DonorResponseEntry> rejectedDonors;

  const BloodRequest({
    required this.id,
    required this.bloodBankId,
    required this.bloodBankName,
    required this.bloodType,
    required this.units,
    required this.isUrgent,
    this.isVerified = false,
    this.details = '',
    this.hospitalLocation = '',
    this.hospitalLatitude,
    this.hospitalLongitude,
    this.acceptedCount = 0,
    this.rejectedCount = 0,
    this.myResponse,
    this.isCompleted = false,
    this.acceptedDonors = const [],
    this.rejectedDonors = const [],
  });

  factory BloodRequest.fromMap(Map<String, dynamic> data, String id) {
    final units = _coerceInt(data['units'], 1);
    return BloodRequest(
      id: id,
      bloodBankId: data['bloodBankId']?.toString() ?? '',
      bloodBankName: data['bloodBankName']?.toString() ?? '',
      bloodType: data['bloodType']?.toString() ?? '',
      units: units < 1 ? 1 : units,
      isUrgent: _coerceBool(data['isUrgent']),
      isVerified: _coerceBool(data['isVerified']) || _coerceBool(data['isUrgent']),
      details: data['details']?.toString() ?? '',
      hospitalLocation: data['hospitalLocation']?.toString() ?? '',
      hospitalLatitude: _coerceDouble(data['hospitalLatitude']),
      hospitalLongitude: _coerceDouble(data['hospitalLongitude']),
      acceptedCount: _coerceInt(data['acceptedCount'], 0),
      rejectedCount: _coerceInt(data['rejectedCount'], 0),
      myResponse: _parseMyResponse(data['myResponse']),
      isCompleted: _coerceBool(data['isCompleted']),
      acceptedDonors: _parseDonorEntries(data['acceptedDonors']),
      rejectedDonors: _parseDonorEntries(data['rejectedDonors']),
    );
  }

  static List<DonorResponseEntry> _parseDonorEntries(dynamic v) {
    if (v is! List) return const [];
    final out = <DonorResponseEntry>[];
    for (final e in v) {
      if (e == null) continue;
      if (e is! Map) continue;
      final m = <String, dynamic>{};
      e.forEach((key, value) {
        m[key.toString()] = value;
      });
      out.add(DonorResponseEntry.fromMap(m));
    }
    return out;
  }

  static int _coerceInt(dynamic v, [int defaultValue = 0]) {
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? defaultValue;
    return defaultValue;
  }

  static bool _coerceBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  static double? _coerceDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static String? _parseMyResponse(dynamic value) {
    if (value is! String) return null;
    final s = value.trim().toLowerCase();
    if (s == 'accepted' || s == 'rejected') return s;
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'bloodBankId': bloodBankId,
      'bloodBankName': bloodBankName,
      'bloodType': bloodType,
      'units': units,
      'isUrgent': isUrgent,
      'isVerified': isVerified || isUrgent,
      'details': details,
      'hospitalLocation': hospitalLocation,
      'isCompleted': isCompleted,
      if (hospitalLatitude != null) 'hospitalLatitude': hospitalLatitude,
      if (hospitalLongitude != null) 'hospitalLongitude': hospitalLongitude,
    };
  }
}
