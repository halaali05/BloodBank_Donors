import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';
import '../services/requests_service.dart';

class NewRequestController {
  final RequestsService _requestsService;
  final FirebaseAuth _auth;

  NewRequestController({RequestsService? requestsService, FirebaseAuth? auth})
    : _requestsService = requestsService ?? RequestsService.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? validateLocation(String? location) {
    if (location == null || location.trim().isEmpty) {
      return 'Please select hospital location';
    }
    return null;
  }

  String? validateAuthentication() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return 'You must be logged in to create a request.';
    }
    return null;
  }

  String? validateRequest({String? hospitalLocation}) {
    final locationError = validateLocation(hospitalLocation);
    if (locationError != null) return locationError;

    final authError = validateAuthentication();
    if (authError != null) return authError;

    return null;
  }

  Future<Map<String, dynamic>> createRequest({
    required String bloodBankName,
    required String bloodType,
    required int units,
    required bool isUrgent,
    required String hospitalLocation,
    String details = '',
    double? hospitalLatitude,
    double? hospitalLongitude,
  }) async {
    try {
      final validationError = validateRequest(
        hospitalLocation: hospitalLocation,
      );
      if (validationError != null) {
        return {'success': false, 'errorMessage': validationError};
      }

      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return {
          'success': false,
          'errorMessage': 'You must be logged in to create a request.',
        };
      }

      final request = BloodRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bloodBankId: uid,
        bloodBankName: bloodBankName,
        bloodType: bloodType,
        units: units,
        isUrgent: isUrgent,
        details: details.trim(),
        hospitalLocation: hospitalLocation.trim(),
        hospitalLatitude: hospitalLatitude,
        hospitalLongitude: hospitalLongitude,
      );

      await _requestsService.addRequest(request);

      return {'success': true};
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      String errorMessage = 'Failed to create request. Please try again.';

      if (errorString.contains('permission-denied') ||
          errorString.contains('permission')) {
        errorMessage =
            'You do not have permission to create requests. Only hospitals can create requests.';
      } else if (errorString.contains('invalid-argument') ||
          errorString.contains('invalid')) {
        errorMessage = 'Please check your request details and try again.';
      } else if (errorString.contains('unauthenticated')) {
        errorMessage = 'Please log in to create a request.';
      } else if (errorString.contains('internal') ||
          errorString.contains('server')) {
        errorMessage = 'Server error occurred. Please try again later.';
      } else if (errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('timeout')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (e.toString().isNotEmpty &&
          !errorString.contains('exception')) {
        errorMessage = e.toString();
      }

      return {'success': false, 'errorMessage': errorMessage};
    }
  }
}
