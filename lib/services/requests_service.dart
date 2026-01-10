import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request_model.dart';
import 'cloud_functions_service.dart';

/// Service class for managing blood requests
/// Handles creating, retrieving, and notifying about blood requests
///
/// SECURITY ARCHITECTURE:
/// - All writes go through Cloud Functions (server-side)
/// - All reads go through Cloud Functions (server-side)
/// - No direct Firestore access from client-side
class RequestsService {
  static final RequestsService instance = RequestsService._internal();

  final CloudFunctionsService _cloudFunctions;

  RequestsService._internal() : _cloudFunctions = CloudFunctionsService();

  /// For testing - allows dependency injection
  RequestsService.test({CloudFunctionsService? cloudFunctions})
    : _cloudFunctions = cloudFunctions ?? CloudFunctionsService();

  /// Adds a new blood request via Cloud Functions
  ///
  /// Creates a new blood request in the Firestore database through Cloud Functions
  /// and sends notifications to all donors if the request is marked as urgent.
  /// This ensures secure access control - only hospitals can create requests.
  ///
  /// Parameters:
  /// - [request]: The [BloodRequest] object containing all request details
  ///
  /// Throws [Exception] if the request fails to save
  Future<void> addRequest(BloodRequest request) async {
    await _cloudFunctions.addRequest(
      requestId: request.id,
      bloodBankName: request.bloodBankName,
      bloodType: request.bloodType,
      units: request.units,
      isUrgent: request.isUrgent,
      details: request.details,
      hospitalLocation: request.hospitalLocation,
    );
  }

  /// Gets blood requests via Cloud Functions
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures proper data filtering and access control
  ///
  /// Parameters:
  /// - [limit]: Maximum number of requests to return (default: 50)
  /// - [lastRequestId]: For pagination, the ID of the last request from previous call
  ///
  /// Returns:
  /// - Map with 'requests' list and 'hasMore' boolean indicating if there are more requests
  Future<Map<String, dynamic>> getRequests({
    int limit = 50,
    String? lastRequestId,
  }) async {
    final result = await _cloudFunctions.getRequests(
      limit: limit,
      lastRequestId: lastRequestId,
    );

    final requestsList = (result['requests'] as List).map((data) {
      final requestData = Map<String, dynamic>.from(data);
      final id = requestData.remove('id') as String;
      // Convert timestamp from milliseconds to Timestamp
      if (requestData['createdAt'] != null) {
        requestData['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(
          requestData['createdAt'] as int,
        );
      }
      return BloodRequest.fromMap(requestData, id);
    }).toList();

    return {'requests': requestsList, 'hasMore': result['hasMore'] as bool};
  }
}
