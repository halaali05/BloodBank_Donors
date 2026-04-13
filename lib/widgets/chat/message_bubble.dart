import 'package:flutter/material.dart';

/// Widget that displays a single message bubble in the chat
/// Messages from current user appear on the right, others on the left

class MessageBubble extends StatefulWidget {
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
    this.maxWidthPercentage = 0.85,
    this.borderRadius = 16.0,
    this.currentUserColor = const Color(0xffffe3e6),
    this.otherUserColor = const Color(0xffe0e0e0),
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.message['text']?.toString() ?? '';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: widget.isFromCurrentUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width *
                  widget.maxWidthPercentage,
            ),
            decoration: BoxDecoration(
              color: widget.isFromCurrentUser
                  ? widget.currentUserColor
                  : widget.otherUserColor,

              // bubble shape
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    Radius.circular(widget.isFromCurrentUser ? 16 : 0),
                bottomRight:
                    Radius.circular(widget.isFromCurrentUser ? 0 : 16),
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                
                Text(
                  text,
                  style: const TextStyle(fontSize: 14),
                ),

                
                if (widget.formattedTime.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.formattedTime,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}