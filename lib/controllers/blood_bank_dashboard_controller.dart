import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_functions_service.dart';
import '../models/blood_request_model.dart';

/// Blood bank dashboard: own requests, delete/update rules, headline stats.
class BloodBankDashboardController {
  final CloudFunctionsService _cloudFunctions;
  final FirebaseAuth _auth;

  BloodBankDashboardController({
    CloudFunctionsService? cloudFunctions,
    FirebaseAuth? auth,
  }) : _cloudFunctions = cloudFunctions ?? CloudFunctionsService(),
       _auth = auth ?? FirebaseAuth.instance;

  // --- Auth ---

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// True when this login created the listed request (`requestBloodBankId` equals current uid).
  bool verifyRequestOwnership(String requestBloodBankId) {
    final currentUid = getCurrentUserId();
    return currentUid != null && requestBloodBankId == currentUid;
  }

  // --- Write ---

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
      // Preserve the readable message produced in [CloudFunctionsService].
      if (e is Exception) {
        rethrow;
      }
      // Handle any other unexpected errors
      throw Exception('Failed to delete request: ${e.toString()}');
    }
  }

  /// Marks a blood request as completed using Cloud Functions.
  Future<Map<String, dynamic>> markRequestCompleted({
    required String requestId,
  }) async {
    if (requestId.isEmpty) {
      throw Exception('Request ID is required');
    }
    try {
      return await _cloudFunctions.markRequestCompleted(requestId: requestId);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to complete request: ${e.toString()}');
    }
  }

  /// Updates units for a blood request using Cloud Functions.
  Future<Map<String, dynamic>> updateRequestUnits({
    required String requestId,
    required int units,
  }) async {
    if (requestId.isEmpty) {
      throw Exception('Request ID is required');
    }
    if (units < 1) {
      throw Exception('Units must be at least 1');
    }
    try {
      return await _cloudFunctions.updateRequestUnits(
        requestId: requestId,
        units: units,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to update request units: ${e.toString()}');
    }
  }

  // --- Load ---

  Future<List<BloodRequest>> fetchRequests() async {
    try {
      final result = await _cloudFunctions.getRequestsByBloodBankId();
      final raw = result['requests'];
      if (raw is! List) {
        return [];
      }

      final out = <BloodRequest>[];
      for (final data in raw) {
        if (data is! Map) continue;
        final map = Map<String, dynamic>.from(data);
        final id = map['id']?.toString() ?? '';
        out.add(BloodRequest.fromMap(map, id));
      }
      return out;
    } catch (e) {
      throw Exception('Failed to fetch requests: $e');
    }
  }

  // --- Stats ---

  /// Header numbers: totals, urgency split, responder counts.
  Map<String, int> calculateStatistics(List<BloodRequest> requests) {
    final totalUnits = requests.fold<int>(0, (sum, r) => sum + r.units);
    final activeRequests = requests.where((r) => !r.isCompleted).toList();
    final urgentCount = activeRequests.where((r) => r.isUrgent).length;
    final normalCount = activeRequests.where((r) => !r.isUrgent).length;

    final totalAccepted = requests.fold<int>(
      0,
      (sum, r) => sum + r.acceptedCount,
    );
    final totalRejected = requests.fold<int>(
      0,
      (sum, r) => sum + r.rejectedCount,
    );

    return {
      'totalUnits': totalUnits,
      'activeCount': activeRequests.length,
      'urgentCount': urgentCount,
      'normalCount': normalCount,
      'totalAccepted': totalAccepted,
      'totalRejected': totalRejected,
    };
  }
}
