import 'package:flutter/foundation.dart';

/// Model class representing a blood donation request
/// Contains all information about a blood request made by a blood bank
@immutable
class BloodRequest {
  /// Unique identifier for the request (usually Firestore document ID)
  final String id;

  /// The unique ID of the blood bank that created this request
  final String bloodBankId;

  /// The name of the blood bank/hospital making the request
  final String bloodBankName;

  /// The required blood type (e.g., 'A+', 'O-', 'AB+')
  final String bloodType;

  /// The number of blood units needed
  final int units;

  /// Whether this is an urgent request (triggers notifications to donors)
  final bool isUrgent;

  /// Additional details about the request
  final String details;

  /// The location of the hospital where blood is needed
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
  });

  /// Factory constructor to create a [BloodRequest] from Firestore data
  ///
  /// Converts a Firestore document map into a [BloodRequest] object.
  /// Used when reading data from Firestore.
  ///
  /// Parameters:
  /// - [data]: A [Map] containing the Firestore document data
  /// - [id]: The document ID from Firestore
  ///
  /// Returns:
  /// - A new [BloodRequest] instance with data from Firestore
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
    );
  }

  /// Converts the [BloodRequest] to a Map for Firestore storage
  ///
  /// Serializes the [BloodRequest] object into a format that can be
  /// saved to Firestore. Used when writing data to Firestore.
  ///
  /// Returns:
  /// - A [Map] containing all request data ready for Firestore
  Map<String, dynamic> toMap() {
    return {
      'bloodBankId': bloodBankId,
      'bloodBankName': bloodBankName,
      'bloodType': bloodType,
      'units': units,
      'isUrgent': isUrgent,
      'details': details,
      'hospitalLocation': hospitalLocation,
    };
  }
}
