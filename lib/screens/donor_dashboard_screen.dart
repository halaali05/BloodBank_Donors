import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import '../models/blood_request_model.dart';
import '../controllers/donor_dashboard_controller.dart';
import 'notifications_screen.dart';
import '../services/fcm_service.dart';
import 'donor_profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_bar_with_logo.dart';
import '../widgets/common/error_box.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/dashboard/donor_header.dart';
import '../widgets/dashboard/donor_request_card.dart';

/// Main dashboard screen for donors
///
/// Displays all available blood requests from blood banks
/// Allows donors to view requests and start conversations
///
/// SECURITY ARCHITECTURE:
/// - Read operations: All go through Cloud Functions (server-side)
///   - Requests: Read via getRequests Cloud Function
///   - User data: Read via getUserData Cloud Function
///   - Notifications: Read via getNotifications Cloud Function
/// - Write operations: All go through Cloud Functions
///
/// NOTE: Real-time updates are achieved through periodic polling (every 10 seconds)
/// since Cloud Functions cannot return real-time streams.
class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen> {
  final DonorDashboardController _controller = DonorDashboardController();
  Timer? _refreshTimer;
  Timer? _notificationsTimer;
  List<BloodRequest> _requests = [];
  Map<String, dynamic>? _userProfile;
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadUserProfile();
    _loadUnreadNotificationsCount();

    // Set up periodic refresh (every 30 seconds) for real-time updates
    // Increased interval to improve performance
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadRequests();
      }
    });

    // Set up periodic refresh for notifications count (every 30 seconds)
    _notificationsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadUnreadNotificationsCount();
      }
    });

    // Initialize Firebase Cloud Messaging for push notifications
    // Done after first frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FCMService.instance.initFCM();
      } catch (e) {
        // Failed to initialize FCM - non-critical, continue
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationsTimer?.cancel();
    super.dispose();
  }

  /// Loads requests via Cloud Functions
  Future<void> _loadRequests() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final requests = await _controller.fetchRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
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

  /// Loads user profile via Cloud Functions
  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    try {
      final userProfile = await _controller.fetchUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = userProfile;
        });
      }
    } catch (e) {
      // Silently fail - user profile is not critical for dashboard
    }
  }

  /// Loads unread notifications count via Cloud Functions
  Future<void> _loadUnreadNotificationsCount() async {
    if (!mounted) return;

    try {
      final count = await _controller.getUnreadNotificationsCount();
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      // Silently fail - notification count is not critical
    }
  }

  // ------------------ Logout Handler ------------------
  /// Handles user logout
  Future<void> _handleLogout() async {
    await _controller.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ------------------ Navigation Handlers ------------------
  /// Navigates to profile screen
  void _navigateToProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DonorProfileScreen()));
  }

  /// Navigates to notifications screen
  void _navigateToNotifications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  /// Navigates to chat screen for a specific request
  void _navigateToChat(BloodRequest request) {
    final currentUserId = _controller.getCurrentUserId();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          requestId: request.id,
          initialMessage: 'Please donate as soon as possible',
          recipientId: currentUserId,
        ),
      ),
    );
  }

  // ------------------ UI Build ------------------
  @override
  Widget build(BuildContext context) {
    final user = _controller.getCurrentUser();

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBarWithLogo(
        title: '',
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'images/logoBLOOD.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        actions: [
          // Profile button
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person, color: AppTheme.deepRed),
            onPressed: _navigateToProfile,
          ),
          // Notification button with unread badge
          _buildNotificationButton(user),
          // Logout button
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: AppTheme.deepRed),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        // FutureBuilder with periodic refresh for real-time updates
        // All reads go through Cloud Functions (server-side)
        child: _isLoading && _requests.isEmpty
            ? const LoadingIndicator()
            : _error != null
            ? ErrorBox(title: 'Error loading requests', message: _error!)
            : RefreshIndicator(
                onRefresh: _loadRequests,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.padding,
                    AppTheme.padding,
                    AppTheme.padding,
                    18,
                  ),
                  children: [
                    // Header with donor name and statistics
                    _buildHeader(user),
                    const SizedBox(height: 14),
                    SectionHeader(
                      title: 'Blood Requests',
                      subtitle: _requests.isEmpty
                          ? 'No requests yet'
                          : 'Latest posts from blood banks',
                    ),
                    const SizedBox(height: 10),
                    // Requests list or empty state
                    if (_requests.isEmpty)
                      const EmptyState(
                        icon: Icons.bloodtype_outlined,
                        title: 'No blood requests yet',
                        subtitle:
                            'When a blood bank posts a request, it will appear here.',
                      )
                    else
                      ..._requests.map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DonorRequestCard(
                            request: request,
                            onMessage: () => _navigateToChat(request),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // ------------------ Widget Builders ------------------
  /// Builds notification button with unread badge
  /// Uses Cloud Functions to get unread count (polling every 30 seconds)
  Widget _buildNotificationButton(User? user) {
    final hasUnread = _unreadNotificationsCount > 0;

    return IconButton(
      tooltip: 'Notifications',
      onPressed: _navigateToNotifications,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          // Red dot indicator for unread notifications
          if (hasUnread)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds header with donor name and statistics
  /// Uses Cloud Functions to get user profile data (polling every 30 seconds)
  Widget _buildHeader(User? user) {
    // Calculate statistics from current requests
    final stats = _controller.calculateStatistics(_requests);

    // Extract donor name from user profile data
    final donorName = _controller.extractDonorName(
      _userProfile,
      user?.displayName,
    );

    return DonorHeader(
      donorName: donorName,
      totalRequests: stats['totalCount']!,
      urgentCount: stats['urgentCount']!,
    );
  }
}
