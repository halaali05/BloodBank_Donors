import 'package:flutter/material.dart';

/// Widget that displays the chat input field with send button
class ChatInputField extends StatelessWidget {
  /// Controller for the text input
  final TextEditingController controller;

  /// Whether a message is currently being sent
  final bool isSending;

  /// Callback when send button is pressed
  final VoidCallback onSend;

  /// Side padding for the input field
  final double sidePadding;

  /// Border radius of the input field
  final double borderRadius;

  /// Bottom padding (including safe area)
  final double bottomPadding;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
    this.sidePadding = 12.0,
    this.borderRadius = 24.0,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sidePadding,
        8,
        sidePadding,
        sidePadding + bottomPadding,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: isSending ? null : onSend,
            icon: isSending
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
              controller: controller,
              enabled: !isSending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: isSending ? 'Sending...' : 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
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
    );
  }
}
