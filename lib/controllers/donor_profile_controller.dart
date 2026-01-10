import '../services/cloud_functions_service.dart';

/// Controller for donor profile business logic
/// Separates business logic from UI for better maintainability
class DonorProfileController {
  final CloudFunctionsService _cloudFunctions;

  DonorProfileController({CloudFunctionsService? cloudFunctions})
    : _cloudFunctions = cloudFunctions ?? CloudFunctionsService();

  // ------------------ Profile Data Fetching ------------------
  /// Fetches user profile data via Cloud Functions
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures users can only read their own profile
  ///
  /// Returns:
  /// - Map with user profile data
  ///
  /// Throws:
  /// - Exception if fetch fails
  Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      return await _cloudFunctions.getUserData();
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  // ------------------ Profile Update Logic ------------------
  /// Updates user profile name
  ///
  /// Security Architecture:
  /// - All profile updates go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures user can only update their own profile
  /// - Server updates both Firestore and Firebase Auth display name
  ///
  /// Parameters:
  /// - [name]: The new name to set for the user
  ///
  /// Returns:
  /// - Map with success status and message
  ///
  /// Throws:
  /// - Exception with error message if update fails
  Future<Map<String, dynamic>> updateProfileName({required String name}) async {
    try {
      return await _cloudFunctions.updateUserProfile(name: name);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}
