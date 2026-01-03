import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions;

  CloudFunctionsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, dynamic>> createPendingProfile({
    required String role, // 'donor' or 'hospital'
    String? fullName,
    String? bloodType,
    String? location,
    String? bloodBankName,
    String? medicalFileUrl,
  }) async {
    try {
      print('[CloudFunctionsService] Calling createPendingProfile...');
      final callable = _functions.httpsCallable('createPendingProfile');
      print('[CloudFunctionsService] Callable created, calling with data...');

      final result = await callable.call({
        'role': role,
        if (fullName != null) 'fullName': fullName,
        if (bloodType != null) 'bloodType': bloodType,
        if (location != null) 'location': location,
        if (bloodBankName != null) 'bloodBankName': bloodBankName,
        if (medicalFileUrl != null) 'medicalFileUrl': medicalFileUrl,
      });

      print('[CloudFunctionsService] Call succeeded, result: $result');
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      print('[CloudFunctionsService] FirebaseFunctionsException caught');
      throw _handleFunctionsException(e);
    } catch (e) {
      // Catch any other exceptions (network errors, etc.)
      print('[CloudFunctionsService] Unexpected error: $e');
      print('[CloudFunctionsService] Error type: ${e.runtimeType}');

      // Check if it's a network/connection error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('socket') ||
          errorStr.contains('timeout') ||
          errorStr.contains('unavailable')) {
        throw Exception(
          'Network error. Please check your internet connection and try again.',
        );
      }

      // Check if function is not found (not deployed)
      if (errorStr.contains('not found') ||
          errorStr.contains('does not exist') ||
          errorStr.contains('404')) {
        throw Exception(
          'Cloud Function not found. Please deploy Cloud Functions first.',
        );
      }

      // Generic error
      throw Exception('Failed to connect to server. Please try again later.');
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

  Future<Map<String, dynamic>> markNotificationsAsRead() async {
    try {
      final callable = _functions.httpsCallable('markNotificationsAsRead');
      final result = await callable.call();
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
  }) async {
    try {
      final callable = _functions.httpsCallable('sendMessage');
      final result = await callable.call({
        'requestId': requestId,
        'text': text,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> deleteRequest({
    required String requestId,
  }) async {
    try {
      print(
        '[CloudFunctionsService] Calling deleteRequest with requestId: $requestId',
      );
      final callable = _functions.httpsCallable('deleteRequest');
      final result = await callable.call({'requestId': requestId});
      print('[CloudFunctionsService] deleteRequest succeeded: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      print(
        '[CloudFunctionsService] deleteRequest failed with FirebaseFunctionsException',
      );
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.details}');
      throw _handleFunctionsException(e);
    } catch (e) {
      print(
        '[CloudFunctionsService] deleteRequest failed with unexpected error: $e',
      );
      print('  Type: ${e.runtimeType}');
      rethrow;
    }
  }

  Exception _handleFunctionsException(FirebaseFunctionsException e) {
    // Log the full error for debugging
    print('Cloud Function Error:');
    print('  Code: ${e.code}');
    print('  Message: ${e.message}');
    print('  Details: ${e.details}');

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
        userMessage = 'Please verify your email first';
        break;
      case 'not-found':
        userMessage = 'Information not found';
        break;
      case 'internal':
        // Try to extract more specific error from message
        if (e.message != null && e.message!.isNotEmpty) {
          // If message contains specific details, use them
          if (e.message!.contains('Failed to delete request:')) {
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
