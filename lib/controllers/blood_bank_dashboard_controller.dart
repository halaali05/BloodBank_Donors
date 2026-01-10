import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_functions_service.dart';
import '../models/blood_request_model.dart';

/// Controller for blood bank dashboard business logic
/// Separates business logic from UI for better maintainability
class BloodBankDashboardController {
  final CloudFunctionsService _cloudFunctions;
  final FirebaseAuth _auth;

  BloodBankDashboardController({
    CloudFunctionsService? cloudFunctions,
    FirebaseAuth? auth,
  }) : _cloudFunctions = cloudFunctions ?? CloudFunctionsService(),
       _auth = auth ?? FirebaseAuth.instance;

  // ------------------ Authentication ------------------
  /// Gets the current authenticated user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Verifies that the current user owns the request
  /// Returns true if user owns the request, false otherwise
  bool verifyRequestOwnership(String requestBloodBankId) {
    final currentUid = getCurrentUserId();
    return currentUid != null && requestBloodBankId == currentUid;
  }

  // ------------------ Request Operations ------------------
  /// Deletes a blood request using Cloud Functions
  ///
  /// Security Architecture:
  /// - All delete operations go through Cloud Functions (server-side)
  /// - Server validates user permissions and request ownership
  /// - Server handles cleanup of related notifications and messages
  ///
  /// Parameters:
  /// - [requestId]: The ID of the request to delete
  ///
  /// Returns:
  /// - Map with success status and message
  ///
  /// Throws:
  /// - FirebaseFunctionsException with error details
  Future<Map<String, dynamic>> deleteRequest({
    required String requestId,
  }) async {
    if (requestId.isEmpty) {
      throw Exception('Request ID is required');
    }

    try {
      final result = await _cloudFunctions.deleteRequest(requestId: requestId);
      return result;
    } catch (e) {
      // Service layer converts FirebaseFunctionsException to Exception
      // Re-throw as-is to preserve the error message from service layer
      if (e is Exception) {
        rethrow;
      }
      // Handle any other unexpected errors
      throw Exception('Failed to delete request: ${e.toString()}');
    }
  }

  // ------------------ Data Fetching ------------------
  /// Fetches all requests for the current blood bank via Cloud Functions
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures only hospitals can view their own requests
  ///
  /// Returns:
  /// - List of BloodRequest objects
  ///
  /// Throws:
  /// - Exception if fetch fails
  Future<List<BloodRequest>> fetchRequests() async {
    try {
      final result = await _cloudFunctions.getRequestsByBloodBankId();
      final requestsData = result['requests'] as List<dynamic>? ?? [];

      return requestsData.map((data) {
        final map = Map<String, dynamic>.from(data);
        final id = map['id'] as String? ?? '';
        return BloodRequest.fromMap(map, id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch requests: $e');
    }
  }

  // ------------------ Statistics Calculation ------------------
  /// Calculates dashboard statistics from a list of requests
  ///
  /// Returns a map with:
  /// - totalUnits: Sum of all units from all requests
  /// - activeCount: Total number of requests
  /// - urgentCount: Number of urgent requests
  /// - normalCount: Number of non-urgent requests
  Map<String, int> calculateStatistics(List<BloodRequest> requests) {
    final totalUnits = requests.fold<int>(0, (sum, r) => sum + r.units);
    final urgentCount = requests.where((r) => r.isUrgent).length;
    final normalCount = requests.where((r) => !r.isUrgent).length;

    return {
      'totalUnits': totalUnits,
      'activeCount': requests.length,
      'urgentCount': urgentCount,
      'normalCount': normalCount,
    };
  }
}
