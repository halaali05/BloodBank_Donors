import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat_screen.dart';
import '../auth/login_screen.dart';
import '../../models/blood_request_model.dart';
import '../../controllers/donor_dashboard_controller.dart';
import '../notifications_screen.dart';
import '../../services/fcm_service.dart';
import '../donor_profile/donor_profile_screen.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/common/app_bar_with_logo.dart';
import '../../shared/widgets/common/error_box.dart';
import '../../shared/widgets/common/loading_indicator.dart';
import '../../shared/widgets/common/section_header.dart';
import '../../shared/widgets/common/empty_state.dart';
import '../../shared/widgets/dashboard/donor_header.dart';
import '../../shared/widgets/dashboard/donor_request_card.dart';
import '../../shared/widgets/common/donor_cooldown_blocked_message.dart';
import '../../shared/utils/donor_eligibility.dart';
import '../../shared/utils/error_message_helper.dart';
import '../../shared/utils/snack_bar_helper.dart';
import '../donor_map_screen.dart';

enum DonorRequestFilter { all, nearest, completed, urgent, normal }

/// Donor home: browse requests, filters, “I can donate”, chat and map entry points.
///
/// Data comes from Cloud Functions. The screen refreshes on a timer (no live DB stream in the client).
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
  List<BloodRequest> _requests = [];
  Map<String, dynamic>? _userProfile;
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String? _respondingRequestId;
  DonorRequestFilter _selectedFilter = DonorRequestFilter.all;

  static const TextStyle _cooldownSnackBaseStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.35,
  );

  TextStyle get _cooldownSnackLinkStyle => TextStyle(
        color: Colors.amber.shade100,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w800,
        decoration: TextDecoration.underline,
      );

  Widget _donorCooldownLinkedSnackContent() {
    return DonorCooldownBlockedMessage(
      baseStyle: _cooldownSnackBaseStyle,
      linkStyle: _cooldownSnackLinkStyle,
    );
  }

  void _showCooldownSnack(Widget content) {
    SnackBarHelper.showContent(
      context: context,
      content: content,
      backgroundColor: Colors.grey.shade900,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDashboardData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadDashboardData(showLoading: false);
      }
    });

    // Push: init after first paint so the tab UI stays smooth.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FCMService.instance.initFCM();
        await FCMService.instance.ensureTokenSynced(
          attempts: 5,
          delay: const Duration(seconds: 2),
        );
      } catch (e) {
        debugPrint('FCM init (donor dashboard): $e');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool showLoading = true}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      await Future.wait([
        _loadRequests(showLoading: showLoading),
        _loadUserProfile(),
        _loadUnreadNotificationsCount(),
      ]);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Loads requests via Cloud Functions
  Future<void> _loadRequests({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final requests = await _controller.fetchRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorMessageHelper.humanize(e);
          if (showLoading) _isLoading = false;
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
      unawaited(_loadUserProfile());
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
      DonorEligibility.isBlockedFromDonating(_userProfile);

  DateTime? _donationCooldownEndsAt() =>
      DonorEligibility.cooldownEndsAt(_userProfile);

  /// Returns the list of blood types this donor is compatible to donate to.
  /// If blood type is unknown (not confirmed yet), returns null → show all.
  List<String>? _compatibleBloodTypes(String? donorBloodType) {
    switch (donorBloodType?.trim()) {
      case 'O-':
        return ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'];
      case 'O+':
        return ['O+', 'A+', 'B+', 'AB+'];
      case 'A-':
        return ['A-', 'A+', 'AB-', 'AB+'];
      case 'A+':
        return ['A+', 'AB+'];
      case 'B-':
        return ['B-', 'B+', 'AB-', 'AB+'];
      case 'B+':
        return ['B+', 'AB+'];
      case 'AB-':
        return ['AB-', 'AB+'];
      case 'AB+':
        return ['AB+'];
      default:
        // Blood type not confirmed yet → show all requests
        return null;
    }
  }

  /// Filters requests by donor's confirmed blood type compatibility.
  /// If blood type is unknown, returns all requests unfiltered.
  List<BloodRequest> _applyBloodTypeFilter(List<BloodRequest> requests) {
    final donorBloodType = (_userProfile?['bloodType'] ?? '').toString().trim();
    final compatible = _compatibleBloodTypes(
      donorBloodType.isEmpty ? null : donorBloodType,
    );
    if (compatible == null) return requests;
    return requests
        .where(
          (r) =>
              _isDonorCompletedRequest(r) ||
              compatible.contains(r.bloodType.trim()),
        )
        .toList();
  }

  bool _isDonorCompletedRequest(BloodRequest request) {
    final process = request.donorProcessStatus?.trim().toLowerCase();
    return request.isCompleted ||
        process == 'donated' ||
        process == 'restricted';
  }

  bool _isActiveForRequestFilters(BloodRequest request) {
    return !_isDonorCompletedRequest(request);
  }

  List<BloodRequest> get _displayRequests {
    switch (_selectedFilter) {
      case DonorRequestFilter.all:
        return _applyBloodTypeFilter(_requests);
      case DonorRequestFilter.completed:
        return _applyBloodTypeFilter(
          _requests.where(_isDonorCompletedRequest).toList(),
        );
      case DonorRequestFilter.urgent:
        return _applyBloodTypeFilter(
          _requests
              .where((r) => _isActiveForRequestFilters(r) && r.isUrgent)
              .toList(),
        );
      case DonorRequestFilter.normal:
        return _applyBloodTypeFilter(
          _requests
              .where((r) => _isActiveForRequestFilters(r) && !r.isUrgent)
              .toList(),
        );
      case DonorRequestFilter.nearest:
        return _applyBloodTypeFilter(_nearestRequestsOnly(_requests));
    }
  }

  String _normalizeLocationLabel(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u2018\u2019]'), "'")
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _governorateFromLocationLabel(String value) {
    final normalized = _normalizeLocationLabel(value);
    if (normalized.isEmpty) return null;

    for (final governorate in AppTheme.jordanianGovernorates) {
      if (normalized == _normalizeLocationLabel(governorate)) {
        return governorate;
      }
    }

    for (final governorate in AppTheme.jordanianGovernorates) {
      final governorateLabel = _normalizeLocationLabel(governorate);
      final pattern = RegExp(
        '(^|[^a-z0-9])${RegExp.escape(governorateLabel)}([^a-z0-9]|\$)',
      );
      if (pattern.hasMatch(normalized)) return governorate;
    }

    return null;
  }

  List<BloodRequest> _nearestRequestsOnly(List<BloodRequest> requests) {
    final donorGovernorate = _governorateFromLocationLabel(
      (_userProfile?['location'] ?? '').toString(),
    );
    if (donorGovernorate == null) return const [];

    return requests.where((request) {
      if (!_isActiveForRequestFilters(request)) return false;
      final requestGovernorate = _governorateFromLocationLabel(
        request.hospitalLocation,
      );
      return requestGovernorate == donorGovernorate;
    }).toList();
  }

  void _setRequestFilter(DonorRequestFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
  }

  String _emptyFilterTitle() {
    if (_selectedFilter == DonorRequestFilter.nearest) {
      return 'NO Nearest Requests Found';
    }
    return 'No Requests Found';
  }

  String _filterLabel(DonorRequestFilter filter) {
    switch (filter) {
      case DonorRequestFilter.all:
        return 'All';
      case DonorRequestFilter.nearest:
        return 'Nearest';
      case DonorRequestFilter.completed:
        return 'Completed';
      case DonorRequestFilter.urgent:
        return 'Urgent Requests';
      case DonorRequestFilter.normal:
        return 'Normal';
    }
  }

  Future<void> _submitDonorResponse(BloodRequest request, String status) async {
    if (_respondingRequestId != null) return;
    if (request.isCompleted) {
      SnackBarHelper.notice(
        context,
        'This request is completed. Responses are disabled.',
      );
      return;
    }
    if (status == 'accepted' &&
        _donationCooldownActive &&
        request.myResponse != 'accepted') {
      final isPermanent = DonorEligibility.isPermanentlyBlocked(_userProfile);
      _showCooldownSnack(
        isPermanent
            ? const Text(
                '🚫 You are permanently blocked from donating due to medical reasons.',
                style: TextStyle(color: Colors.white, fontSize: 14),
              )
            : _donorCooldownLinkedSnackContent(),
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
      SnackBarHelper.success(
        context,
        status == 'accepted'
            ? 'Marked as "I can donate". The blood bank can now see you.'
            : 'Removed from "I can donate" list.',
      );
      await _loadDashboardData(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      final msg = ErrorMessageHelper.humanize(e);
      final showLinked =
          msg.toLowerCase().contains('not eligible') ||
          msg.toLowerCase().contains('when can i donate');
      _showCooldownSnack(
        showLinked
            ? _donorCooldownLinkedSnackContent()
            : Text(msg, style: const TextStyle(color: Colors.white)),
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
    final displayRequests = _displayRequests;

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBarWithLogo(
        title: '',
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/docs/images/logoBLOOD.png',
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
                    onRefresh: () => _loadDashboardData(showLoading: false),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.padding,
                            AppTheme.padding,
                            AppTheme.padding,
                            10,
                          ),
                          sliver: SliverList.list(
                            children: [
                              _buildHeader(user),
                              const SizedBox(height: 14),
                              SectionHeader(
                                title: 'Blood Requests',
                                subtitle: displayRequests.isEmpty
                                    ? 'No requests for ${_filterLabel(_selectedFilter)}'
                                    : '${displayRequests.length} request(s) - ${_filterLabel(_selectedFilter)}',
                              ),
                              const SizedBox(height: 10),
                              _RequestFilterBar(
                                selectedFilter: _selectedFilter,
                                onFilterSelected: _setRequestFilter,
                              ),
                              const SizedBox(height: 10),
                              if (displayRequests.isEmpty)
                                EmptyState(
                                  icon: Icons.bloodtype_outlined,
                                  title: _emptyFilterTitle(),
                                ),
                            ],
                          ),
                        ),
                        if (displayRequests.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.padding,
                              0,
                              AppTheme.padding,
                              18,
                            ),
                            sliver: SliverList.separated(
                              itemCount: displayRequests.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final request = displayRequests[index];
                                return DonorRequestCard(
                                  request: request,
                                  isSubmittingResponse:
                                      _respondingRequestId == request.id,
                                  acceptBlockedByCooldown:
                                      _donationCooldownActive,
                                  permanentlyBlocked:
                                      DonorEligibility.isPermanentlyBlocked(
                                        _userProfile,
                                      ),
                                  onDonate: () =>
                                      _submitDonorResponse(request, 'accepted'),
                                  onUndoDonate: () =>
                                      _submitDonorResponse(request, 'none'),
                                  onMessage: () => _navigateToChat(request),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          // ── Tab 2: Map view ───────────────────────────────────────────────
          DonorMapScreen(
            requests: _applyBloodTypeFilter(_requests),
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
    final activeRequests = _requests.where((r) => !r.isCompleted).toList();

    final activeUnits = activeRequests.fold(0, (sum, r) => sum + r.units);

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

class _RequestFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RequestFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.deepRed : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.deepRed : const Color(0xFFD0D4F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _RequestFilterBar extends StatelessWidget {
  final DonorRequestFilter selectedFilter;
  final ValueChanged<DonorRequestFilter> onFilterSelected;

  const _RequestFilterBar({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _RequestFilterChip(
            label: 'All',
            selected: selectedFilter == DonorRequestFilter.all,
            onTap: () => onFilterSelected(DonorRequestFilter.all),
          ),
          const SizedBox(width: 8),
          _RequestFilterChip(
            label: 'Nearest',
            selected: selectedFilter == DonorRequestFilter.nearest,
            onTap: () => onFilterSelected(DonorRequestFilter.nearest),
          ),
          const SizedBox(width: 8),
          _RequestFilterChip(
            label: 'Completed',
            selected: selectedFilter == DonorRequestFilter.completed,
            onTap: () => onFilterSelected(DonorRequestFilter.completed),
          ),
          const SizedBox(width: 8),
          _RequestFilterChip(
            label: 'Urgent',
            selected: selectedFilter == DonorRequestFilter.urgent,
            onTap: () => onFilterSelected(DonorRequestFilter.urgent),
          ),
          const SizedBox(width: 8),
          _RequestFilterChip(
            label: 'Normal',
            selected: selectedFilter == DonorRequestFilter.normal,
            onTap: () => onFilterSelected(DonorRequestFilter.normal),
          ),
        ],
      ),
    );
  }
}
