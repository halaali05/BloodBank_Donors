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
    this.borderRadius = 30.0, // خليتها أكبر شوي
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          enabled: !isSending,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onSend(),
          decoration: InputDecoration(
            hintText: isSending ? 'Sending...' : 'Type a message...',
            
            suffixIcon: isSending
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.red),
                    onPressed: onSend,
                  ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide.none,
            ),

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14, 
            ),
          ),
        ),
      ),
    );
  }
}