import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/notifications_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_bar_with_logo.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/error_box.dart';
import '../widgets/notifications/notification_item_cloud.dart';

/// Screen that displays all user notifications
/// Has two tabs: "All" and "Unread" notifications
///
/// SECURITY ARCHITECTURE:
/// - Read operations: All go through Cloud Functions (server-side)
///   - Notifications: Read via getNotifications Cloud Function
/// - Write operations: All go through Cloud Functions (server-side)
///
/// NOTE: Real-time updates are achieved through periodic polling (every 10 seconds)
/// since Cloud Functions cannot return real-time streams.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsController _controller = NotificationsController();

  Timer? _refreshTimer;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();

    // Set up periodic refresh (every 30 seconds) for real-time updates
    // Increased interval to improve performance
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ------------------ Data Loading ------------------
  /// Loads notifications via Cloud Functions
  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await _controller.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  // ------------------ Notification Actions ------------------
  /// Handles marking all notifications as read
  Future<void> _handleMarkAllAsRead() async {
    try {
      await _controller.markAllAsRead();
      if (!mounted) return;

      // Refresh notifications after marking as read
      await _loadNotifications();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to mark as read: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ------------------ UI Build ------------------
  @override
  Widget build(BuildContext context) {
    final user = _controller.getCurrentUser();

    if (user == null) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: AppTheme.softBg,
          appBar: AppBarWithLogo(
            title: 'Notifications',
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: const Center(
            child: Text(
              'Please login to see notifications.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppTheme.softBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                tooltip: 'Mark all as read',
                icon: const Icon(Icons.done_all, color: AppTheme.deepRed),
                onPressed: _handleMarkAllAsRead,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Image.asset(
                  'images/logoBLOOD.png',
                  height: 34,
                  fit: BoxFit.contain,
                ),
              ),
            ],
            bottom: const TabBar(
              labelColor: AppTheme.deepRed,
              unselectedLabelColor: Colors.black54,
              indicatorColor: AppTheme.deepRed,
              tabs: [
                Tab(text: 'All'),
                Tab(text: 'Unread'),
              ],
            ),
          ),
          body: _isLoading && _notifications.isEmpty
              ? const LoadingIndicator()
              : _error != null
              ? ErrorBox(title: 'Error loading notifications', message: _error!)
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: _notifications.isEmpty
                      ? const Center(
                          child: Text(
                            'No notifications yet.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : TabBarView(
                          children: [
                            _NotificationsList(
                              notifications: _notifications,
                              controller: _controller,
                              onRefresh: _loadNotifications,
                            ),
                            _NotificationsList(
                              notifications: _controller.getUnreadNotifications(
                                _notifications,
                              ),
                              controller: _controller,
                              onRefresh: _loadNotifications,
                            ),
                          ],
                        ),
                ),
        ),
      ),
    );
  }
}

/// Widget that displays a list of notifications
class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.notifications,
    required this.controller,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> notifications;
  final NotificationsController controller;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const Center(
        child: Text(
          'No notifications here.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.padding,
        vertical: 12,
      ),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final notificationId =
            (notification['id'] as String?) ??
            (notification['notificationId'] as String?) ??
            '';
        return NotificationItemCloud(
          notification: notification,
          formatTime: (context, timestamp) =>
              controller.formatTime(context, timestamp),
          onMarkAsRead: notificationId.isNotEmpty
              ? (id) => controller.markAsRead(id)
              : null,
          onRefresh: () {
            // Refresh notifications list after marking as read
            // Use a small delay to ensure Cloud Function has processed the update
            Future.delayed(const Duration(milliseconds: 300), () {
              onRefresh();
            });
          },
        );
      },
    );
  }
}
