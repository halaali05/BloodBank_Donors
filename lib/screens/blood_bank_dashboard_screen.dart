import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contacts_screen.dart';
import 'new_request_screen.dart';
import 'login_screen.dart';
import '../models/blood_request_model.dart';
import '../controllers/blood_bank_dashboard_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_bar_with_logo.dart';
import '../widgets/common/error_box.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/section_header.dart';
import '../widgets/dashboard/header_card.dart';
import '../widgets/dashboard/stat_card.dart';
import '../widgets/dashboard/request_card.dart';

class BloodBankDashboardScreen extends StatefulWidget {
  final String bloodBankName;
  final String location;

  const BloodBankDashboardScreen({
    super.key,
    required this.bloodBankName,
    required this.location,
  });

  @override
  State<BloodBankDashboardScreen> createState() =>
      _BloodBankDashboardScreenState();
}

class _BloodBankDashboardScreenState extends State<BloodBankDashboardScreen> {
  final BloodBankDashboardController _controller =
      BloodBankDashboardController();

  Timer? _refreshTimer;
  List<BloodRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadRequests();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

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

  Future<void> _handleDeleteRequest(
    BuildContext context,
    BloodRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _controller.deleteRequest(requestId: request.id);
      if (context.mounted) Navigator.pop(context);
      await _loadRequests();
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBarWithLogo(
        title: 'Blood Bank',
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: AppTheme.deepRed),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _requests.isEmpty
            ? const LoadingIndicator()
            : _error != null
                ? ErrorBox(title: 'Error loading requests', message: _error!)
                : RefreshIndicator(
                    onRefresh: _loadRequests,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.padding,
                        14,
                        AppTheme.padding,
                        18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          /// HEADER (LTR)
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: HeaderCard(
                              title: widget.bloodBankName,
                              subtitle: widget.location,
                            ),
                          ),

                          const SizedBox(height: 14),

                          /// STATS (LTR)
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: _StatsGrid(
                              totalUnits: _controller
                                  .calculateStatistics(_requests)['totalUnits']!,
                              activeCount: _controller
                                  .calculateStatistics(_requests)['activeCount']!,
                              urgentCount: _controller
                                  .calculateStatistics(_requests)['urgentCount']!,
                              normalCount: _controller
                                  .calculateStatistics(_requests)['normalCount']!,
                            ),
                          ),

                          const SizedBox(height: 20),

                          /// SECTION HEADER (LTR)
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: SectionHeader(
                              title: 'Active Requests',
                              subtitle: _requests.isEmpty
                                  ? 'No active requests'
                                  : 'Manage your blood current posts',
                              rightWidget: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewRequestScreen(
                                        bloodBankName: widget.bloodBankName,
                                        initialHospitalLocation:
                                            widget.location,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('New Request'),
                                style: AppTheme.primaryButtonStyle(
                                  borderRadius:
                                      AppTheme.borderRadiusSmall,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          /// POSTS (UNCHANGED)
                          if (_requests.isEmpty)
                            const EmptyState(
                              icon: Icons.inbox_outlined,
                              title: 'No active requests',
                              subtitle:
                                  'Create a new request to reach donors quickly.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: _requests.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final request = _requests[index];
                                return RequestCard(
                                  request: request,
                                  onDelete: () =>
                                      _handleDeleteRequest(context, request),
                                  onViewDonors: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ContactsScreen(
                                          requestId: request.id,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

/// ---------------- STATS GRID ----------------
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.totalUnits,
    required this.activeCount,
    required this.urgentCount,
    required this.normalCount,
  });

  final int totalUnits;
  final int activeCount;
  final int urgentCount;
  final int normalCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(
              title: 'Total Units',
              value: '$totalUnits',
              icon: Icons.bloodtype,
              tint: const Color(0xFF1565C0),
              width: cardWidth,
            ),
            StatCard(
              title: 'Active Requests',
              value: '$activeCount',
              icon: Icons.list_alt,
              tint: AppTheme.deepRed,
              width: cardWidth,
            ),
            StatCard(
              title: 'Urgent',
              value: '$urgentCount',
              icon: Icons.warning_amber_rounded,
              tint: const Color(0xFFF57C00),
              width: cardWidth,
            ),
            StatCard(
              title: 'Normal',
              value: '$normalCount',
              icon: Icons.check_circle,
              tint: const Color(0xFF2E7D32),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }
}
