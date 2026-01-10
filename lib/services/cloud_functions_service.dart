import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions;

  CloudFunctionsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, dynamic>> createPendingProfile({
    required String role, // 'donor' or 'hospital'
    String? fullName,
    String? location,
    String? bloodBankName,
    String? medicalFileUrl,
  }) async {
    try {
      final callable = _functions.httpsCallable('createPendingProfile');

      final Map<String, dynamic> callData = {'role': role};

      // Add donor-specific fields (required for donors)
      // These are validated in register_screen.dart before calling, so they should never be null/empty
      if (role == 'donor') {
        // Ensure we have valid values (should never be null/empty due to validation)
        if (fullName == null || fullName.trim().isEmpty) {
          throw Exception('Full name is required for donor registration');
        }
        if (location == null || location.trim().isEmpty) {
          throw Exception('Location is required for donor registration');
        }
        callData['fullName'] = fullName.trim();
        callData['location'] = location.trim();
        if (medicalFileUrl != null && medicalFileUrl.trim().isNotEmpty) {
          callData['medicalFileUrl'] = medicalFileUrl.trim();
        }
      }

      // Add hospital-specific fields (required for hospitals)
      // These are validated in register_screen.dart before calling, so they should never be null/empty
      if (role == 'hospital') {
        if (bloodBankName == null || bloodBankName.trim().isEmpty) {
          throw Exception(
            'Blood bank name is required for hospital registration',
          );
        }
        if (location == null || location.trim().isEmpty) {
          throw Exception('Location is required for hospital registration');
        }
        callData['bloodBankName'] = bloodBankName.trim();
        callData['location'] = location.trim();
      }

      final result = await callable.call(callData);

      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      // Catch any other exceptions (network errors, SSL errors, etc.)
      throw _handleNetworkError(e);
    }
  }

  Future<Map<String, dynamic>> completeProfileAfterVerification() async {
    try {
      final callable = _functions.httpsCallable(
        'completeProfileAfterVerification',
      );
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Updates the last login timestamp for the authenticated user
  /// Only updates if user document exists in users collection
  Future<Map<String, dynamic>> updateLastLoginAt() async {
    try {
      final callable = _functions.httpsCallable('updateLastLoginAt');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Updates the FCM token for push notifications
  ///
  /// Security Architecture:
  /// - All FCM token updates go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures user document exists before updating
  ///
  /// Parameters:
  /// - [fcmToken]: The Firebase Cloud Messaging token for push notifications
  ///
  /// Returns:
  /// - Map with success status and message
  Future<Map<String, dynamic>> updateFcmToken({
    required String fcmToken,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateFcmToken');
      final result = await callable.call({'fcmToken': fcmToken});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  /// Updates user profile information
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
  Future<Map<String, dynamic>> updateUserProfile({required String name}) async {
    try {
      final callable = _functions.httpsCallable('updateUserProfile');
      final result = await callable.call({'name': name});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> getUserData({String? uid}) async {
    try {
      final callable = _functions.httpsCallable('getUserData');
      final result = await callable.call({if (uid != null) 'uid': uid});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<String> getUserRole({String? uid}) async {
    try {
      final callable = _functions.httpsCallable('getUserRole');
      final result = await callable.call({if (uid != null) 'uid': uid});
      final data = Map<String, dynamic>.from(result.data);
      return (data['role'] ?? '') as String;
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> addRequest({
    required String requestId,
    required String bloodBankName,
    required String bloodType,
    required int units,
    required bool isUrgent,
    required String hospitalLocation,
    String details = '',
  }) async {
    try {
      final callable = _functions.httpsCallable('addRequest');
      final result = await callable.call({
        'requestId': requestId,
        'bloodBankName': bloodBankName,
        'bloodType': bloodType,
        'units': units,
        'isUrgent': isUrgent,
        'details': details,
        'hospitalLocation': hospitalLocation,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> getRequests({
    int limit = 50,
    String? lastRequestId,
  }) async {
    try {
      final callable = _functions.httpsCallable('getRequests');
      final result = await callable.call({
        'limit': limit,
        if (lastRequestId != null) 'lastRequestId': lastRequestId,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  /// Get all requests for a specific blood bank
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures only hospitals can view their own requests
  ///
  /// Returns:
  /// - Map with 'requests' list and 'count'
  Future<Map<String, dynamic>> getRequestsByBloodBankId() async {
    try {
      final callable = _functions.httpsCallable('getRequestsByBloodBankId');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  /// Get all notifications for the authenticated user
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures users can only view their own notifications
  ///
  /// Returns:
  /// - Map with 'notifications' list and 'count'
  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final callable = _functions.httpsCallable('getNotifications');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  /// Get all messages for a specific request
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server filters messages based on user role and recipientId
  ///
  /// Parameters:
  /// - [requestId]: The ID of the request to get messages for
  /// - [filterRecipientId]: Optional. When provided, filters messages to show only those
  ///   for this specific recipient (used when blood bank chats with a specific donor)
  ///
  /// Returns:
  /// - Map with 'messages' list and 'count'
  Future<Map<String, dynamic>> getMessages({
    required String requestId,
    String? filterRecipientId,
  }) async {
    try {
      final callable = _functions.httpsCallable('getMessages');
      final result = await callable.call({
        'requestId': requestId,
        if (filterRecipientId != null && filterRecipientId.isNotEmpty)
          'filterRecipientId': filterRecipientId,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  Future<Map<String, dynamic>> markNotificationsAsRead() async {
    try {
      final callable = _functions.httpsCallable('markNotificationsAsRead');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> markNotificationAsRead({
    required String notificationId,
  }) async {
    try {
      final callable = _functions.httpsCallable('markNotificationAsRead');
      final result = await callable.call({'notificationId': notificationId});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> deleteNotification({
    required String notificationId,
  }) async {
    try {
      final callable = _functions.httpsCallable('deleteNotification');
      final result = await callable.call({'notificationId': notificationId});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  // send request message to ddonors function by rand
  Future<Map<String, dynamic>> sendRequestMessageToDonors({
    required String requestId,
    required String bloodType,
    required bool isUrgent,
    required String bloodBankId,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendRequestMessageToDonors');
      final result = await callable.call({
        'requestId': requestId,
        'bloodType': bloodType,
        'isUrgent': isUrgent,
        'bloodBankId': bloodBankId,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  /// Get list of all donors (hospitals only)
  /// Optional: filter by bloodType if provided
  Future<Map<String, dynamic>> getDonors({String? bloodType}) async {
    try {
      final callable = _functions.httpsCallable('getDonors');
      final result = await callable.call(
        bloodType != null ? {'bloodType': bloodType} : {},
      );
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String requestId,
    required String text,
    String? recipientId,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendMessage');
      final data = <String, dynamic>{'requestId': requestId, 'text': text};

      // CRITICAL: Always include recipientId if provided
      if (recipientId != null && recipientId.isNotEmpty) {
        data['recipientId'] = recipientId.trim();
      }

      final result = await callable.call(data);
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> deleteRequest({
    required String requestId,
  }) async {
    try {
      final callable = _functions.httpsCallable('deleteRequest');
      final result = await callable.call({'requestId': requestId});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Handles network errors, SSL errors, and connection issues
  Exception _handleNetworkError(dynamic e) {
    final errorStr = e.toString().toLowerCase();

    // Check for SSL/TLS handshake errors
    if (errorStr.contains('handshake') ||
        errorStr.contains('ssl') ||
        errorStr.contains('tls') ||
        errorStr.contains('certificate') ||
        errorStr.contains('nativecrypto') ||
        errorStr.contains('unknown error 5')) {
      return Exception(
        'Connection security error. Please check your internet connection and try again. '
        'If the problem persists, try switching networks or restarting the app.',
      );
    }

    // Check for network/connection errors
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket') ||
        errorStr.contains('timeout') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('failed to connect') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('ipv6') ||
        errorStr.contains('ipv4')) {
      return Exception(
        'Network error. Please check your internet connection and try again.',
      );
    }

    // Check if function is not found (not deployed)
    if (errorStr.contains('not found') ||
        errorStr.contains('does not exist') ||
        errorStr.contains('404')) {
      return Exception(
        'Cloud Function not found. Please deploy Cloud Functions first.',
      );
    }

    // Generic error
    return Exception('Failed to connect to server. Please try again later.');
  }

  Exception _handleFunctionsException(FirebaseFunctionsException e) {
    // Use the error message from the Cloud Function if available
    String userMessage = e.message ?? 'Something went wrong. Please try again';

    // Map specific error codes to user-friendly messages
    switch (e.code) {
      case 'unauthenticated':
        userMessage = 'Please log in first';
        break;
      case 'permission-denied':
        userMessage = 'You do not have permission';
        break;
      case 'invalid-argument':
        // Use the specific message from the function if available
        if (e.message != null && e.message!.isNotEmpty) {
          userMessage = e.message!;
        } else {
          userMessage = 'Please check your information';
        }
        break;
      case 'failed-precondition':
      case 'FAILED_PRECONDITION':
        // Check if there's a specific message, otherwise use generic message
        if (e.message != null && e.message!.isNotEmpty) {
          if (e.message!.contains('index') || e.message!.contains('Index')) {
            userMessage = 'Database index required. Please contact support.';
          } else if (e.message!.contains('verify') ||
              e.message!.contains('email')) {
            userMessage = 'Please verify your email first';
          } else {
            userMessage = e.message!;
          }
        } else {
          userMessage =
              'Operation failed. Please verify your email and try again.';
        }
        break;
      case 'not-found':
        userMessage = 'Information not found';
        break;
      case 'internal':
        // Try to extract more specific error from message
        if (e.message != null && e.message!.isNotEmpty) {
          // Check for FAILED_PRECONDITION in message (sometimes wrapped in internal error)
          if (e.message!.contains('FAILED_PRECONDITION') ||
              e.message!.contains('failed-precondition')) {
            if (e.message!.contains('index') || e.message!.contains('Index')) {
              userMessage = 'Database index required. Please contact support.';
            } else {
              userMessage =
                  'Operation failed. Please verify your email and try again.';
            }
          } else if (e.message!.contains('Failed to delete request:')) {
            userMessage = e.message!;
          } else {
            userMessage = 'Server error: ${e.message}';
          }
        } else {
          userMessage = 'Server error occurred. Please try again later.';
        }
        break;
      default:
        // Use the message from the function, or a generic one
        if (e.message != null && e.message!.isNotEmpty) {
          userMessage = e.message!;
        } else {
          userMessage = 'Something went wrong. Please try again';
        }
    }

    return Exception(userMessage);
  }
}
