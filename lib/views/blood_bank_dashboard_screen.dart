import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'new_request_screen.dart';
import 'login_screen.dart';
import 'donor_management/donor_management_screen.dart';

import 'stats_screen.dart';
import 'blood_bank_past_donors_screen.dart';

import '../models/blood_request_model.dart';
import '../controllers/blood_bank_dashboard_controller.dart';
import '../theme/app_theme.dart';

import '../widgets/common/app_bar_with_logo.dart';
import '../widgets/common/error_box.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/section_header.dart';

import '../widgets/dashboard/header_card.dart';
import '../widgets/dashboard/request_card.dart';

import '../services/fcm_service.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FCMService.instance.initFCM();
        await FCMService.instance.ensureTokenSynced(
          attempts: 5,
          delay: const Duration(seconds: 2),
        );
      } catch (_) {}
    });

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
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _controller.deleteRequest(requestId: request.id);
      if (!context.mounted) return;
      Navigator.pop(context);
      await _loadRequests();
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _handleCompleteRequest(
    BuildContext context,
    BloodRequest request,
  ) async {
    if (request.isCompleted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark Request Completed'),
        content: const Text(
          'This will mark the post as completed and disable new responses. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _controller.markRequestCompleted(requestId: request.id);
      if (!context.mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request marked as completed.')),
      );

      await _loadRequests();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);

      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'Failed.' : message)),
      );
    }
  }

  Future<void> _handleEditUnits(
    BuildContext context,
    BloodRequest request,
  ) async {
    final controller = TextEditingController(text: request.units.toString());
    final updatedUnits = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit units'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Units'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed < 1) return;
              Navigator.pop(context, parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updatedUnits == null || updatedUnits == request.units) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _controller.updateRequestUnits(
        requestId: request.id,
        units: updatedUnits,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request units updated.')));
      await _loadRequests();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'Failed.' : message)),
      );
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
    final stats = _controller.calculateStatistics(_requests);
    final urgentCount = stats['urgentCount'] ?? 0;

    final activeRequests = _requests.where((r) => !r.isCompleted).toList();

    final completedRequests = _requests.where((r) => r.isCompleted).toList();

    final activeUnits = activeRequests.fold(0, (sum, r) => sum + r.units);

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBarWithLogo(
        title: 'Blood Bank',
        actions: [
          IconButton(
            tooltip: 'Donors',
            icon: const Icon(Icons.groups_2_outlined, color: AppTheme.deepRed),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BloodBankPastDonorsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.deepRed),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatsScreen(requests: _requests),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.deepRed),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _requests.isEmpty
            ? const LoadingIndicator(color: AppTheme.deepRed)
            : _error != null
            ? ErrorBox(
                title: 'Error',
                message: _error!,
                onRetry: _loadRequests,
              )
            : RefreshIndicator(
                onRefresh: _loadRequests,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// HEADER
                      HeaderCard(
                        title: widget.bloodBankName,
                        subtitle: widget.location,
                        activeUnits: activeUnits,
                        urgentRequests: urgentCount,
                        activeRequests: activeRequests.length,
                      ),

                      const SizedBox(height: 24),

                      /// ACTIVE REQUESTS
                      SectionHeader(
                        title: 'Active Requests',
                        subtitle: activeRequests.isEmpty
                            ? 'No active requests'
                            : 'Manage current posts',
                        rightWidget: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewRequestScreen(
                                  bloodBankName: widget.bloodBankName,
                                  initialHospitalLocation: widget.location,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('New'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (activeRequests.isEmpty)
                        const EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No active requests',
                          subtitle: 'Create one now.',
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activeRequests.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final request = activeRequests[index];
                            return RequestCard(
                              request: request,
                              onDelete: () =>
                                  _handleDeleteRequest(context, request),
                              onEdit: () => _handleEditUnits(context, request),
                              onMarkCompleted: () =>
                                  _handleCompleteRequest(context, request),
                              onTapAcceptances: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DonorManagementScreen(request: request),
                                  ),
                                ).then((_) => _loadRequests());
                              },
                            );
                          },
                        ),

                      const SizedBox(height: 24),

                      /// COMPLETED
                      SectionHeader(
                        title: 'Completed Requests',
                        subtitle: 'Closed posts',
                      ),

                      const SizedBox(height: 12),

                      if (completedRequests.isEmpty)
                        const EmptyState(
                          icon: Icons.check_circle_outline,
                          title: 'No completed requests',
                          subtitle: '',
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: completedRequests.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final request = completedRequests[index];
                            return RequestCard(
                              request: request,
                              onDelete: () =>
                                  _handleDeleteRequest(context, request),
                              onEdit: () => _handleEditUnits(context, request),
                              onTapAcceptances: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DonorManagementScreen(request: request),
                                  ),
                                ).then((_) => _loadRequests());
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
