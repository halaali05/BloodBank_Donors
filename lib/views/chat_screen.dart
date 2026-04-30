import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import '../shared/utils/snack_bar_helper.dart';
import '../shared/widgets/common/error_box.dart';
import '../shared/widgets/chat/message_bubble.dart';
import '../shared/widgets/chat/chat_input_field.dart';

/// Chat between blood bank and donors for one request.
/// Can be a group thread or a one-to-one thread when [recipientId] is set.
///
/// Data uses Cloud Functions. New messages appear when the app reloads the list (timer ~10s).
class ChatScreen extends StatefulWidget {
  /// Blood request this thread belongs to.
  final String requestId;

  /// Hint text for notifications; real content still comes from the server.
  final String initialMessage;

  /// When set, only that donor’s side of the conversation is shown.
  final String? recipientId;

  /// If true, send [initialMessage] once right after open.
  final bool autoSendInitialMessage;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.initialMessage,
    this.recipientId,
    this.autoSendInitialMessage = false,
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
  bool _didAutoSendInitialMessage = false;

  /// Blood bank user id for routing outgoing messages.
  String? _requestOwnerId;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage.trim().isNotEmpty && widget.recipientId != null) {
      _textController.text = widget.initialMessage.trim();
      if (widget.autoSendInitialMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _didAutoSendInitialMessage) return;
          _didAutoSendInitialMessage = true;
          _sendMessage();
        });
      }
    }
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
    String? role;
    try {
      role = await _controller.getUserRole();
    } catch (_) {
      // OK if role can’t be read; messages can still load.
    }
    if (role == 'donor') {
      try {
        await _controller.ensureDonorWelcomeMessage(widget.requestId);
      } catch (_) {
        // Welcome line may already exist.
      }
    }
    _loadMessages();

    // Poll so new messages show up without live Firestore listeners.
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadMessages(showLoading: false);
      }
    });
  }

  // ------------------ Data Loading ------------------
  /// Loads messages via Cloud Functions
  Future<void> _loadMessages({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // Bank talking to one donor: server filters by recipient.
      final snapshot = await _controller.fetchMessages(
        widget.requestId,
        filterRecipientId: widget.recipientId,
      );
      if (mounted) {
        setState(() {
          _messages = snapshot.messages;
          _requestOwnerId = snapshot.bloodBankId ?? _requestOwnerId;
          _error = null;
          if (showLoading) _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          if (showLoading) _isLoading = false;
        });
      }
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
      );

      if (!mounted) return;
      _textController.clear();
      FocusScope.of(context).unfocus();

      // Refresh messages after sending
      await _loadMessages(showLoading: false);

      if (mounted) {
        SnackBarHelper.success(
          context,
          'Message sent',
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.failure(
          context,
          'Failed to send message: '
          '${SnackBarHelper.stripExceptionPrefix(e.toString())}',
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _sendMessage,
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
                                final dateTime = _parseCreatedAt(
                                  msg['createdAt'],
                                );

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

  DateTime? _parseCreatedAt(dynamic createdAt) {
    if (createdAt == null) return null;
    if (createdAt is DateTime) return createdAt;
    if (createdAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(createdAt);
    }
    if (createdAt is Map) {
      final seconds = createdAt['_seconds'] as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return null;
  }
}
