import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';
import 'cloud_functions_service.dart';

/// Service class for managing blood requests
/// Handles creating, retrieving, and notifying about blood requests
/// Uses Cloud Functions as a secure layer for write operations

class RequestsService {
  static final RequestsService instance = RequestsService._internal();

  final CollectionReference _requestsCollection;
  final CloudFunctionsService _cloudFunctions;

  RequestsService._internal()
    : _requestsCollection = FirebaseFirestore.instance.collection('requests'),
      _cloudFunctions = CloudFunctionsService();

  /// for testing
  RequestsService.test(
    FirebaseFirestore db,
    FirebaseAuth auth, [
    CloudFunctionsService? cloudFunctions,
  ]) : _requestsCollection = db.collection('requests'),
       _cloudFunctions = cloudFunctions ?? CloudFunctionsService();

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

  /// Gets a stream of all blood requests ordered by creation date
  ///
  /// Returns a real-time stream of all blood requests from Firestore,
  /// ordered by creation date (newest first). The stream automatically
  /// updates whenever requests are added, modified, or deleted.
  ///
  /// Note: This uses direct Firestore access for real-time updates.
  /// Ensure Firestore security rules restrict read access appropriately.
  ///
  /// Returns:
  /// - A [Stream] of [List<BloodRequest>] that emits whenever the data changes
  Stream<List<BloodRequest>> getRequestsStream() {
    return _requestsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return BloodRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList(),
        );
  }

  /// Gets blood requests via Cloud Functions (for pagination support)
  ///
  /// Fetches blood requests through Cloud Functions with pagination support.
  /// Use this when you need pagination or when you prefer all operations
  /// to go through Cloud Functions.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of requests to return (default: 50)
  /// - [lastRequestId]: For pagination, the ID of the last request from previous call
  ///
  /// Returns:
  /// - A [List<BloodRequest>] and a boolean indicating if there are more requests
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

  // Note: Notification sending is now handled by Cloud Functions
  // when addRequest is called with isUrgent = true
}
