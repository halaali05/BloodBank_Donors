import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_functions_service.dart';
import '../services/auth_service.dart';

/// Result of loading messages for a request (includes blood bank id for routing).
class ChatMessagesSnapshot {
  final List<Map<String, dynamic>> messages;
  final String? bloodBankId;

  const ChatMessagesSnapshot({
    required this.messages,
    this.bloodBankId,
  });
}

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
  /// Returns messages and request owner id (blood bank) when present.
  ///
  /// Throws:
  /// - Exception if fetch fails
  Future<ChatMessagesSnapshot> fetchMessages(
    String requestId, {
    String? filterRecipientId,
  }) async {
    try {
      final result = await _cloudFunctions.getMessages(
        requestId: requestId,
        filterRecipientId: filterRecipientId,
      );
      final messagesData = result['messages'] as List<dynamic>? ?? [];
      final bloodBankId = result['bloodBankId'] as String?;

      return ChatMessagesSnapshot(
        messages: messagesData.map((m) => Map<String, dynamic>.from(m)).toList(),
        bloodBankId: bloodBankId,
      );
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  /// Creates the same welcome line as the new-request trigger, if missing.
  Future<void> ensureDonorWelcomeMessage(String requestId) async {
    await _cloudFunctions.ensureDonorWelcomeMessage(requestId: requestId);
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
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final messageRecipientId = _resolveRecipientId(
        currentUserId: user.uid,
        recipientId: recipientId,
        requestOwnerId: requestOwnerId,
      );

      await _cloudFunctions.sendMessage(
        requestId: requestId,
        text: text,
        recipientId: messageRecipientId,
      );
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  String? _resolveRecipientId({
    required String currentUserId,
    String? recipientId,
    String? requestOwnerId,
  }) {
    final trimmedRecipientId = recipientId?.trim();
    if (trimmedRecipientId != null && trimmedRecipientId.isNotEmpty) {
      // Personalized message to a specific recipient.
      return trimmedRecipientId;
    }

    final isRequestOwner =
        requestOwnerId != null && requestOwnerId == currentUserId;
    if (!isRequestOwner && requestOwnerId != null) {
      // Donor sends to request owner (blood bank) when no explicit recipient is provided.
      return requestOwnerId;
    }

    // Request owner sends broadcast message.
    return null;
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
