import 'package:flutter/material.dart';

import '../../models/blood_request_model.dart';
import '../../models/donor_medical_report.dart';
import '../../models/donor_response_entry.dart';
import '../../services/cloud_functions_service.dart';
import '../../theme/app_theme.dart';
import 'donor_management_appointment.dart';
import 'donor_management_donor_list.dart';
import 'donor_management_models.dart';
import 'donor_management_report_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDonors(showSpinner: true);
  }

  Future<void> _loadDonors({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _isLoading = true);

    List<DonorPipelineRow> fromEntries(List<DonorResponseEntry> entries) {
      return entries
          .map(
            (d) => DonorPipelineRow(
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
    } catch (_) {}

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

  List<DonorPipelineRow> _byStatus(List<DonorProcessStatus> statuses) =>
      _donors.where((d) => statuses.contains(d.status)).toList();

  @override
  Widget build(BuildContext context) {
    final acceptedCount = _donors
        .where((d) => d.status != DonorProcessStatus.restricted)
        .length;
    final restrictedCount =
        _byStatus([DonorProcessStatus.restricted]).length;

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
                  pendingCount:
                      _byStatus([DonorProcessStatus.accepted]).length,
                  scheduledCount: _byStatus([
                    DonorProcessStatus.scheduled,
                    DonorProcessStatus.tested,
                  ]).length,
                  doneCount: _byStatus([
                    DonorProcessStatus.donated,
                    DonorProcessStatus.restricted,
                  ]).length,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      DonorManagementDonorList(
                        donors: _byStatus([DonorProcessStatus.accepted]),
                        emptyLabel: 'No pending donors',
                        onAction: _onSchedule,
                        actionLabel: 'Schedule',
                        actionIcon: Icons.calendar_today_rounded,
                        actionColor: const Color(0xFF1565C0),
                      ),
                      DonorManagementDonorList(
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
                      DonorManagementDonorList(
                        donors: _byStatus([
                          DonorProcessStatus.donated,
                          DonorProcessStatus.restricted,
                        ]),
                        emptyLabel: 'No completed donors yet',
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
      setState(() {
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
        onSubmit: (status, reason, notes, reportFileUrl) async {
          Navigator.pop(context);

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
              reportFileUrl: reportFileUrl,
            );
            if (!mounted) return;
            await _loadDonors(showSpinner: false);
            if (!mounted) return;
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
