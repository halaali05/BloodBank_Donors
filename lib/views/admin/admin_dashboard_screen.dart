import 'package:flutter/material.dart';
import '../../controllers/admin_controller.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/snack_bar_helper.dart';
import '../auth/login_screen.dart';
import 'admin_donors_tab.dart';
import 'admin_requests_tab.dart';
import 'admin_stats_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminController _controller = AdminController();
  final AuthService _authService = AuthService();

  List<BloodRequest> _requests = [];
  List<BloodRequest> _filteredRequests = [];
  List<User> _donors = [];
  List<User> _filteredDonors = [];
  AdminStats? _stats;

  bool _isLoading = true;
  String _requestFilter = 'all';
  String _donorFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _controller.fetchAllRequests();
      final donors = await _controller.fetchDonors();
      final stats = _controller.computeStats(requests, donors);
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _donors = donors;
        _stats = stats;
        _applyRequestFilter(_requestFilter);
        _applyDonorFilter(_donorFilter);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarHelper.failureFrom(context, e);
    }
  }

  void _applyRequestFilter(String filter) {
    _requestFilter = filter;
    switch (filter) {
      case 'active':
        _filteredRequests = _requests.where((r) => !r.isCompleted).toList();
        break;
      case 'urgent':
        _filteredRequests = _requests
            .where((r) => r.isUrgent && !r.isCompleted)
            .toList();
        break;
      case 'completed':
        _filteredRequests = _requests.where((r) => r.isCompleted).toList();
        break;
      default:
        _filteredRequests = List.from(_requests);
    }
  }

  void _applyDonorFilter(String filter) {
    _donorFilter = filter;
    final now = DateTime.now();
    switch (filter) {
      case 'eligible':
        _filteredDonors = _donors
            .where(
              (d) =>
                  !d.isPermanentlyBlocked &&
                  (d.restrictedUntil == null ||
                      d.restrictedUntil!.isBefore(now)) &&
                  (d.nextDonationEligibleAt == null ||
                      d.nextDonationEligibleAt!.isBefore(now)),
            )
            .toList();
        break;
      case 'restricted':
        _filteredDonors = _donors
            .where(
              (d) =>
                  d.isPermanentlyBlocked ||
                  (d.restrictedUntil != null &&
                      d.restrictedUntil!.isAfter(now)) ||
                  (d.nextDonationEligibleAt != null &&
                      d.nextDonationEligibleAt!.isAfter(now)),
            )
            .toList();
        break;
      default:
        _filteredDonors = List.from(_donors);
    }
  }

  Future<void> _onDeleteRequest(BloodRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Request'),
        content: Text(
          'Delete the ${request.bloodType} request from ${request.bloodBankName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _controller.deleteRequest(request.id);
      await _loadData();
      if (!mounted) return;
      SnackBarHelper.success(context, 'Request deleted');
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.failureFrom(context, e);
    }
  }

  Future<void> _onMarkCompleted(BloodRequest request) async {
    try {
      await _controller.markCompleted(request.id);
      await _loadData();
      if (!mounted) return;
      SnackBarHelper.success(context, 'Request marked as completed');
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.failureFrom(context, e);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final eligibleCount = _donors
        .where(
          (d) =>
              !d.isPermanentlyBlocked &&
              (d.restrictedUntil == null || d.restrictedUntil!.isBefore(now)) &&
              (d.nextDonationEligibleAt == null ||
                  d.nextDonationEligibleAt!.isBefore(now)),
        )
        .length;
    final restrictedCount = _donors.length - eligibleCount;

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              'Admin Dashboard',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              'System Overview',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.deepRed,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.deepRed,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list_alt_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text('Requests (${_requests.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text('Donors (${_donors.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 16),
                  SizedBox(width: 4),
                  Text('Stats'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRed),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                AdminRequestsTab(
                  requests: _filteredRequests,
                  allCount: _requests.length,
                  activeCount: _requests.where((r) => !r.isCompleted).length,
                  urgentCount: _requests
                      .where((r) => r.isUrgent && !r.isCompleted)
                      .length,
                  completedCount: _requests.where((r) => r.isCompleted).length,
                  currentFilter: _requestFilter,
                  onFilterChanged: (f) =>
                      setState(() => _applyRequestFilter(f)),
                  onDelete: _onDeleteRequest,
                  onMarkCompleted: _onMarkCompleted,
                ),
                AdminDonorsTab(
                  donors: _filteredDonors,
                  allCount: _donors.length,
                  eligibleCount: eligibleCount,
                  restrictedCount: restrictedCount,
                  currentFilter: _donorFilter,
                  onFilterChanged: (f) => setState(() => _applyDonorFilter(f)),
                ),
                AdminStatsTab(
                  stats: _stats,
                  requests: _requests,
                  donors: _donors,
                ),
              ],
            ),
    );
  }
}
