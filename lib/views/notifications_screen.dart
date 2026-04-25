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
/// NOTE: Updates are refreshed periodically through Cloud Functions.
/// since Cloud Functions cannot return real-time streams.
class NotificationsScreen extends StatefulWidget {
  /// Initial tab index (0 = All, 1 = Unread)
  final int initialTabIndex;

  const NotificationsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationsController _controller = NotificationsController();

  Timer? _refreshTimer;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isMarkingAll = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );
    _loadNotifications();

    // Ensure tab is set to the correct index after the first frame
    // This handles cases where the widget is rebuilt or navigation happens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialTabIndex != 0) {
        // Use a small delay to ensure the TabBarView is fully built
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && widget.initialTabIndex < _tabController.length) {
            // Always animate to the initial tab index to ensure it's set correctly
            _tabController.animateTo(widget.initialTabIndex);
          }
        });
      }
    });

    // Silent refresh keeps the list current without showing a loading screen.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadNotifications(showLoading: false);
      }
    });
  }

  @override
  void didUpdateWidget(NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the initialTabIndex changed, animate to the new tab
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tabController.animateTo(widget.initialTabIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ------------------ Data Loading ------------------
  /// Loads notifications via Cloud Functions
  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final notifications = await _controller.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          if (showLoading) _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          if (showLoading) _isLoading = false;
        });
      }
    }
  }

  // ------------------ Notification Actions ------------------
  /// Handles marking all notifications as read
  Future<void> _handleMarkAllAsRead() async {
    if (_isMarkingAll) return;
    final previous = _notifications
        .map((n) => Map<String, dynamic>.from(n))
        .toList();
    final hasUnread = previous.any(
      (n) => n['isRead'] != true && n['read'] != true,
    );
    if (!hasUnread) return;

    setState(() {
      _isMarkingAll = true;
      _notifications = _notifications
          .map((n) => {...n, 'read': true, 'isRead': true})
          .toList();
    });

    try {
      await _controller.markAllAsRead();
      if (!mounted) return;

      unawaited(_loadNotifications(showLoading: false));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _notifications = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to mark as read: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _markNotificationAsReadFast(String notificationId) async {
    if (notificationId.isEmpty) return;

    var changed = false;
    setState(() {
      _notifications = _notifications.map((n) {
        final id =
            (n['id'] as String?) ?? (n['notificationId'] as String?) ?? '';
        if (id != notificationId || n['read'] == true || n['isRead'] == true) {
          return n;
        }
        changed = true;
        return {...n, 'read': true, 'isRead': true};
      }).toList();
    });
    if (!changed) return;

    unawaited(
      _controller
          .markAsRead(notificationId)
          .then((_) => _loadNotifications(showLoading: false))
          .catchError((_) {
            if (!mounted) return;
            setState(() {
              _notifications = _notifications.map((n) {
                final id =
                    (n['id'] as String?) ??
                    (n['notificationId'] as String?) ??
                    '';
                if (id != notificationId) return n;
                return {...n, 'read': false, 'isRead': false};
              }).toList();
            });
          }),
    );
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
              icon: _isMarkingAll
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.deepRed,
                      ),
                    )
                  : const Icon(Icons.done_all, color: AppTheme.deepRed),
              onPressed: _isMarkingAll ? null : _handleMarkAllAsRead,
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
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppTheme.deepRed,
            unselectedLabelColor: Colors.black54,
            indicatorColor: AppTheme.deepRed,
            tabs: const [
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
                        controller: _tabController,
                        children: [
                          _NotificationsList(
                            notifications: _notifications,
                            controller: _controller,
                            onMarkAsRead: _markNotificationAsReadFast,
                          ),
                          _NotificationsList(
                            notifications: _controller.getUnreadNotifications(
                              _notifications,
                            ),
                            controller: _controller,
                            onMarkAsRead: _markNotificationAsReadFast,
                          ),
                        ],
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
    required this.onMarkAsRead,
  });

  final List<Map<String, dynamic>> notifications;
  final NotificationsController controller;
  final Future<void> Function(String) onMarkAsRead;

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
          onMarkAsRead: notificationId.isNotEmpty ? onMarkAsRead : null,
        );
      },
    );
  }
}
