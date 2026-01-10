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

/// Main dashboard screen for blood banks/hospitals
///
/// Displays all active blood requests, statistics, and allows creating new requests
///
/// SECURITY ARCHITECTURE:
/// - Read operations: All go through Cloud Functions (server-side)
///   - Requests: Read via getRequestsByBloodBankId Cloud Function
/// - Write operations: All go through Cloud Functions (server-side)
///   - Delete requests: Uses deleteRequest Cloud Function
///   - Create requests: Uses addRequest Cloud Function (from NewRequestScreen)
///
/// NOTE: Real-time updates are achieved through periodic polling (every 10 seconds)
/// since Cloud Functions cannot return real-time streams.
class BloodBankDashboardScreen extends StatefulWidget {
  /// Name of the blood bank
  final String bloodBankName;

  /// Location of the blood bank
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

    // Set up periodic refresh (every 30 seconds) for real-time updates
    // Increased interval to improve performance
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadRequests();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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

  // ------------------ Delete Request Handler ------------------
  /// Handles request deletion with confirmation dialog
  ///
  /// Flow:
  /// 1. Show confirmation dialog
  /// 2. Verify user owns the request (client-side check)
  /// 3. Call Cloud Function to delete (server-side validation)
  /// 4. Refresh requests list
  /// 5. Show success/error message
  Future<void> _handleDeleteRequest(
    BuildContext context,
    BloodRequest request,
  ) async {
    // Step 1: Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Step 2: Validate request ID
    if (request.id.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid request. Cannot delete.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Step 3: Verify ownership (client-side check)
    if (!_controller.verifyRequestOwnership(request.bloodBankId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only delete your own requests.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Step 4: Show loading indicator
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Step 5: Delete via Cloud Function (server-side)
    try {
      final result = await _controller.deleteRequest(requestId: request.id);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Step 6: Refresh requests list
      await _loadRequests();

      if (context.mounted) {
        final message =
            result['message'] as String? ?? 'Request deleted successfully.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Debug: Print full error for troubleshooting
      print('[Delete Request Error] Full error: $e');
      print('[Delete Request Error] Error type: ${e.runtimeType}');

      if (context.mounted) {
        String errorMessage;

        // Extract error message based on error type
        if (e is Exception) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        } else {
          errorMessage = e.toString();
        }

        // Clean up the error message
        if (errorMessage.isEmpty) {
          errorMessage = 'Failed to delete request. Please try again.';
        }

        // Handle specific error cases
        if (errorMessage.contains('FAILED_PRECONDITION') ||
            errorMessage.contains('failed-precondition')) {
          if (errorMessage.contains('index') ||
              errorMessage.contains('Index')) {
            errorMessage =
                'Database index required. Please contact support or check Firebase console.';
          } else if (!errorMessage.contains('verify') &&
              !errorMessage.contains('email')) {
            errorMessage =
                'Operation failed. This may require a database index. Please contact support.';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ------------------ Logout Handler ------------------
  /// Handles user logout
  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ------------------ UI Build ------------------
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // RTL for Arabic support
      child: Scaffold(
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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), AppTheme.offWhite],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            // FutureBuilder with periodic refresh for real-time updates
            // All reads go through Cloud Functions (server-side)
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
                          HeaderCard(
                            title: widget.bloodBankName,
                            subtitle: widget.location,
                          ),
                          const SizedBox(height: 14),
                          _StatsGrid(
                            totalUnits: _controller.calculateStatistics(
                              _requests,
                            )['totalUnits']!,
                            activeCount: _controller.calculateStatistics(
                              _requests,
                            )['activeCount']!,
                            urgentCount: _controller.calculateStatistics(
                              _requests,
                            )['urgentCount']!,
                            normalCount: _controller.calculateStatistics(
                              _requests,
                            )['normalCount']!,
                          ),
                          const SizedBox(height: 20),
                          SectionHeader(
                            title: 'Active Requests',
                            subtitle: _requests.isEmpty
                                ? 'No active requests'
                                : 'Manage your blood current posts',
                            rightWidget: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => NewRequestScreen(
                                      bloodBankName: widget.bloodBankName,
                                      initialHospitalLocation: widget.location,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New Request'),
                              style: AppTheme.primaryButtonStyle(
                                borderRadius: AppTheme.borderRadiusSmall,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
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
                              physics: const NeverScrollableScrollPhysics(),
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
        ),
      ),
    );
  }
}

/// Grid widget that displays statistics cards in a 2x2 layout
/// Shows total units, active requests, urgent count, and normal count
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
        // Calculate card width for 2-column grid (accounting for spacing)
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
