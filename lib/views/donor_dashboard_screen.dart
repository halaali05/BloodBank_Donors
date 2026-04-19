import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import '../models/blood_request_model.dart';
import '../controllers/donor_dashboard_controller.dart';
import 'notifications_screen.dart';
import '../services/fcm_service.dart';
import 'donor_profile/donor_profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_bar_with_logo.dart';
import '../widgets/common/error_box.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/dashboard/donor_header.dart';
import '../widgets/dashboard/donor_request_card.dart';
import '../widgets/common/donor_cooldown_blocked_message.dart';
import '../utils/donor_eligibility.dart';
import 'donor_map_screen.dart';

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

class _DonorDashboardScreenState extends State<DonorDashboardScreen>
    with SingleTickerProviderStateMixin {
  final DonorDashboardController _controller = DonorDashboardController();
  late final TabController _tabController;
  Timer? _refreshTimer;
  Timer? _notificationsTimer;
  List<BloodRequest> _requests = [];
  Map<String, dynamic>? _userProfile;
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;
  String? _error;
  String? _respondingRequestId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
    _loadUserProfile();
    _loadUnreadNotificationsCount();

    // Set up periodic refresh (every 30 seconds) for real-time updates
    // Increased interval to improve performance
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadRequests();
        _loadUserProfile();
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
        await FCMService.instance.ensureTokenSynced(
          attempts: 5,
          delay: const Duration(seconds: 2),
        );
      } catch (e) {
        // Failed to initialize FCM - non-critical, continue
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
  /// Refreshes user profile when returning if profile was updated
  Future<void> _navigateToProfile() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const DonorProfileScreen()));

    // If profile was updated, refresh user profile immediately
    if (result == true && mounted) {
      _loadUserProfile();
    }
  }

  /// Navigates to notifications screen
  void _navigateToNotifications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  /// Navigates to chat screen for a specific request
  void _navigateToChat(BloodRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(requestId: request.id, initialMessage: ''),
      ),
    );
  }

  bool get _donationCooldownActive =>
      DonorEligibility.isCooldownActive(_userProfile);

  DateTime? _donationCooldownEndsAt() =>
      DonorEligibility.cooldownEndsAt(_userProfile);

  Future<void> _submitDonorResponse(BloodRequest request, String status) async {
    if (_respondingRequestId != null) return;
    if (request.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This request is completed. Responses are disabled.'),
        ),
      );
      return;
    }
    if (status == 'accepted' &&
        _donationCooldownActive &&
        request.myResponse != 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey.shade900,
          content: DonorCooldownBlockedMessage(
            baseStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
            linkStyle: TextStyle(
              color: Colors.amber.shade100,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _respondingRequestId = request.id);
    try {
      await _controller.submitDonorResponse(
        requestId: request.id,
        response: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'accepted'
                ? 'Marked as "I can donate". The blood bank can now see you.'
                : 'Removed from "I can donate" list.',
          ),
        ),
      );
      await _loadRequests();
      await _loadUserProfile();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final showLinked =
          msg.toLowerCase().contains('not eligible') ||
          msg.toLowerCase().contains('when can i donate');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey.shade900,
          content: showLinked
              ? DonorCooldownBlockedMessage(
                  baseStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                  linkStyle: TextStyle(
                    color: Colors.amber.shade100,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                )
              : Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingRequestId = null);
      }
    }
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.deepRed,
          labelColor: AppTheme.deepRed,
          unselectedLabelColor: Colors.black45,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.list_alt_outlined, size: 18),
              text: 'Requests',
            ),
            Tab(icon: Icon(Icons.map_outlined, size: 18), text: 'Map'),
          ],
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: List view ──────────────────────────────────────────────
          SafeArea(
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
                        _buildHeader(user),
                        const SizedBox(height: 14),
                        SectionHeader(
                          title: 'Blood Requests',
                          subtitle: _requests.isEmpty
                              ? 'No requests yet'
                              : 'Latest posts from blood banks',
                        ),
                        const SizedBox(height: 10),
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
                                isSubmittingResponse:
                                    _respondingRequestId == request.id,
                                acceptBlockedByCooldown: _donationCooldownActive,
                                onDonate: () =>
                                    _submitDonorResponse(request, 'accepted'),
                                onUndoDonate: () =>
                                    _submitDonorResponse(request, 'none'),
                                onMessage: () => _navigateToChat(request),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          // ── Tab 2: Map view ───────────────────────────────────────────────
          DonorMapScreen(
            requests: _requests,
            donorGovernorate: _userProfile?['location'] as String?,
            respondingRequestId: _respondingRequestId,
            nextDonationEligibleAt: _donationCooldownEndsAt(),
            onRespond: _submitDonorResponse,
          ),
        ],
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
    final activeRequests =
        _requests.where((r) => !r.isCompleted).toList();

    final activeUnits = activeRequests.fold(
      0,
      (sum, r) => sum + r.units,
    );

    final donorName = _controller.extractDonorName(
      _userProfile,
      user?.displayName,
    );

    return DonorHeader(
      donorName: donorName,
      activeRequests: activeRequests.length,
      activeUnits: activeUnits,
    );
  }
}

