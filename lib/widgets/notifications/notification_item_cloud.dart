import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../screens/chat_screen.dart';
import '../../screens/request_details_screen.dart';

/// Widget that displays a single notification in the notifications list
/// Shows notification details, urgent badge, and allows navigation to request details and chat
class NotificationItemCloud extends StatelessWidget {
  /// Notification data from Cloud Functions
  final Map<String, dynamic> notification;

  /// Function to format timestamp for display
  final String Function(BuildContext, int?) formatTime;

  /// Callback to mark notification as read
  final Future<void> Function(String)? onMarkAsRead;

  /// Callback to refresh notifications after marking as read
  final VoidCallback? onRefresh;

  const NotificationItemCloud({
    super.key,
    required this.notification,
    required this.formatTime,
    this.onMarkAsRead,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final data = notification;
    final notificationId =
        (data['id'] as String?) ?? (data['notificationId'] as String?) ?? '';
    final isRead = (data['isRead'] == true) || (data['read'] == true);
    final requestId = (data['requestId'] as String?) ?? '';
    final createdAt = data['createdAt'] as int?;
    final createdAtText = formatTime(context, createdAt);
    final isUrgent = data['isUrgent'] == true;
    final cardBg = isUrgent ? AppTheme.urgentCardBg : Colors.white;
    final iconData = isUrgent
        ? Icons.warning_amber_rounded
        : Icons.notifications;
    final title = data['title'] as String? ?? 'Blood Request';
    final body = data['body'] as String? ?? '';

    // Handle tap to open request details
    Future<void> handleCardTap() async {
      if (requestId.isEmpty) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Mark notification as read if not already read (FIRST - before navigation)
      if (!isRead && notificationId.isNotEmpty && onMarkAsRead != null) {
        try {
          await onMarkAsRead!(notificationId);
          // Refresh notifications list to update UI
          if (onRefresh != null) {
            onRefresh!();
          }
        } catch (e) {
          // Silently fail - don't block navigation
        }
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetailsScreen(requestId: requestId),
          ),
        );
      }
    }

    // Handle message button tap
    Future<void> handleMessageTap() async {
      if (requestId.isEmpty) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Mark notification as read if not already read (FIRST - before navigation)
      if (!isRead && notificationId.isNotEmpty && onMarkAsRead != null) {
        try {
          await onMarkAsRead!(notificationId);
          // Refresh notifications list to update UI
          if (onRefresh != null) {
            onRefresh!();
          }
        } catch (e) {
          // Silently fail - don't block navigation
        }
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(requestId: requestId, initialMessage: body),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: isRead ? Colors.transparent : AppTheme.deepRed,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: handleCardTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconData, color: AppTheme.deepRed, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isRead
                                    ? Colors.black87
                                    : AppTheme.deepRed,
                              ),
                            ),
                          ),
                          if (isUrgent)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.deepRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Urgent',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (createdAtText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          createdAtText,
                          style: const TextStyle(
                            color: Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: handleMessageTap,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Messages'),
              style: AppTheme.primaryButtonStyle(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
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
