import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_functions_service.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String initialMessage;
  final String? recipientId; // Optional: filter messages for specific donor
  // معرف طلب الدم اللي حاب تتواصل فيه
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
  static const _listPadding = EdgeInsets.all(12);
  static const _inputSidePadding = 12.0;
  static const _bubbleRadius = 14.0;
  static const _inputRadius = 24.0;

  final TextEditingController _controller = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  final _cloudFunctions = CloudFunctionsService();
  bool _isSending = false;
  String? _requestOwnerId; // Store the request owner (hospital) ID

  @override
  void initState() {
    super.initState();
    _loadRequestOwner();
  }

  Future<void> _loadRequestOwner() async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .get();

      if (requestDoc.exists && mounted) {
        final data = requestDoc.data();
        setState(() {
          _requestOwnerId = data?['bloodBankId'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading request owner: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sends a message via Cloud Functions
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || currentUser == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      debugPrint('Sending message: $text');
      debugPrint('Request ID: ${widget.requestId}');

      final result = await _cloudFunctions.sendMessage(
        requestId: widget.requestId,
        text: text,
      );

      debugPrint('Message sent successfully: $result');

      _controller.clear();
      FocusScope.of(context).unfocus();

      // Show success feedback (optional)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending message: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _send(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  /// Builds a message bubble
  Widget _messageBubble(Map<String, dynamic> msg) {
    final isMe = msg['senderId'] == currentUser?.uid;
    final text = msg['text']?.toString() ?? '';
    final createdAt = msg['createdAt'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xffffe3e6) : const Color(0xffe0e0e0),
          borderRadius: BorderRadius.circular(_bubbleRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(fontSize: 14)),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTime(createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is Map) {
        // Handle Firestore timestamp format
        final seconds = timestamp['_seconds'] as int?;
        if (seconds != null) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        } else {
          return '';
        }
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return '';
      }
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('requests')
                    .doc(widget.requestId)
                    .collection('messages')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint('Chat StreamBuilder error: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(height: 8),
                          Text(
                            'Error loading messages: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final currentUserId = currentUser?.uid;

                  final messages = snapshot.data!.docs
                      .map(
                        (doc) => {
                          'id': doc.id,
                          ...doc.data() as Map<String, dynamic>,
                        },
                      )
                      .toList();

                  // Debug logging
                  debugPrint('=== CHAT FILTERING DEBUG ===');
                  debugPrint('Current user ID: $currentUserId');
                  debugPrint('Request owner ID: $_requestOwnerId');
                  debugPrint('Widget recipientId: ${widget.recipientId}');
                  debugPrint('Total messages in stream: ${messages.length}');

                  // Filter messages based on context:
                  // - If recipientId is provided (from contacts screen), show only messages for that recipient
                  // - Otherwise, show messages for current user (donor) or all messages (hospital)
                  final validMessages = messages.where((msg) {
                    if (msg['text'] == null || msg['text'].toString().isEmpty) {
                      debugPrint('  Message filtered: empty text');
                      return false;
                    }

                    // Handle different data types from Firestore
                    final senderId = msg['senderId']?.toString();
                    final recipientId = msg['recipientId']?.toString();
                    final senderRole = msg['senderRole']?.toString();
                    final text = msg['text']?.toString();

                    debugPrint(
                      '  Message: senderId=$senderId, recipientId=$recipientId, senderRole=$senderRole, text=${text != null && text.length > 30 ? text.substring(0, 30) : text}',
                    );

                    // If viewing from contacts screen (recipientId provided)
                    // This means blood bank is chatting with a specific donor
                    if (widget.recipientId != null) {
                      // Show ONLY messages for this specific recipient
                      // This ensures blood bank sees only this donor's personalized message, not all donors' messages
                      // Convert to strings to ensure proper comparison
                      final recipientIdStr = recipientId?.toString();
                      final widgetRecipientIdStr = widget.recipientId
                          .toString();
                      final senderIdStr = senderId?.toString();
                      final currentUserIdStr = currentUserId?.toString();

                      // STRICT FILTERING: Only show messages where recipientId exactly matches the selected donor
                      // This prevents showing personalized messages for other donors
                      final isForThisRecipient =
                          recipientIdStr != null &&
                          recipientIdStr == widgetRecipientIdStr;

                      // Also show messages sent by current user in this conversation
                      // But only if they don't have a recipientId (general messages) OR if recipientId matches
                      final isSentByCurrentUser =
                          senderIdStr != null &&
                          senderIdStr == currentUserIdStr &&
                          (recipientId == null ||
                              recipientIdStr == widgetRecipientIdStr);

                      final matches = isForThisRecipient || isSentByCurrentUser;

                      debugPrint(
                        '    -> Recipient view (blood bank chatting with specific donor): isForThisRecipient=$isForThisRecipient (recipientId=$recipientIdStr, widget.recipientId=$widgetRecipientIdStr), isSentByCurrentUser=$isSentByCurrentUser, matches=$matches',
                      );
                      return matches;
                    }

                    // Check if current user is the request owner (hospital)
                    final isRequestOwner = _requestOwnerId == currentUserId;

                    if (isRequestOwner) {
                      // BLOOD BANK VIEW: When blood bank opens chat without specific recipient
                      // Show only: messages they sent OR general messages (no recipientId)
                      // Do NOT show personalized messages for specific donors
                      final senderIdStr = senderId?.toString();
                      final currentUserIdStr = currentUserId?.toString();
                      final recipientIdStr = recipientId?.toString();

                      // Show messages where:
                      // 1. Blood bank sent the message
                      // 2. Message is general (no recipientId - for all donors)
                      // Do NOT show personalized messages (recipientId != null) unless viewing specific donor
                      final isSentByBloodBank =
                          senderIdStr != null &&
                          senderIdStr == currentUserIdStr;
                      final isGeneralMessage = recipientId == null;

                      final matches = isSentByBloodBank || isGeneralMessage;
                      debugPrint(
                        '    -> Blood bank view (no recipient): isSentByBloodBank=$isSentByBloodBank, isGeneralMessage=$isGeneralMessage, recipientId=$recipientIdStr, matches=$matches',
                      );
                      return matches;
                    } else {
                      // DONOR VIEW: Only show messages meant for this specific donor
                      // Convert to strings for proper comparison
                      final senderIdStr = senderId?.toString();
                      final recipientIdStr = recipientId?.toString();
                      final currentUserIdStr = currentUserId?.toString();

                      // 1. Messages sent by this donor
                      final isMyMessage =
                          senderIdStr != null &&
                          senderIdStr == currentUserIdStr;

                      // 2. Personalized messages from hospital where recipientId exactly matches current user
                      // This ensures each donor ONLY sees their own personalized message
                      final isPersonalizedForMe =
                          recipientIdStr != null &&
                          recipientIdStr == currentUserIdStr;

                      // Donors see ONLY:
                      // - Messages they sent
                      // - Personalized messages where recipientId == their ID
                      // This prevents donors from seeing messages meant for other donors
                      final matches = isMyMessage || isPersonalizedForMe;
                      debugPrint(
                        '    -> Donor view: isMyMessage=$isMyMessage, isPersonalizedForMe=$isPersonalizedForMe (recipientId=$recipientIdStr, currentUserId=$currentUserIdStr), matches=$matches',
                      );
                      return matches;
                    }
                  }).toList();

                  debugPrint(
                    'Valid messages after filtering: ${validMessages.length}',
                  );
                  debugPrint('=== END DEBUG ===');

                  if (validMessages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: _listPadding,
                    reverse: true,
                    itemCount: validMessages.length,
                    itemBuilder: (context, index) {
                      return _messageBubble(validMessages[index]);
                    },
                  );
                },
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                left: _inputSidePadding,
                right: _inputSidePadding,
                top: 8,
                bottom: _inputSidePadding + bottomInset,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isSending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _isSending
                            ? 'Sending...'
                            : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(_inputRadius),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
