import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _listPadding = EdgeInsets.all(12);
  static const _inputSidePadding = 12.0;
  static const _bubbleRadius = 14.0;
  static const _inputRadius = 24.0;

  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = <String>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sends a message in the chat
  ///
  /// Adds the message text to the messages list and clears the input field.
  /// Messages are inserted at the start of the list because the ListView
  /// is reversed (newest messages appear at the bottom).
  ///
  /// Does nothing if the message text is empty.
  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      // insert at start because list is reversed (keeps latest at bottom visually)
      _messages.insert(0, text);
    });

    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  /// Builds a message bubble widget
  ///
  /// Creates a styled container for displaying a chat message.
  /// Messages are aligned to the right with rounded corners and
  /// the app's primary color scheme.
  ///
  /// Parameters:
  /// - [msg]: The message text to display
  ///
  /// Returns:
  /// - An [Align] widget containing a styled message bubble
  Widget _messageBubble(String msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xffffe3e6),
          borderRadius: BorderRadius.circular(_bubbleRadius),
        ),
        child: Text(msg),
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
              child: _messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                      padding: _listPadding,
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _messageBubble(_messages[index]);
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
