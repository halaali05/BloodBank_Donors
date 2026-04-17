import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/donor_medical_report.dart';
import '../models/blood_request_model.dart';
import '../models/donor_response_entry.dart';
import '../services/cloud_functions_service.dart';
import '../theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/platform_file_reader.dart';

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
    _loadDonors(showSpinner: true);
  }

  /// Loads donors with real `processStatus` / appointment from Cloud Functions.
  /// Falls back to [widget.request.acceptedDonors] if the call fails.
  Future<void> _loadDonors({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _isLoading = true);

    List<_DonorCard> fromEntries(List<DonorResponseEntry> entries) {
      return entries
          .map(
            (d) => _DonorCard(
              donorId: d.donorId,
              fullName: d.fullName,
              email: d.email,
              phoneNumber: d.phoneNumber,
              status: parseDonorProcessStatus(d.processStatus),
              appointmentAt: d.appointmentAtMillis != null
                  ? DateTime.fromMillisecondsSinceEpoch(d.appointmentAtMillis!)
                  : null,
            ),
          )
          .toList();
    }

    try {
      final res = await _cloudFunctions.getRequestDonorResponses(
        requestId: widget.request.id,
      );
      final raw = res['accepted'];
      if (raw is List) {
        final entries = raw.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return DonorResponseEntry.fromMap(m);
        }).toList();
        if (!mounted) return;
        setState(() {
          _donors = fromEntries(entries);
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Use embedded list from dashboard when the callable fails or returns empty.
    }

    if (!mounted) return;
    setState(() {
      _donors = fromEntries(widget.request.acceptedDonors);
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
    final acceptedCount = _donors
        .where((d) => d.status != DonorProcessStatus.restricted)
        .length;
    final restrictedCount = _byStatus([DonorProcessStatus.restricted]).length;
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
          SizedBox(
            width: 170,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                _statPill('✅ $acceptedCount', Colors.greenAccent),
                
                _statPill('⚠️ $restrictedCount', const Color(0xFFFFB74D)),
              ],
            ),
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

  // ─── Actions ────────────────────────────────────────────────

  void _onSchedule(_DonorCard donor) async {
    final picked = await pickAppointmentDateTime(context);
    if (picked == null) return;

    final idx = _donors.indexWhere((d) => d.donorId == donor.donorId);
    if (idx == -1) return;

    // Optimistic UI update
    setState(() {
      _donors[idx] = donor.copyWith(
        status: DonorProcessStatus.scheduled,
        appointmentAt: picked,
      );
    });

    try {
      await _cloudFunctions.scheduleDonorAppointment(
        requestId: widget.request.id,
        donorId: donor.donorId,
        appointmentAtMillis: picked.millisecondsSinceEpoch,
      );
      if (!mounted) return;
      await _loadDonors(showSpinner: false);
      if (!mounted) return;
      _showSnack(
        '📅 Appointment saved for ${donor.fullName}',
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
        onSubmit: (status, reason, notes, canDonateAt, reportFileUrl) async {
          // ← added reportFileUrl param
          Navigator.pop(context);

          // Optimistic UI update
          setState(() {
            final idx = _donors.indexWhere((d) => d.donorId == donor.donorId);
            if (idx != -1) _donors[idx] = donor.copyWith(status: status);
          });

          try {
            await _cloudFunctions.saveMedicalReport(
              requestId: widget.request.id,
              donorId: donor.donorId,
              status: donorProcessStatusToString(status),
              restrictionReason: reason,
              notes: notes,
              reportFileUrl: reportFileUrl, // ← now passed
              canDonateAgainAt: canDonateAt?.toIso8601String(),
            );
            if (!mounted) return;
            await _loadDonors(showSpinner: false);
            if (!mounted) return;
            // Donor is now `donated` / `restricted` — show them under Done.
            if (_tabController.length > 2) {
              _tabController.animateTo(2);
            }
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
// Helper: Date+Time Picker (not Flutter's Material.showDateTimePicker)
// ─────────────────────────────────────────────────────────────
Future<DateTime?> pickAppointmentDateTime(BuildContext context) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = await showDatePicker(
    context: context,
    initialDate: today.add(const Duration(days: 1)),
    firstDate: today,
    lastDate: now.add(const Duration(days: 30)),
  );
  if (date == null || !context.mounted) return null;

  final isToday =
      date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
  // If scheduling today, default the time picker to shortly after now.
  final initialTime = isToday
      ? TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15)))
      : const TimeOfDay(hour: 9, minute: 0);

  final time = await showTimePicker(context: context, initialTime: initialTime);
  if (time == null || !context.mounted) return null;

  final combined = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (!combined.isAfter(now)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Choose a date and time in the future.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return null;
  }
  return combined;
}

// ─────────────────────────────────────────────────────────────
// Donor Card Data Model (local UI state)
// ─────────────────────────────────────────────────────────────
class _DonorCard {
  final String donorId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final DonorProcessStatus status;
  final DateTime? appointmentAt;

  const _DonorCard({
    required this.donorId,
    required this.fullName,
    required this.email,
    this.phoneNumber = '',
    required this.status,
    this.appointmentAt,
  });

  _DonorCard copyWith({DonorProcessStatus? status, DateTime? appointmentAt}) =>
      _DonorCard(
        donorId: donorId,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
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
                  if (donor.phoneNumber.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_android_outlined,
                          size: 12,
                          color: Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SelectableText(
                            donor.phoneNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
    String? reportFileUrl, // ← NEW
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
  bool _showValidationErrors = false;

  // ── PDF upload state ──────────────────────────────────────
  String? _pickedFileName;
  String? _uploadedFileUrl;
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Picks a PDF or image file and uploads it to Firebase Storage
  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: kIsWeb,
        withReadStream: !kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final bytes = await readPlatformFileBytes(picked);

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read this file. Try another PDF/image or pick from Downloads.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _pickedFileName = picked.name;
        _isUploading = true;
        _uploadProgress = 0;
        _uploadedFileUrl = null;
      });

      final ext = (picked.extension ?? '').toLowerCase();

      String contentType = 'application/octet-stream';
      if (ext == 'pdf') {
        contentType = 'application/pdf';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == 'png') {
        contentType = 'image/png';
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';

      final ref = FirebaseStorage.instance
          .ref()
          .child('medical_reports')
          .child(widget.donor.donorId)
          .child(fileName);

      final storagePath = 'medical_reports/${widget.donor.donorId}/$fileName';

      debugPrint('Picked file name: ${picked.name}');
      debugPrint('Picked file bytes: ${bytes.length}');
      debugPrint('Storage path: $storagePath');
      debugPrint('Content type: $contentType');

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;

        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;

        if (total > 0) {
          setState(() {
            _uploadProgress = transferred / total;
          });
        }

        debugPrint('UPLOAD STATE: ${snapshot.state} | $transferred / $total');
      });

      final snap = await uploadTask;
      final downloadUrl = await snap.ref.getDownloadURL();

      if (!mounted) return;

      setState(() {
        _uploadedFileUrl = downloadUrl;
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      debugPrint('UPLOAD SUCCESS URL: $downloadUrl');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, st) {
      debugPrint('UPLOAD ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _pickedFileName = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitReport() {
    final isRestricted = _outcome == DonorProcessStatus.restricted;
    final reason = _reasonCtrl.text.trim();
    final hasReasonError = isRestricted && reason.isEmpty;
    final hasFileError = _uploadedFileUrl == null;

    if (hasReasonError || hasFileError) {
      setState(() => _showValidationErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields marked with *'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onSubmit(
      _outcome,
      isRestricted ? reason : null,
      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isRestricted ? _canDonateAt : null,
      _uploadedFileUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRestricted = _outcome == DonorProcessStatus.restricted;
    final hasReasonError =
        isRestricted && _showValidationErrors && _reasonCtrl.text.trim().isEmpty;
    final hasFileError = _showValidationErrors && _uploadedFileUrl == null;

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
            if (widget.donor.phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.donor.phoneNumber,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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

            // ── PDF / Image Upload ──────────────────────────────
            const Text(
              'Medical Report File *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: _isUploading ? null : _pickAndUploadFile,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _uploadedFileUrl != null
                      ? Colors.green.withOpacity(0.06)
                      : AppTheme.softBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _uploadedFileUrl != null
                        ? Colors.green.withOpacity(0.4)
                        : hasFileError
                        ? Colors.red
                        : Colors.black12,
                    width: hasFileError ? 1.4 : 1,
                  ),
                ),
                child: _isUploading
                    ? Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_upload_rounded,
                                color: AppTheme.deepRed,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Uploading ${_pickedFileName ?? 'file'}...',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                '${(_uploadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: AppTheme.deepRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              minHeight: 4,
                              backgroundColor: Colors.black12,
                              color: AppTheme.deepRed,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            _uploadedFileUrl != null
                                ? Icons.check_circle_rounded
                                : Icons.upload_file_rounded,
                            color: _uploadedFileUrl != null
                                ? Colors.green
                                : AppTheme.deepRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _uploadedFileUrl != null
                                  ? _pickedFileName ?? 'File uploaded ✓'
                                  : 'Attach Medical Report (PDF / Image)',
                              style: TextStyle(
                                color: _uploadedFileUrl != null
                                    ? Colors.green[700]
                                    : Colors.black54,
                                fontSize: 13,
                                fontWeight: _uploadedFileUrl != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_uploadedFileUrl != null)
                            GestureDetector(
                              onTap: () => setState(() {
                                _uploadedFileUrl = null;
                                _pickedFileName = null;
                              }),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.black38,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFileError
                  ? 'Required — attach PDF, JPG, or PNG'
                  : 'Required — PDF, JPG, or PNG',
              style: TextStyle(
                color: hasFileError ? Colors.red : Colors.black45,
                fontSize: 11,
                fontWeight: hasFileError ? FontWeight.w600 : FontWeight.normal,
              ),
            ),

            const SizedBox(height: 14),

            if (isRestricted) ...[
              TextField(
                controller: _reasonCtrl,
                onChanged: (_) {
                  if (_showValidationErrors) setState(() {});
                },
                decoration:
                    AppTheme.outlinedInputDecoration(
                      label: 'Restriction Reason *',
                      icon: Icons.warning_amber_rounded,
                    ).copyWith(
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: hasReasonError ? Colors.red : Colors.black54,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusSmall,
                        ),
                        borderSide: BorderSide(
                          color: hasReasonError
                              ? Colors.red
                              : const Color(0xffd0d4f0),
                          width: hasReasonError ? 1.4 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusSmall,
                        ),
                        borderSide: BorderSide(
                          color: hasReasonError ? Colors.red : AppTheme.deepRed,
                          width: 1.6,
                        ),
                      ),
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
                onPressed: _isUploading
                    ? null // disable while uploading
                    : _submitReport,
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.black26,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.black54,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
