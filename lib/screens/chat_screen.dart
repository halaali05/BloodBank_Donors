import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/chat_controller.dart';
import '../widgets/common/error_box.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/chat_input_field.dart';

/// Chat screen for messaging between blood banks and donors
/// Supports both general messages (to all donors) and personalized messages (to specific donor)
///
/// SECURITY ARCHITECTURE:
/// - Read operations: All go through Cloud Functions (server-side)
///   - Messages: Read via getMessages Cloud Function
/// - Write operations: All go through Cloud Functions (server-side)
///   - Messages: Sent via sendMessage Cloud Function
///
/// NOTE: Real-time updates are achieved through periodic polling (every 5 seconds)
/// since Cloud Functions cannot return real-time streams.
class ChatScreen extends StatefulWidget {
  /// ID of the blood request this chat is associated with
  final String requestId;

  /// Initial message text (not used, kept for compatibility)
  final String initialMessage;

  /// Optional: If provided, filters messages to show only those for this specific donor
  /// Used when blood bank wants to chat with a specific donor
  final String? recipientId;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.initialMessage,
    this.recipientId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // UI constants
  static const _listPadding = EdgeInsets.all(12);

  // Controllers and services
  final ChatController _controller = ChatController();
  final TextEditingController _textController = TextEditingController();

  // State
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  // Request and user info
  String? _requestOwnerId; // ID of the blood bank that created the request
  String? _currentUserRole; // Current user's role (donor or hospital)

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  // ------------------ Initialization ------------------
  /// Initializes chat by loading user role and messages
  Future<void> _initializeChat() async {
    await _loadUserRole();
    _loadMessages();

    // Set up periodic refresh (every 10 seconds) for real-time updates
    // Increased interval to improve performance
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadMessages();
      }
    });
  }

  // ------------------ Data Loading ------------------
  /// Loads messages via Cloud Functions
  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Pass recipientId to filter messages when blood bank chats with specific donor
      final messages = await _controller.fetchMessages(
        widget.requestId,
        filterRecipientId: widget.recipientId,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// Loads the current user's role (donor or hospital)
  /// Used for message routing logic
  Future<void> _loadUserRole() async {
    try {
      final role = await _controller.getUserRole();
      if (mounted) {
        setState(() {
          _currentUserRole = role;
        });
      }
    } catch (e) {
      // Error loading user role - continue without it
    }
  }

  // ------------------ Message Operations ------------------
  /// Sends a message to the chat
  /// Handles message routing:
  /// - If recipientId is provided: sends personalized message to that donor
  /// - If donor sends message: automatically routes to blood bank
  /// - If blood bank sends without recipientId: sends general message to all donors
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final currentUser = _controller.getCurrentUser();
    if (text.isEmpty || currentUser == null || _isSending) return;

    setState(() => _isSending = true);

    try {
      // CRITICAL: Ensure recipientId is preserved
      final recipientIdToSend = widget.recipientId;

      await _controller.sendMessage(
        requestId: widget.requestId,
        text: text,
        recipientId: recipientIdToSend,
        requestOwnerId: _requestOwnerId,
        currentUserRole: _currentUserRole,
      );

      _textController.clear();
      FocusScope.of(context).unfocus();

      // Refresh messages after sending
      await _loadMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send message: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _sendMessage,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ------------------ UI Build ------------------

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final currentUser = _controller.getCurrentUser();

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(
          child: Text(
            'Please login to send messages.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ErrorBox(
                      title: 'Error loading messages',
                      message: _error!,
                      onRetry: _loadMessages,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMessages,
                      child: _messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              padding: _listPadding,
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final createdAt = msg['createdAt'];
                                DateTime? dateTime;

                                // Handle different timestamp formats
                                if (createdAt != null) {
                                  if (createdAt is DateTime) {
                                    dateTime = createdAt;
                                  } else if (createdAt is int) {
                                    dateTime =
                                        DateTime.fromMillisecondsSinceEpoch(
                                          createdAt,
                                        );
                                  } else if (createdAt is Map) {
                                    // Firestore Timestamp format
                                    final seconds =
                                        createdAt['_seconds'] as int?;
                                    if (seconds != null) {
                                      dateTime =
                                          DateTime.fromMillisecondsSinceEpoch(
                                            seconds * 1000,
                                          );
                                    }
                                  }
                                }

                                return MessageBubble(
                                  message: msg,
                                  isFromCurrentUser: _controller
                                      .isMessageFromCurrentUser(msg),
                                  formattedTime: _controller.formatTime(
                                    dateTime,
                                  ),
                                );
                              },
                            ),
                    ),
            ),
            ChatInputField(
              controller: _textController,
              isSending: _isSending,
              onSend: _sendMessage,
              bottomPadding: safeBottom,
            ),
          ],
        ),
      ),
    );
  }
}
