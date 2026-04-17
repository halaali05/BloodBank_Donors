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
  final String details;
  final String hospitalLocation;
  final double? hospitalLatitude;
  final double? hospitalLongitude;

  /// Donors who tapped Accept (maintained server-side).
  final int acceptedCount;

  /// Donors who tapped Reject (maintained server-side).
  final int rejectedCount;

  /// Current donor's response for this request
  final String? myResponse;

  /// Whether this request has been marked completed by the blood bank.
  final bool isCompleted;

  /// Appointment time for this donor (if scheduled)
  final DateTime? appointmentAt;

  /// Donor pipeline on this request: accepted, scheduled, tested, donated, restricted (from donorResponses).
  final String? donorProcessStatus;

  /// When the blood request was created (ms from server).
  final DateTime? createdAt;

  /// Donors who accepted — for hospitals
  final List<DonorResponseEntry> acceptedDonors;

  /// Donors who rejected — for hospitals
  final List<DonorResponseEntry> rejectedDonors;

  const BloodRequest({
    required this.id,
    required this.bloodBankId,
    required this.bloodBankName,
    required this.bloodType,
    required this.units,
    required this.isUrgent,
    this.details = '',
    this.hospitalLocation = '',
    this.hospitalLatitude,
    this.hospitalLongitude,
    this.acceptedCount = 0,
    this.rejectedCount = 0,
    this.myResponse,
    this.isCompleted = false,
    this.appointmentAt,
    this.donorProcessStatus,
    this.createdAt,
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
      details: data['details']?.toString() ?? '',
      hospitalLocation: data['hospitalLocation']?.toString() ?? '',
      hospitalLatitude: _coerceDouble(data['hospitalLatitude']),
      hospitalLongitude: _coerceDouble(data['hospitalLongitude']),
      acceptedCount: _coerceInt(data['acceptedCount'], 0),
      rejectedCount: _coerceInt(data['rejectedCount'], 0),
      myResponse: _parseMyResponse(data['myResponse']),
      isCompleted: _coerceBool(data['isCompleted']),

      /// ✅ أهم سطر (حل المشكلة)
      appointmentAt: _parseDate(data['appointmentAt']),
      donorProcessStatus: _parseOptionalString(data['processStatus']),
      createdAt: _parseDate(data['createdAt']),

      acceptedDonors: _parseDonorEntries(data['acceptedDonors']),
      rejectedDonors: _parseDonorEntries(data['rejectedDonors']),
    );
  }

  static List<DonorResponseEntry> _parseDonorEntries(dynamic v) {
    if (v is! List) return const [];
    final out = <DonorResponseEntry>[];

    for (final e in v) {
      if (e == null || e is! Map) continue;

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

  static String? _parseOptionalString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _parseMyResponse(dynamic value) {
    if (value is! String) return null;
    final s = value.trim().toLowerCase();

    if (s == 'accepted') return s;
    if (s == 'rejected') return s;

    return null;
  }

  /// ✅ NEW: parse appointment date safely
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);

    try {
      final dt = v.toDate(); // Firestore timestamp
      if (dt is DateTime) return dt;
    } catch (_) {}

    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'bloodBankId': bloodBankId,
      'bloodBankName': bloodBankName,
      'bloodType': bloodType,
      'units': units,
      'isUrgent': isUrgent,
      'details': details,
      'hospitalLocation': hospitalLocation,
      'isCompleted': isCompleted,

      if (hospitalLatitude != null) 'hospitalLatitude': hospitalLatitude,
      if (hospitalLongitude != null) 'hospitalLongitude': hospitalLongitude,

      /// Optional: send appointment back if needed
      if (appointmentAt != null)
        'appointmentAt': appointmentAt!.toIso8601String(),
    };
  }
}