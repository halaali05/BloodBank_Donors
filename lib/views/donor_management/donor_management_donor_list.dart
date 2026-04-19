import 'package:flutter/material.dart';

import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';
import 'donor_management_models.dart';

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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
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
                    border: Border.all(color: actionColor!.withValues(alpha: 0.3)),
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
