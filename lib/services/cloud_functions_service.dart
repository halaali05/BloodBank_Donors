import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Calls HTTPS Cloud Functions (`us-central1`). Use this instead of talking to Firestore straight from the app.
class CloudFunctionsService {
  final FirebaseFunctions _functions;

  CloudFunctionsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<User?> _waitForCurrentUser() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;

    try {
      return await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return FirebaseAuth.instance.currentUser;
    }
  }

  Future<Map<String, dynamic>> createPendingProfile({
    required String role, // 'donor' or 'hospital'
    String? fullName,
    String? location,
    String? bloodBankName,
    String? gender,
    String? phoneNumber,
    double? latitude,
    double? longitude,
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
        if (gender == null || gender.trim().isEmpty) {
          throw Exception('Gender is required for donor registration');
        }
        if (phoneNumber == null || phoneNumber.trim().isEmpty) {
          throw Exception('Phone number is required for donor registration');
        }
        callData['gender'] = gender.trim().toLowerCase();
        callData['phoneNumber'] = phoneNumber.trim();
        if (latitude != null) callData['latitude'] = latitude;
        if (longitude != null) callData['longitude'] = longitude;
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
        if (latitude != null) callData['latitude'] = latitude;
        if (longitude != null) callData['longitude'] = longitude;
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

  /// Phone login: backend turns +962… into the Firebase email tied to that donor. Returns null if unknown.
  Future<String?> resolveDonorEmailForPhoneLogin(String phoneNumberE164) async {
    try {
      final callable = _functions.httpsCallable(
        'resolveDonorEmailForPhoneLogin',
      );
      final result = await callable.call({'phoneNumber': phoneNumberE164});
      final data = Map<String, dynamic>.from(result.data);
      final email = data['email'] as String?;
      final trimmed = email?.trim();
      if (trimmed == null || trimmed.isEmpty) return null;
      return trimmed;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') return null;
      throw _handleFunctionsException(e);
    } catch (e) {
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
      if (e.toString().startsWith('Exception: ')) rethrow;
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

  /// Saves the push token Firebase gives this device onto the logged-in user.
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

  /// Updates display name (and related fields on the server).
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
    double? hospitalLatitude,
    double? hospitalLongitude,
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
        if (hospitalLatitude != null) 'hospitalLatitude': hospitalLatitude,
        if (hospitalLongitude != null) 'hospitalLongitude': hospitalLongitude,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  Future<Map<String, dynamic>> getAdminRequests({int limit = 200}) async {
    try {
      final callable = _functions.httpsCallable('getAdminRequests');
      final result = await callable.call({'limit': limit});
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

  Future<Map<String, dynamic>> getRequestById({
    required String requestId,
  }) async {
    try {
      final callable = _functions.httpsCallable('getRequestById');
      final result = await callable.call({'requestId': requestId});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Lists requests created by the logged-in blood bank.
  Future<Map<String, dynamic>> getRequestsByBloodBankId({
    int limit = 80,
  }) async {
    try {
      final callable = _functions.httpsCallable('getRequestsByBloodBankId');
      final result = await callable.call({'limit': limit});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  /// Donor accepts or rejects a blood request (counts update for the blood bank).
  Future<Map<String, dynamic>> setDonorRequestResponse({
    required String requestId,
    required String response,
  }) async {
    try {
      final callable = _functions.httpsCallable('setDonorRequestResponse');
      final result = await callable.call({
        'requestId': requestId,
        'response': response,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Hospital updates units for a request they own.
  Future<Map<String, dynamic>> updateRequestUnits({
    required String requestId,
    required int units,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateRequestUnits');
      final result = await callable.call({
        'requestId': requestId,
        'units': units,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Hospital marks a request as completed.
  Future<Map<String, dynamic>> markRequestCompleted({
    required String requestId,
  }) async {
    try {
      final callable = _functions.httpsCallable('markRequestCompleted');
      final result = await callable.call({'requestId': requestId});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Current user’s notification inbox from the server.
  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final callable = _functions.httpsCallable('getNotifications');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  /// Chat transcript; pass [filterRecipientId] to narrow to one donor’s thread.
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

  /// Donor: ensures the personalized “Please {name}, {bank} needs your help” message exists.
  Future<Map<String, dynamic>> ensureDonorWelcomeMessage({
    required String requestId,
  }) async {
    try {
      final callable = _functions.httpsCallable('ensureDonorWelcomeMessage');
      final result = await callable.call({'requestId': requestId});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Hospital: donors who accepted / rejected this request (name + email).
  Future<Map<String, dynamic>> getRequestDonorResponses({
    required String requestId,
    bool includeLatestReports = true,
  }) async {
    try {
      final callable = _functions.httpsCallable('getRequestDonorResponses');
      final result = await callable.call({
        'requestId': requestId,
        'includeLatestReports': includeLatestReports,
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

  Future<Map<String, dynamic>> deleteOldNotifications({int days = 30}) async {
    try {
      final callable = _functions.httpsCallable('deleteOldNotifications');
      final result = await callable.call({'days': days});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    }
  }

  /// Get list of all donors (hospitals only).
  /// Each item includes `id`, `fullName`, `location`, `bloodType`, `email`, `phoneNumber`.
  /// Optional: filter by [bloodType] if provided.
  Future<Map<String, dynamic>> getDonors({
    String? bloodType,
    int limit = 80,
  }) async {
    try {
      final callable = _functions.httpsCallable('getDonors');
      final result = await callable.call({
        'limit': limit,
        if (bloodType != null) 'bloodType': bloodType,
      });
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
        if (e.message != null && e.message!.isNotEmpty) {
          if (e.message!.contains('index') || e.message!.contains('Index')) {
            userMessage = 'Database index required. Please contact support.';
          } else {
            // Use the server's message — avoid replacing "duplicate phone "
            // or other cases with generic "verify email".
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
            userMessage = 'Something went wrong. Please try again.';
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

  // --- Donation history ---

  /// Donor’s past donations / medical report entries (shape: `reports` list in the map).
  Future<Map<String, dynamic>> getDonationHistory({
    bool includeActiveProgress = true,
  }) async {
    try {
      final callable = _functions.httpsCallable('getDonationHistory');

      Future<Map<String, dynamic>> callWithFreshToken() async {
        final user = await _waitForCurrentUser();
        final idToken = await user?.getIdToken(true);
        if (idToken == null || idToken.isEmpty) {
          throw Exception('Please log in first');
        }
        final result = await callable.call({
          'includeActiveProgress': includeActiveProgress,
          'authToken': idToken,
          'idToken': idToken,
        });
        return Map<String, dynamic>.from(result.data);
      }

      try {
        return await callWithFreshToken();
      } on FirebaseFunctionsException catch (e) {
        if (e.code != 'unauthenticated') rethrow;
        await FirebaseAuth.instance.currentUser?.reload();
        return await callWithFreshToken();
      }
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  // --- Medical report (blood bank) ---

  /// After a donation: status `donated` or `restricted`, file URL, confirmed blood type, optional next eligible date.
  Future<Map<String, dynamic>> saveMedicalReport({
    required String requestId,
    required String donorId,
    required String status,
    String? restrictionReason,
    String? notes,
    required String reportFileUrl,
    String? canDonateAgainAt,
    required String confirmedBloodType,
    bool isPermanentBlock = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('saveMedicalReport');
      final result = await callable.call({
        'requestId': requestId,
        'donorId': donorId,
        'status': status,
        if (restrictionReason != null) 'restrictionReason': restrictionReason,
        if (notes != null) 'notes': notes,
        'reportFileUrl': reportFileUrl,
        if (canDonateAgainAt != null) 'canDonateAgainAt': canDonateAgainAt,
        'confirmedBloodType': confirmedBloodType,
        'isPermanentBlock': isPermanentBlock,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  // --- Appointments ---

  /// Blood bank proposes a donation time (`appointmentAtMillis` = Unix ms).
  Future<Map<String, dynamic>> scheduleDonorAppointment({
    required String requestId,
    required String donorId,
    required int appointmentAtMillis,
  }) async {
    try {
      final callable = _functions.httpsCallable('scheduleDonorAppointment');
      final result = await callable.call({
        'requestId': requestId,
        'donorId': donorId,
        'appointmentAt': appointmentAtMillis,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Donor: asks the blood bank to pick a new slot; returns donor to pending
  /// with [rescheduleReason] and [preferredAppointmentAtMillis] for the bank UI.
  Future<Map<String, dynamic>> requestAppointmentReschedule({
    required String requestId,
    required String reason,
    required int preferredAppointmentAtMillis,
  }) async {
    try {
      final callable = _functions.httpsCallable('requestAppointmentReschedule');
      final result = await callable.call({
        'requestId': requestId,
        'reason': reason,
        'preferredAppointmentAt': preferredAppointmentAtMillis,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Donors who completed at least one donation (`donated`) at this blood bank
  /// (medicalReports for this bank; excludes data removed when a request is deleted).
  Future<Map<String, dynamic>> listBloodBankPastDonors() async {
    try {
      final callable = _functions.httpsCallable('listBloodBankPastDonors');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  /// Medical reports for [donorId] at the authenticated blood bank only.
  Future<Map<String, dynamic>> getBloodBankDonorMedicalHistory({
    required String donorId,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'getBloodBankDonorMedicalHistory',
      );
      final result = await callable.call({'donorId': donorId});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionsException(e);
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }
}
