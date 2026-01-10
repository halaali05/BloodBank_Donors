import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';
import '../services/cloud_functions_service.dart';
import '../services/auth_service.dart';

/// Controller for donor dashboard business logic
/// Separates business logic from UI for better maintainability
///
/// SECURITY ARCHITECTURE:
/// - All reads go through Cloud Functions (server-side)
/// - Server validates user authentication
/// - Server ensures proper data access
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

  // ------------------ Authentication ------------------
  /// Gets the current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Gets the current authenticated user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Logs out the current user
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ------------------ Statistics Calculation ------------------
  /// Calculates dashboard statistics from a list of requests
  ///
  /// Returns a map with:
  /// - totalCount: Total number of requests
  /// - urgentCount: Number of urgent requests
  /// - normalCount: Number of non-urgent requests
  Map<String, int> calculateStatistics(List<BloodRequest> requests) {
    final urgentCount = requests.where((r) => r.isUrgent == true).length;
    final normalCount = requests.length - urgentCount;

    return {
      'totalCount': requests.length,
      'urgentCount': urgentCount,
      'normalCount': normalCount,
    };
  }

  // ------------------ Data Fetching ------------------
  /// Fetches all blood requests via Cloud Functions
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  ///
  /// Returns:
  /// - List of BloodRequest objects
  ///
  /// Throws:
  /// - Exception if fetch fails
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

  /// Fetches unread notifications count via Cloud Functions
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  ///
  /// Returns:
  /// - Number of unread notifications
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

  // ------------------ User Data Processing ------------------
  /// Fetches user profile data via Cloud Functions
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  ///
  /// Returns:
  /// - User data map, or null if fetch fails
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return null;

      return {
        'fullName': userData.fullName ?? '',
        'name':
            userData.fullName ?? '', // Use fullName as name for compatibility
        'email': userData.email,
        'location': userData.location ?? '',
      };
    } catch (e) {
      return null;
    }
  }

  /// Extracts donor name from user data
  ///
  /// Tries multiple sources in order:
  /// 1. User data 'name' field
  /// 2. User data 'fullName' field
  /// 3. Auth displayName
  /// 4. Default: 'Donor'
  ///
  /// Parameters:
  /// - [userData]: User data map from Cloud Functions
  /// - [authDisplayName]: Display name from Firebase Auth
  ///
  /// Returns: The best available name
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
