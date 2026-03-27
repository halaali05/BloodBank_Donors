import 'package:flutter/foundation.dart';

@immutable
class BloodRequest {
  final double? hospitalLatitude;
  final double? hospitalLongitude;

  final String id;
  final String bloodBankId;
  final String bloodBankName;
  final String bloodType;
  final int units;
  final bool isUrgent;
  final String details;
  final String hospitalLocation;

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
  });

  factory BloodRequest.fromMap(Map<String, dynamic> data, String id) {
    return BloodRequest(
      id: id,
      bloodBankId: data['bloodBankId'] ?? '',
      bloodBankName: data['bloodBankName'] ?? '',
      bloodType: data['bloodType'] ?? '',
      units: data['units'] ?? 1,
      isUrgent: data['isUrgent'] ?? false,
      details: data['details'] ?? '',
      hospitalLocation: data['hospitalLocation'] ?? '',
      hospitalLatitude: (data['hospitalLatitude'] as num?)?.toDouble(),
      hospitalLongitude: (data['hospitalLongitude'] as num?)?.toDouble(),
    );
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
      'hospitalLatitude': hospitalLatitude,
      'hospitalLongitude': hospitalLongitude,
    };
  }
}
