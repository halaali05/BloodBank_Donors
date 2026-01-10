import 'package:flutter/material.dart';

/// Widget that displays a single message bubble in the chat
/// Messages from current user appear on the right, others on the left
class MessageBubble extends StatelessWidget {
  /// Message data
  final Map<String, dynamic> message;

  /// Whether this message is from the current user
  final bool isFromCurrentUser;

  /// Formatted time string to display
  final String formattedTime;

  /// Maximum width of the bubble (as percentage of screen width)
  final double maxWidthPercentage;

  /// Border radius of the bubble
  final double borderRadius;

  /// Background color for current user's messages
  final Color currentUserColor;

  /// Background color for other user's messages
  final Color otherUserColor;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    required this.formattedTime,
    this.maxWidthPercentage = 0.75,
    this.borderRadius = 14.0,
    this.currentUserColor = const Color(0xffffe3e6),
    this.otherUserColor = const Color(0xffe0e0e0),
  });

  @override
  Widget build(BuildContext context) {
    final text = message['text']?.toString() ?? '';

    return Align(
      alignment: isFromCurrentUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * maxWidthPercentage,
        ),
        decoration: BoxDecoration(
          color: isFromCurrentUser ? currentUserColor : otherUserColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(fontSize: 14)),
            if (formattedTime.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  formattedTime,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
