import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';
import 'donor_management_models.dart';

void _showRescheduleRequestDialog(
  BuildContext context,
  DonorPipelineRow donor,
) {
  final pref = donor.reschedulePreferredAt;
  final reason = donor.rescheduleReason?.trim().isNotEmpty == true
      ? donor.rescheduleReason!.trim()
      : '—';

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Reschedule request',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              donor.fullName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.bloodtype_rounded,
                  size: 14,
                  color: AppTheme.deepRed.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  _donorBloodTypeLabel(donor),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(reason),
            const SizedBox(height: 16),
            const Text(
              'Preferred date & time',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pref != null ? _formatDialogDateTime(pref) : '—',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _donorBloodTypeLabel(DonorPipelineRow donor) {
  final t = donor.bloodType?.trim() ?? '';
  return t.isEmpty ? 'Not set' : t;
}

String _rescheduleReasonPreview(DonorPipelineRow donor) {
  final r = donor.rescheduleReason?.trim();
  if (r == null || r.isEmpty) {
    return 'Reschedule requested';
  }
  return r;
}

String _formatDialogDateTime(DateTime dt) {
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
  return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hour:$min $ampm';
}

Future<void> _openLatestReport(
  BuildContext context,
  DonorMedicalReport report,
) async {
  final rawUrl = report.reportFileUrl?.trim() ?? '';
  if (rawUrl.isEmpty) return;

  try {
    final url = Uri.parse(rawUrl);
    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open report: $e')));
  }
}

String _latestReportSubtitle(DonorMedicalReport report) {
  final date = _formatDialogDateTime(report.createdAt);
  final bank = report.bloodBankName.trim();
  if (bank.isEmpty) return date;
  return '$bank · $date';
}

class DonorManagementDonorList extends StatelessWidget {
  final List<DonorPipelineRow> donors;
  final String emptyLabel;
  final void Function(DonorPipelineRow)? onAction;
  final String? actionLabel;
  final IconData? actionIcon;
  final Color? actionColor;

  const DonorManagementDonorList({
    super.key,
    required this.donors,
    required this.emptyLabel,
    this.onAction,
    this.actionLabel,
    this.actionIcon,
    this.actionColor,
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
      itemBuilder: (_, i) => DonorManagementDonorTile(
        donor: donors[i],
        onAction: onAction,
        actionLabel: actionLabel,
        actionIcon: actionIcon,
        actionColor: actionColor,
      ),
    );
  }
}

class DonorManagementDonorTile extends StatelessWidget {
  final DonorPipelineRow donor;
  final void Function(DonorPipelineRow)? onAction;
  final String? actionLabel;
  final IconData? actionIcon;
  final Color? actionColor;

  const DonorManagementDonorTile({
    super.key,
    required this.donor,
    this.onAction,
    this.actionLabel,
    this.actionIcon,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(donor.status);
    final statusLabel = _statusLabel(donor.status);
    final statusIcon = _statusIcon(donor.status);
    final appointmentBadgeLabel = _appointmentBadgeLabel(donor);
    final appointmentBadgeColor = _appointmentBadgeColor(donor);
    final appointmentBadgeIcon = _appointmentBadgeIcon(donor);
    final isPendingTabRow = donor.status == DonorProcessStatus.accepted;
    final pendingReschedule = donor.hasPendingRescheduleRequest;
    final latestReport = donor.latestMedicalReport;
    final latestReportUrl = latestReport?.reportFileUrl?.trim() ?? '';
    final hasLatestReport = latestReport != null && latestReportUrl.isNotEmpty;
    final borderColor = isPendingTabRow
        ? (pendingReschedule ? Colors.deepOrange : const Color(0xFF1976D2))
        : statusColor.withValues(alpha: 0.25);
    final borderWidth = isPendingTabRow ? (pendingReschedule ? 3.0 : 2.5) : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
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
                if (isPendingTabRow && pendingReschedule)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.event_repeat_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isPendingTabRow && !pendingReschedule)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.bloodtype_rounded,
                        size: 12,
                        color: AppTheme.deepRed.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _donorBloodTypeLabel(donor),
                        style: TextStyle(
                          fontSize: 12,
                          color: (donor.bloodType?.trim().isNotEmpty ?? false)
                              ? Colors.black87
                              : Colors.black38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                  if (appointmentBadgeLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: appointmentBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            appointmentBadgeIcon,
                            size: 11,
                            color: appointmentBadgeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            appointmentBadgeLabel,
                            style: TextStyle(
                              color: appointmentBadgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
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
                  if (isPendingTabRow && !pendingReschedule) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(
                            0xFF1976D2,
                          ).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: Colors.blue.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Awaiting first appointment',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.blue.shade900,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isPendingTabRow && pendingReschedule) ...[
                    const SizedBox(height: 8),
                    Tooltip(
                      message: _rescheduleReasonPreview(donor),
                      waitDuration: const Duration(milliseconds: 400),
                      child: InkWell(
                        onTap: () =>
                            _showRescheduleRequestDialog(context, donor),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.deepOrange.withValues(alpha: 0.38),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.edit_calendar_rounded,
                                size: 16,
                                color: Colors.deepOrange.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _rescheduleReasonPreview(donor),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                        color: Colors.deepOrange.shade900,
                                      ),
                                    ),
                                    if (donor.reschedulePreferredAt !=
                                        null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Preferred: ${_formatDialogDateTime(donor.reschedulePreferredAt!)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.deepOrange.shade800,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Colors.deepOrange.shade700,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isPendingTabRow && hasLatestReport) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _openLatestReport(context, latestReport),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: Colors.green.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Last uploaded report',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _latestReportSubtitle(latestReport),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                              color: Colors.green.shade800,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onAction != null && actionLabel != null)
              GestureDetector(
                onTap: () => onAction!(donor),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor!.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: actionColor!.withValues(alpha: 0.3),
                    ),
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

  String? _appointmentBadgeLabel(DonorPipelineRow donor) {
    final a = (donor.appointmentStatus ?? '').toLowerCase();
    if (a == 'completed') return '🟢 Completed';
    if (a == 'missed') return '🔴 Missed';
    if (a == 'scheduled' || donor.status == DonorProcessStatus.scheduled) {
      return '🟡 Scheduled';
    }
    return null;
  }

  Color _appointmentBadgeColor(DonorPipelineRow donor) {
    final a = (donor.appointmentStatus ?? '').toLowerCase();
    if (a == 'completed') return Colors.green;
    if (a == 'missed') return Colors.red;
    return Colors.orange;
  }

  IconData _appointmentBadgeIcon(DonorPipelineRow donor) {
    final a = (donor.appointmentStatus ?? '').toLowerCase();
    if (a == 'completed') return Icons.check_circle_rounded;
    if (a == 'missed') return Icons.cancel_rounded;
    return Icons.schedule_rounded;
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
