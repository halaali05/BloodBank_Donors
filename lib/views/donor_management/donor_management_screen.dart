import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/blood_request_model.dart';
import '../../models/donor_medical_report.dart';
import '../../models/donor_response_entry.dart';
import '../../services/cloud_functions_service.dart';
import '../../theme/app_theme.dart';
import 'donor_management_appointment.dart';
import 'donor_management_donor_list.dart';
import 'donor_management_models.dart';
import 'donor_management_report_sheet.dart'
    show DonorManagementReportSheet, RejectionSubType;
import 'donor_management_request_summary.dart';
import 'donor_management_tab_bar.dart';

/// Blood bank screen: accepted → scheduled → tested → donated / restricted.
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

  List<DonorPipelineRow> _donors = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDonors(showSpinner: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDonors(showSpinner: false);
      });
    });
  }

  void _scheduleSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }

  Future<void> _loadDonors({bool showSpinner = true}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    if (showSpinner && mounted) {
      _scheduleSetState(() => _isLoading = true);
    }

    List<DonorPipelineRow> fromEntries(List<DonorResponseEntry> entries) {
      final existingReportsByDonor = {
        for (final donor in _donors) donor.donorId: donor.latestMedicalReport,
      };
      return entries
          .map(
            (d) => DonorPipelineRow(
              donorId: d.donorId,
              fullName: d.fullName,
              email: d.email,
              phoneNumber: d.phoneNumber,
              status: parseDonorProcessStatus(d.processStatus),
              appointmentStatus: d.appointmentStatus,
              appointmentAt: d.appointmentAtMillis != null
                  ? DateTime.fromMillisecondsSinceEpoch(d.appointmentAtMillis!)
                  : null,
              bloodType: d.bloodType,
              rescheduleReason: d.rescheduleReason,
              reschedulePreferredAt: d.reschedulePreferredAtMillis != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      d.reschedulePreferredAtMillis!,
                    )
                  : null,
              rescheduleRequestedAt: d.rescheduleRequestedAtMillis != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      d.rescheduleRequestedAtMillis!,
                    )
                  : null,
              latestMedicalReport:
                  d.latestMedicalReport ?? existingReportsByDonor[d.donorId],
            ),
          )
          .toList();
    }

    try {
      final res = await _cloudFunctions.getRequestDonorResponses(
        requestId: widget.request.id,
        includeLatestReports: showSpinner,
      );
      final raw = res['accepted'];
      if (raw is List) {
        final entries = raw.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return DonorResponseEntry.fromMap(m);
        }).toList();
        if (!mounted) return;
        _scheduleSetState(() {
          _donors = fromEntries(entries);
          _isLoading = false;
        });
        _isRefreshing = false;
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    _scheduleSetState(() {
      _donors = fromEntries(widget.request.acceptedDonors);
      _isLoading = false;
    });
    _isRefreshing = false;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<DonorPipelineRow> _byStatus(List<DonorProcessStatus> statuses) =>
      _donors.where((d) => statuses.contains(d.status)).toList();

  List<DonorPipelineRow> _availableAccepted() => _donors
      .where(
        (d) =>
            d.status == DonorProcessStatus.accepted &&
            (d.appointmentStatus ?? '') != 'missed' &&
            (d.appointmentStatus ?? '') != 'completed',
      )
      .toList();

  List<DonorPipelineRow> _scheduledOnly() =>
      _donors.where((d) => d.status == DonorProcessStatus.scheduled).toList();

  List<DonorPipelineRow> _completedOnly() =>
      _donors.where((d) => (d.appointmentStatus ?? '') == 'completed').toList();

  List<DonorPipelineRow> _missedOnly() =>
      _donors.where((d) => (d.appointmentStatus ?? '') == 'missed').toList();

  @override
  Widget build(BuildContext context) {
    final acceptedCount = _donors
        .where((d) => d.status != DonorProcessStatus.restricted)
        .length;
    final restrictedCount = _byStatus([DonorProcessStatus.restricted]).length;

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
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
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRed),
            )
          : Column(
              children: [
                DonorManagementRequestSummary(
                  request: widget.request,
                  acceptedCount: acceptedCount,
                  restrictedCount: restrictedCount,
                ),
                DonorManagementTabBar(
                  controller: _tabController,
                  availableCount: _availableAccepted().length,
                  scheduledCount: _scheduledOnly().length,
                  completedCount: _completedOnly().length,
                  missedCount: _missedOnly().length,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      DonorManagementDonorList(
                        donors: _availableAccepted(),
                        emptyLabel: 'No available donors',
                        onAction: _onSchedule,
                        actionLabel: 'Schedule',
                        actionIcon: Icons.calendar_today_rounded,
                        actionColor: const Color(0xFF1565C0),
                      ),
                      DonorManagementDonorList(
                        donors: _scheduledOnly(),
                        emptyLabel: 'No scheduled donors',
                        onAction: _onUploadReport,
                        actionLabel: 'Upload Report',
                        actionIcon: Icons.upload_file_rounded,
                        actionColor: const Color(0xFF6A1B9A),
                      ),
                      DonorManagementDonorList(
                        donors: _completedOnly(),
                        emptyLabel: 'No completed donors yet',
                      ),
                      DonorManagementDonorList(
                        donors: _missedOnly(),
                        emptyLabel: 'No missed donors',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _onSchedule(DonorPipelineRow donor) async {
    final picked = await pickDonorAppointmentDateTime(context);
    if (picked == null) return;

    final idx = _donors.indexWhere((d) => d.donorId == donor.donorId);
    if (idx == -1) return;

    _scheduleSetState(() {
      _donors[idx] = donor.copyWith(
        status: DonorProcessStatus.scheduled,
        appointmentStatus: 'scheduled',
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
      _scheduleSetState(() {
        final i = _donors.indexWhere((d) => d.donorId == donor.donorId);
        if (i != -1) _donors[i] = donor;
      });
      _showSnack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    }
  }

  void _onUploadReport(DonorPipelineRow donor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DonorManagementReportSheet(
        donor: donor,
        onSubmit:
            (
              status,
              reason,
              notes,
              reportFileUrl,
              confirmedBloodType,
              rejectionSubType,
            ) async {
              Navigator.pop(context);

              _scheduleSetState(() {
                final idx = _donors.indexWhere(
                  (d) => d.donorId == donor.donorId,
                );
                if (idx != -1) {
                  _donors[idx] = donor.copyWith(
                    status: status,
                    appointmentStatus: 'completed',
                  );
                }
              });

              final isPermanentBlock =
                  rejectionSubType == RejectionSubType.permanentBlock;

              // reportFileUrl is empty string ('') when Other Reasons
              // and the hospital chose not to attach a file.
              // We only pass it to the Cloud Function when a real URL exists,
              // so the backend knows whether to send a "report uploaded"
              // notification and whether to show the report in history/reports.
              final hasReport = reportFileUrl.isNotEmpty;

              try {
                await _cloudFunctions.saveMedicalReport(
                  requestId: widget.request.id,
                  donorId: donor.donorId,
                  status: donorProcessStatusToString(status),
                  restrictionReason: reason,
                  notes: notes,
                  reportFileUrl: hasReport ? reportFileUrl : '',
                  confirmedBloodType: confirmedBloodType,
                  isPermanentBlock: isPermanentBlock,
                );
                if (!mounted) return;
                await _loadDonors(showSpinner: false);
                if (!mounted) return;
                if (_tabController.length > 2) {
                  _tabController.animateTo(2);
                }
                // Only show "report uploaded" snack when file was actually attached
                final msg = status == DonorProcessStatus.donated
                    ? '🩸 ${donor.fullName} donation recorded!'
                    : hasReport
                    ? '⚠️ ${donor.fullName} marked as restricted — report sent'
                    : '⚠️ ${donor.fullName} marked as restricted';
                _showSnack(
                  msg,
                  status == DonorProcessStatus.donated
                      ? Colors.green[700]!
                      : Colors.orange[700]!,
                );
              } catch (e) {
                _scheduleSetState(() {
                  final idx = _donors.indexWhere(
                    (d) => d.donorId == donor.donorId,
                  );
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
