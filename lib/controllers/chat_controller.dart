import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_functions_service.dart';
import '../services/auth_service.dart';

/// Load result for chat: messages plus blood bank id used to route replies.
class ChatMessagesSnapshot {
  final List<Map<String, dynamic>> messages;
  final String? bloodBankId;

  const ChatMessagesSnapshot({required this.messages, this.bloodBankId});
}

/// Chat: fetch/send messages and light formatting helpers.
///
/// Server work is done via [CloudFunctionsService] (not direct database access).
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

  // --- Auth ---

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // --- Load ---

  /// Loads messages; [filterRecipientId] limits to one donor when the bank uses private chat.
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
        messages: messagesData
            .map((m) => Map<String, dynamic>.from(m))
            .toList(),
        bloodBankId: bloodBankId,
      );
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  /// Ensures donors see an intro line (same wording the backend uses on new requests).
  Future<void> ensureDonorWelcomeMessage(String requestId) async {
    await _cloudFunctions.ensureDonorWelcomeMessage(requestId: requestId);
  }

  /// `'donor'` or `'hospital'`, or null if unknown.
  Future<String?> getUserRole() async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;
      return await _authService.getUserRole(user.uid);
    } catch (e) {
      return null;
    }
  }

  // --- Send ---

  /// Sends [text]; [recipientId] targets one donor; otherwise routing uses [requestOwnerId] (bank vs donor).
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
      // Directed message to one donor.
      return trimmedRecipientId;
    }

    final isRequestOwner =
        requestOwnerId != null && requestOwnerId == currentUserId;
    if (!isRequestOwner && requestOwnerId != null) {
      // Donor replying → message goes to the blood bank that owns the request.
      return requestOwnerId;
    }

    // Bank user: no recipient ⇒ broadcast-style thread.
    return null;
  }

  // --- Time labels ---

  /// Short relative label ("Just now", "5m ago", …).
  String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return '${difference.inHours}h ago';

      // Same calendar day → clock time only.
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String formatTimeFromMillis(int? timestampMillis) {
    if (timestampMillis == null) return '';
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      return formatTime(dateTime);
    } catch (_) {
      return '';
    }
  }

  bool isMessageFromCurrentUser(Map<String, dynamic> message) {
    final user = getCurrentUser();
    if (user == null) return false;
    return message['senderId'] == user.uid;
  }

  /// Donor ids who wrote at least once (excluding the bank).
  Future<List<String>> getChatParticipants(String requestId) async {
    final snapshot = await fetchMessages(requestId);

    final messages = snapshot.messages;
    final bloodBankId = snapshot.bloodBankId;

    final userIds = <String>{};

    for (var msg in messages) {
      final sender = msg['senderId'];

      if (sender != null && sender != bloodBankId) {
        userIds.add(sender);
      }
    }

    return userIds.toList();
  }

  /// Simple “unread per donor” map from message shape (bank as receiver).
  Future<Map<String, int>> getUnreadCountPerUser(String requestId) async {
    final snapshot = await fetchMessages(requestId);

    final messages = snapshot.messages;
    final bloodBankId = snapshot.bloodBankId;

    final unreadCount = <String, int>{};

    for (var msg in messages) {
      final sender = msg['senderId'];
      final receiver = msg['recipientId'];

      // Count messages sent to the bank (receiver = bank id).
      if (receiver == bloodBankId && sender != null) {
        unreadCount[sender] = (unreadCount[sender] ?? 0) + 1;
      }
    }

    return unreadCount;
  }
}
