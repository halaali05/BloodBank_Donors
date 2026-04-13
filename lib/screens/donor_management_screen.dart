import 'package:flutter/material.dart';
import '../models/donor_medical_report.dart';
import '../models/blood_request_model.dart';
import '../services/cloud_functions_service.dart';
import '../theme/app_theme.dart';

/// Blood bank screen to manage accepted donors through the full process:
/// accepted → scheduled → tested → donated / restricted
class DonorManagementScreen extends StatefulWidget {
  final BloodRequest request;

  const DonorManagementScreen({super.key, required this.request});

  @override
  State<DonorManagementScreen> createState() => _DonorManagementScreenState();
}

class _DonorManagementScreenState extends State<DonorManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();

  List<_DonorCard> _donors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDonors();
  }

  void _loadDonors() {
    // Load accepted donors from the request object.
    // Full process status comes from Cloud Functions in production.
    setState(() {
      _donors = widget.request.acceptedDonors
          .map(
            (d) => _DonorCard(
              donorId: d.donorId,
              fullName: d.fullName,
              email: d.email,
              status: DonorProcessStatus.accepted,
            ),
          )
          .toList();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_DonorCard> _byStatus(List<DonorProcessStatus> statuses) =>
      _donors.where((d) => statuses.contains(d.status)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRed),
            )
          : Column(
              children: [
                _buildRequestSummary(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _DonorList(
                        donors: _byStatus([DonorProcessStatus.accepted]),
                        emptyLabel: 'No pending donors',
                        onAction: _onSchedule,
                        actionLabel: 'Schedule',
                        actionIcon: Icons.calendar_today_rounded,
                        actionColor: const Color(0xFF1565C0),
                      ),
                      _DonorList(
                        donors: _byStatus([
                          DonorProcessStatus.scheduled,
                          DonorProcessStatus.tested,
                        ]),
                        emptyLabel: 'No scheduled donors',
                        onAction: _onUploadReport,
                        actionLabel: 'Upload Report',
                        actionIcon: Icons.upload_file_rounded,
                        actionColor: const Color(0xFF6A1B9A),
                      ),
                      _DonorList(
                        donors: _byStatus([
                          DonorProcessStatus.donated,
                          DonorProcessStatus.restricted,
                        ]),
                        emptyLabel: 'No completed donors yet',
                        showBadge: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _canComplete() ? _buildCompleteButton() : null,
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black87,
    elevation: 0,
    centerTitle: true,
    title: Column(
      children: [
        const Text(
          'Donor Management',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        Text(
          widget.request.bloodBankName,
          style: const TextStyle(fontSize: 11, color: Colors.black45),
        ),
      ],
    ),
  );

  Widget _buildRequestSummary() {
    final req = widget.request;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: req.isUrgent
              ? [const Color(0xFF7A0009), const Color(0xFFB71C1C)]
              : [const Color(0xFF1A237E), const Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadowLarge,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              req.bloodType,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (req.isUrgent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '${req.units} units needed',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  req.hospitalLocation,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statPill('✅ ${req.acceptedCount}', Colors.greenAccent),
              const SizedBox(height: 4),
              _statPill('❌ ${req.rejectedCount}', Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _buildTabBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppTheme.cardShadow,
    ),
    child: TabBar(
      controller: _tabController,
      indicator: BoxDecoration(
        color: AppTheme.deepRed,
        borderRadius: BorderRadius.circular(11),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.black45,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      tabs: [
        _tab('Pending', _byStatus([DonorProcessStatus.accepted]).length),
        _tab(
          'Scheduled',
          _byStatus([
            DonorProcessStatus.scheduled,
            DonorProcessStatus.tested,
          ]).length,
        ),
        _tab(
          'Done',
          _byStatus([
            DonorProcessStatus.donated,
            DonorProcessStatus.restricted,
          ]).length,
        ),
      ],
    ),
  );

  Tab _tab(String label, int count) => Tab(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 10)),
          ),
        ],
      ],
    ),
  );

  bool _canComplete() {
    final pending = _byStatus([
      DonorProcessStatus.accepted,
      DonorProcessStatus.scheduled,
      DonorProcessStatus.tested,
    ]);
    return pending.isEmpty && _donors.isNotEmpty;
  }

  Widget _buildCompleteButton() => FloatingActionButton.extended(
    backgroundColor: AppTheme.deepRed,
    icon: const Icon(Icons.check_circle_rounded),
    label: const Text(
      'Mark Request Completed',
      style: TextStyle(fontWeight: FontWeight.w700),
    ),
    onPressed: _confirmComplete,
  );

  void _confirmComplete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Complete Request',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'All donors have been processed. Mark this request as completed?\n\nThis will finalize all donor reports and notify everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppTheme.primaryButtonStyle(),
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                await _cloudFunctions.markRequestCompleted(
                  requestId: widget.request.id,
                );
                if (context.mounted) Navigator.pop(context);
                _showSnack('Request marked as completed ✅', Colors.green[700]!);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                _showSnack(
                  e.toString().replaceFirst('Exception: ', ''),
                  Colors.red,
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────

  void _onSchedule(_DonorCard donor) async {
    final picked = await showDateTimePicker(context);
    if (picked == null) return;

    // Optimistic UI update
    setState(() {
      final idx = _donors.indexOf(donor);
      _donors[idx] = donor.copyWith(
        status: DonorProcessStatus.scheduled,
        appointmentAt: picked,
      );
    });

    try {
      await _cloudFunctions.scheduleDonorAppointment(
        requestId: widget.request.id,
        donorId: donor.donorId,
        appointmentAt: picked.toIso8601String(),
      );
      _showSnack(
        '📅 Appointment scheduled for ${donor.fullName}',
        Colors.blue[700]!,
      );
    } catch (e) {
      // Revert on failure
      setState(() {
        final idx = _donors.indexWhere((d) => d.donorId == donor.donorId);
        if (idx != -1) _donors[idx] = donor;
      });
      _showSnack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    }
  }

  void _onUploadReport(_DonorCard donor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportUploadSheet(
        donor: donor,
        onSubmit: (status, reason, notes, canDonateAt) async {
          Navigator.pop(context);

          // Optimistic UI update
          setState(() {
            final idx = _donors.indexOf(donor);
            _donors[idx] = donor.copyWith(status: status);
          });

          try {
            await _cloudFunctions.saveMedicalReport(
              requestId: widget.request.id,
              donorId: donor.donorId,
              status: donorProcessStatusToString(status),
              restrictionReason: reason,
              notes: notes,
              canDonateAgainAt: canDonateAt?.toIso8601String(),
            );
            final msg = status == DonorProcessStatus.donated
                ? '🩸 ${donor.fullName} donation recorded!'
                : '⚠️ ${donor.fullName} marked as restricted';
            _showSnack(
              msg,
              status == DonorProcessStatus.donated
                  ? Colors.green[700]!
                  : Colors.orange[700]!,
            );
          } catch (e) {
            // Revert on failure
            setState(() {
              final idx = _donors.indexWhere((d) => d.donorId == donor.donorId);
              if (idx != -1) _donors[idx] = donor;
            });
            _showSnack(
              e.toString().replaceFirst('Exception: ', ''),
              Colors.red,
            );
          }
        },
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helper: Date+Time Picker
// ─────────────────────────────────────────────────────────────
Future<DateTime?> showDateTimePicker(BuildContext context) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now().add(const Duration(days: 1)),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 30)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// ─────────────────────────────────────────────────────────────
// Donor Card Data Model (local UI state)
// ─────────────────────────────────────────────────────────────
class _DonorCard {
  final String donorId;
  final String fullName;
  final String email;
  final DonorProcessStatus status;
  final DateTime? appointmentAt;

  const _DonorCard({
    required this.donorId,
    required this.fullName,
    required this.email,
    required this.status,
    this.appointmentAt,
  });

  _DonorCard copyWith({DonorProcessStatus? status, DateTime? appointmentAt}) =>
      _DonorCard(
        donorId: donorId,
        fullName: fullName,
        email: email,
        status: status ?? this.status,
        appointmentAt: appointmentAt ?? this.appointmentAt,
      );
}

// ─────────────────────────────────────────────────────────────
// Donor List Widget
// ─────────────────────────────────────────────────────────────
class _DonorList extends StatelessWidget {
  final List<_DonorCard> donors;
  final String emptyLabel;
  final void Function(_DonorCard)? onAction;
  final String? actionLabel;
  final IconData? actionIcon;
  final Color? actionColor;
  final bool showBadge;

  const _DonorList({
    required this.donors,
    required this.emptyLabel,
    this.onAction,
    this.actionLabel,
    this.actionIcon,
    this.actionColor,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (donors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 52, color: Colors.black12),
            const SizedBox(height: 10),
            Text(
              emptyLabel,
              style: const TextStyle(color: Colors.black38, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: donors.length,
      itemBuilder: (_, i) => _DonorTile(
        donor: donors[i],
        onAction: onAction,
        actionLabel: actionLabel,
        actionIcon: actionIcon,
        actionColor: actionColor,
        showBadge: showBadge,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Donor Tile
// ─────────────────────────────────────────────────────────────
class _DonorTile extends StatelessWidget {
  final _DonorCard donor;
  final void Function(_DonorCard)? onAction;
  final String? actionLabel;
  final IconData? actionIcon;
  final Color? actionColor;
  final bool showBadge;

  const _DonorTile({
    required this.donor,
    this.onAction,
    this.actionLabel,
    this.actionIcon,
    this.actionColor,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(donor.status);
    final statusLabel = _statusLabel(donor.status);
    final statusIcon = _statusIcon(donor.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  donor.fullName.isNotEmpty
                      ? donor.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    donor.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    donor.email,
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  if (donor.appointmentAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(donor.appointmentAt!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Action button
            if (onAction != null && actionLabel != null)
              GestureDetector(
                onTap: () => onAction!(donor),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor!.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: actionColor!.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(actionIcon, size: 18, color: actionColor),
                      const SizedBox(height: 2),
                      Text(
                        actionLabel!,
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(DonorProcessStatus s) {
    switch (s) {
      case DonorProcessStatus.accepted:
        return Colors.blue;
      case DonorProcessStatus.scheduled:
        return Colors.purple;
      case DonorProcessStatus.tested:
        return Colors.orange;
      case DonorProcessStatus.donated:
        return Colors.green;
      case DonorProcessStatus.restricted:
        return Colors.red;
    }
  }

  String _statusLabel(DonorProcessStatus s) {
    switch (s) {
      case DonorProcessStatus.accepted:
        return 'Pending Schedule';
      case DonorProcessStatus.scheduled:
        return 'Appointment Set';
      case DonorProcessStatus.tested:
        return 'Under Testing';
      case DonorProcessStatus.donated:
        return 'Donated ✓';
      case DonorProcessStatus.restricted:
        return 'Restricted ⚠';
    }
  }

  IconData _statusIcon(DonorProcessStatus s) {
    switch (s) {
      case DonorProcessStatus.accepted:
        return Icons.hourglass_top_rounded;
      case DonorProcessStatus.scheduled:
        return Icons.calendar_month_rounded;
      case DonorProcessStatus.tested:
        return Icons.biotech_rounded;
      case DonorProcessStatus.donated:
        return Icons.favorite_rounded;
      case DonorProcessStatus.restricted:
        return Icons.block_rounded;
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${dt.day} ${months[dt.month - 1]} · $hour:$min $ampm';
  }
}

// ─────────────────────────────────────────────────────────────
// Report Upload Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _ReportUploadSheet extends StatefulWidget {
  final _DonorCard donor;
  final void Function(
    DonorProcessStatus status,
    String? reason,
    String? notes,
    DateTime? canDonateAt,
  )
  onSubmit;

  const _ReportUploadSheet({required this.donor, required this.onSubmit});

  @override
  State<_ReportUploadSheet> createState() => _ReportUploadSheetState();
}

class _ReportUploadSheetState extends State<_ReportUploadSheet> {
  DonorProcessStatus _outcome = DonorProcessStatus.donated;
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _canDonateAt;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRestricted = _outcome == DonorProcessStatus.restricted;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Upload Report — ${widget.donor.fullName}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              widget.donor.email,
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Outcome toggle
            const Text(
              'Donation Outcome',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _OutcomeChip(
                  label: '✅  Donated',
                  selected: _outcome == DonorProcessStatus.donated,
                  color: Colors.green,
                  onTap: () =>
                      setState(() => _outcome = DonorProcessStatus.donated),
                ),
                const SizedBox(width: 10),
                _OutcomeChip(
                  label: '⚠️  Restricted',
                  selected: _outcome == DonorProcessStatus.restricted,
                  color: Colors.orange,
                  onTap: () =>
                      setState(() => _outcome = DonorProcessStatus.restricted),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Upload button (placeholder)
            GestureDetector(
              onTap: () {
                // TODO: implement file picker
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.softBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black12,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.upload_file_rounded, color: AppTheme.deepRed),
                    SizedBox(width: 10),
                    Text(
                      'Attach Medical Report (PDF / Image)',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (isRestricted) ...[
              TextField(
                controller: _reasonCtrl,
                decoration: AppTheme.outlinedInputDecoration(
                  label: 'Restriction Reason',
                  icon: Icons.warning_amber_rounded,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _canDonateAt = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD0D4F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available,
                        color: Colors.black45,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _canDonateAt != null
                            ? 'Can donate again: ${_canDonateAt!.day}/${_canDonateAt!.month}/${_canDonateAt!.year}'
                            : 'Set "Can Donate Again" date (optional)',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _notesCtrl,
              decoration: AppTheme.outlinedInputDecoration(
                label: 'Additional Notes (optional)',
                icon: Icons.notes_rounded,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRestricted
                      ? Colors.orange[700]
                      : Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                  isRestricted
                      ? Icons.block_rounded
                      : Icons.check_circle_rounded,
                ),
                label: Text(
                  isRestricted ? 'Submit & Restrict Donor' : 'Confirm Donation',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => widget.onSubmit(
                  _outcome,
                  isRestricted ? _reasonCtrl.text.trim() : null,
                  _notesCtrl.text.trim().isEmpty
                      ? null
                      : _notesCtrl.text.trim(),
                  isRestricted ? _canDonateAt : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _OutcomeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? color : Colors.black12,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? color : Colors.black45,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    ),
  );
}
