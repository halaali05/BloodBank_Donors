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

                  // Filter messages based on context:
                  // - If recipientId is provided (from contacts screen), show only messages for that recipient
                  // - Otherwise, show messages for current user (donor) or all messages (hospital)
                  final validMessages = messages.where((msg) {
                    if (msg['text'] == null || msg['text'].toString().isEmpty) {
                      return false;
                    }

                    final senderId = msg['senderId'];
                    final recipientId = msg['recipientId'];

                    // If viewing from contacts screen (recipientId provided)
                    // This means hospital is chatting with a specific donor
                    if (widget.recipientId != null) {
                      final selectedDonorId = widget.recipientId.toString();

                      // Show:
                      // 1. Personalized message for this specific recipient (recipientId matches selected donor)
                      // 2. Regular chat messages (no recipientId) sent by hospital
                      // 3. Messages sent by the donor themselves (senderId matches selected donor)
                      // 4. Messages sent by hospital with recipientId matching selected donor (fallback)
                      final msgRecipientId = recipientId?.toString();
                      final msgSenderId = senderId?.toString();

                      final isPersonalizedForThisDonor =
                          msgRecipientId != null &&
                          msgRecipientId == selectedDonorId;
                      final isRegularChatMessage =
                          msgRecipientId == null &&
                          msgSenderId == currentUserId?.toString();
                      final isDonorMessage =
                          msgSenderId != null && msgSenderId == selectedDonorId;
                      // Fallback: hospital sent message to this donor (covers personalized messages)
                      final isHospitalToThisDonor =
                          msgSenderId == currentUserId?.toString() &&
                          msgRecipientId == selectedDonorId;

                      return isPersonalizedForThisDonor ||
                          isRegularChatMessage ||
                          isDonorMessage ||
                          isHospitalToThisDonor;
                    }

                    // Default view (no specific recipient selected)
                    // For hospitals: show all messages
                    // For donors: show only their personalized messages or messages they sent
                    final isHospital =
                        senderId == currentUserId &&
                        msg['senderRole'] == 'hospital';

                    if (isHospital) {
                      return true; // Hospitals see all messages
                    } else {
                      // Donors see: their messages OR messages intended for them
                      return senderId == currentUserId ||
                          recipientId == currentUserId ||
                          recipientId == null;
                    }
                  }).toList();

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
