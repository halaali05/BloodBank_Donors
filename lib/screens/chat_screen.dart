import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String initialMessage;
  // معرف طلب الدم اللي حاب تتواصل فيه
  const ChatScreen({
    super.key,
    required this.requestId,
    required this.initialMessage,
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sends a message to Firestore
  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || currentUser == null) return;

    final msgData = {
      'text': text,
      'senderId': currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'senderRole': 'donor', // لأن المتبرع يرسل من هنا
    };

    await FirebaseFirestore.instance
        .collection('requests')
        .doc(widget.requestId)
        .collection('messages')
        .add(msgData);

    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  /// Builds a message bubble
  Widget _messageBubble(Map<String, dynamic> msg) {
    final isMe = msg['senderId'] == currentUser?.uid;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xffffe3e6) : const Color(0xffe0e0e0),
          borderRadius: BorderRadius.circular(_bubbleRadius),
        ),
        child: Text(msg['text'] ?? ''),
      ),
    );
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
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No messages yet'));
                  }

                  final messages = snapshot.data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();

                  return ListView.builder(
                    padding: _listPadding,
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _messageBubble(messages[index]);
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
                  IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
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
