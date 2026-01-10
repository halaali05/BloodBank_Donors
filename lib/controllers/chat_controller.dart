import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_functions_service.dart';
import '../services/auth_service.dart';

/// Controller for chat screen business logic
/// Separates business logic from UI for better maintainability
///
/// SECURITY ARCHITECTURE:
/// - All reads go through Cloud Functions (server-side)
/// - All writes go through Cloud Functions (server-side)
/// - Server validates user authentication
/// - Server ensures users can only access messages for requests they're authorized to view
class ChatController {
  final CloudFunctionsService _cloudFunctions;
  final AuthService _authService;
  final FirebaseAuth _auth;

  ChatController({
    CloudFunctionsService? cloudFunctions,
    AuthService? authService,
    FirebaseAuth? auth,
  }) : _cloudFunctions = cloudFunctions ?? CloudFunctionsService(),
       _authService = authService ?? AuthService(),
       _auth = auth ?? FirebaseAuth.instance;

  // ------------------ Authentication ------------------
  /// Gets the current authenticated user
  /// Returns null if user is not authenticated
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ------------------ Data Fetching ------------------
  /// Fetches all messages for a request via Cloud Functions
  ///
  /// Security Architecture:
  /// - All reads go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures users can only view messages for requests they're authorized to view
  ///
  /// Parameters:
  /// - [requestId]: The ID of the blood request
  /// - [filterRecipientId]: Optional. When provided, filters messages to show only those
  ///   for this specific recipient (used when blood bank chats with a specific donor)
  ///
  /// Returns:
  /// - List of message maps
  ///
  /// Throws:
  /// - Exception if fetch fails
  Future<List<Map<String, dynamic>>> fetchMessages(
    String requestId, {
    String? filterRecipientId,
  }) async {
    try {
      final result = await _cloudFunctions.getMessages(
        requestId: requestId,
        filterRecipientId: filterRecipientId,
      );
      final messagesData = result['messages'] as List<dynamic>? ?? [];

      return messagesData.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  /// Gets the current user's role (donor or hospital)
  ///
  /// Returns:
  /// - User role as string ('donor' or 'hospital')
  /// - null if user is not authenticated or role cannot be determined
  Future<String?> getUserRole() async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;
      return await _authService.getUserRole(user.uid);
    } catch (e) {
      return null;
    }
  }

  // ------------------ Message Operations ------------------
  /// Sends a message to the chat
  ///
  /// Handles message routing:
  /// - If recipientId is provided: sends personalized message to that donor
  /// - If donor sends message: automatically routes to blood bank
  /// - If blood bank sends without recipientId: sends general message to all donors
  ///
  /// Security Architecture:
  /// - All writes go through Cloud Functions (server-side)
  /// - Server validates user authentication
  /// - Server ensures users can only send messages for requests they're authorized to
  ///
  /// Parameters:
  /// - [requestId]: The ID of the blood request
  /// - [text]: The message text
  /// - [recipientId]: Optional recipient ID for personalized messages
  /// - [requestOwnerId]: Optional request owner ID for automatic routing
  /// - [currentUserRole]: Optional current user role for routing logic
  ///
  /// Returns:
  /// - void on success
  ///
  /// Throws:
  /// - Exception if send fails
  Future<void> sendMessage({
    required String requestId,
    required String text,
    String? recipientId,
    String? requestOwnerId,
    String? currentUserRole,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // CRITICAL: Preserve recipientId if provided (for personalized messages)
      // This ensures blood bank messages to specific donors are personalized
      String? messageRecipientId;

      if (recipientId != null && recipientId.isNotEmpty) {
        // recipientId is provided - use it (personalized message to specific donor)
        messageRecipientId = recipientId.trim();
      } else {
        // No recipientId provided
        // Determine if current user is the request owner (blood bank)
        final isRequestOwner =
            requestOwnerId != null && requestOwnerId == user.uid;

        if (!isRequestOwner && requestOwnerId != null) {
          // Donor sending message without recipientId - route to blood bank
          messageRecipientId = requestOwnerId;
        }
        // If blood bank sends without recipientId, messageRecipientId stays null (general message)
      }

      // CRITICAL: Verify recipientId is not lost
      if (recipientId != null &&
          recipientId.isNotEmpty &&
          messageRecipientId == null) {
        // Restore it if it was lost
        messageRecipientId = recipientId.trim();
      }

      await _cloudFunctions.sendMessage(
        requestId: requestId,
        text: text,
        recipientId: messageRecipientId,
      );
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // ------------------ Data Processing ------------------
  /// Formats timestamp to readable time string
  /// Shows "Just now", "5m ago", "2h ago", or time if older than today
  ///
  /// Parameters:
  /// - [dateTime]: The DateTime to format
  ///
  /// Returns:
  /// - Formatted time string
  String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return '${difference.inHours}h ago';

      // For older messages, show time
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// Formats timestamp from milliseconds to readable time string
  ///
  /// Parameters:
  /// - [timestampMillis]: Timestamp in milliseconds
  ///
  /// Returns:
  /// - Formatted time string
  String formatTimeFromMillis(int? timestampMillis) {
    if (timestampMillis == null) return '';
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      return formatTime(dateTime);
    } catch (_) {
      return '';
    }
  }

  /// Checks if a message is from the current user
  ///
  /// Parameters:
  /// - [message]: The message map
  ///
  /// Returns:
  /// - true if message is from current user, false otherwise
  bool isMessageFromCurrentUser(Map<String, dynamic> message) {
    final user = getCurrentUser();
    if (user == null) return false;
    return message['senderId'] == user.uid;
  }
}
