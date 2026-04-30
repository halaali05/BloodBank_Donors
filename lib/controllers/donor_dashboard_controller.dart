import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';
import '../services/cloud_functions_service.dart';
import '../services/auth_service.dart';

/// Donor home screen data: requests, responses, notification count, profile fetch.
///
/// Everything hits the backend through Cloud Functions.
class DonorDashboardController {
  final FirebaseAuth _auth;
  final CloudFunctionsService _cloudFunctions;
  final AuthService _authService;

  DonorDashboardController({
    FirebaseAuth? auth,
    CloudFunctionsService? cloudFunctions,
    AuthService? authService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _cloudFunctions = cloudFunctions ?? CloudFunctionsService(),
       _authService = authService ?? AuthService();

  // --- Auth ---

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  // --- Stats ---

  /// Counts total / urgent / normal for header chips.
  Map<String, int> calculateStatistics(List<BloodRequest> requests) {
    final urgentCount = requests.where((r) => r.isUrgent == true).length;
    final normalCount = requests.length - urgentCount;

    return {
      'totalCount': requests.length,
      'urgentCount': urgentCount,
      'normalCount': normalCount,
    };
  }

  // --- Requests ---

  /// Pulls the latest request list from the server.
  Future<List<BloodRequest>> fetchRequests() async {
    try {
      final result = await _cloudFunctions.getRequests(limit: 100);
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

  /// Records donor accept/reject for a request (Cloud Function).
  Future<void> submitDonorResponse({
    required String requestId,
    required String response,
  }) async {
    final r = response.trim().toLowerCase();
    if (r != 'accepted' && r != 'rejected' && r != 'none') {
      throw Exception('Invalid response');
    }
    await _cloudFunctions.setDonorRequestResponse(
      requestId: requestId,
      response: r,
    );
  }

  /// How many notification rows are still unread.
  Future<int> getUnreadNotificationsCount() async {
    try {
      final result = await _cloudFunctions.getNotifications();
      final notificationsData = result['notifications'] as List<dynamic>? ?? [];

      final unreadCount = notificationsData.where((n) {
        final notification = Map<String, dynamic>.from(n);
        final isRead =
            notification['isRead'] == true || notification['read'] == true;
        return !isRead;
      }).length;

      return unreadCount;
    } catch (e) {
      return 0;
    }
  }

  // --- Profile ---

  /// Donor-facing fields merged from Auth + Cloud Function profile.
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return null;

      return {
        'fullName': userData.fullName ?? '',
        'name':
            userData.fullName ?? '', // Keep `name` in sync with `fullName` for older UI.
        'email': userData.email,
        'location': userData.location ?? '',
        'latitude': userData.latitude,
        'longitude': userData.longitude,
        'bloodType': userData.bloodType ?? '',
        'gender': userData.gender,
        'nextDonationEligibleAt': userData.nextDonationEligibleAt,
        'lastDonatedAt': userData.lastDonatedAt,
        'restrictedUntil': userData.restrictedUntil,
      };
    } catch (e) {
      return null;
    }
  }

  /// Best-effort display name (`userData`, then Firebase displayName, then "Donor").
  String extractDonorName(
    Map<String, dynamic>? userData,
    String? authDisplayName,
  ) {
    if (userData != null) {
      final name = (userData['name'] ?? '').toString().trim();
      final fullName = (userData['fullName'] ?? '').toString().trim();

      if (name.isNotEmpty) {
        return name;
      }
      if (fullName.isNotEmpty) {
        return fullName;
      }
    }

    if (authDisplayName != null && authDisplayName.trim().isNotEmpty) {
      return authDisplayName.trim();
    }

    return 'Donor';
  }
}
