import 'package:flutter/material.dart';
import '../models/donor_medical_report.dart';
import '../theme/app_theme.dart';

/// Displays the donor's full donation history on their profile.
/// Each card shows the request details, outcome, and links to the medical report.
class DonationHistorySection extends StatelessWidget {
  final List<DonorMedicalReport> reports;
  final bool isLoading;

  const DonationHistorySection({
    super.key,
    required this.reports,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.deepRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.bloodtype_rounded,
                      color: AppTheme.deepRed,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Donation History',
                      style: TextStyle(
                        color: AppTheme.deepRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (reports.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Text(
                    '${reports.where((r) => r.status == DonorProcessStatus.donated).length} donations',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Stats Row ──────────────────────────────────────────
        if (reports.isNotEmpty) ...[
          _StatsRow(reports: reports),
          const SizedBox(height: 14),
        ],

        // ── Loading ────────────────────────────────────────────
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppTheme.deepRed),
            ),
          )
        // ── Empty State ────────────────────────────────────────
        else if (reports.isEmpty)
          _EmptyHistoryCard()
        // ── Report Cards ───────────────────────────────────────
        else
          ...reports.map((r) => _ReportCard(report: r)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stats Row (mini summary at top)
// ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<DonorMedicalReport> reports;
  const _StatsRow({required this.reports});

  @override
  Widget build(BuildContext context) {
    final donated = reports
        .where((r) => r.status == DonorProcessStatus.donated)
        .length;
    final restricted = reports
        .where((r) => r.status == DonorProcessStatus.restricted)
        .length;
    final urgent = reports.where((r) => r.isUrgent).length;

    return Row(
      children: [
        _StatCard(
          icon: Icons.favorite_rounded,
          label: 'Donated',
          value: '$donated',
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        _StatCard(
          icon: Icons.emergency_rounded,
          label: 'Urgent',
          value: '$urgent',
          color: AppTheme.urgentRed,
        ),
        const SizedBox(width: 8),
        _StatCard(
          icon: Icons.block_rounded,
          label: 'Restricted',
          value: '$restricted',
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.black38, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────
class _EmptyHistoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppTheme.cardShadow,
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.deepRed.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.bloodtype_outlined,
            color: AppTheme.deepRed,
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No donations yet',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Accept a blood request to start\nyour donation journey.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black38, fontSize: 13),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Individual Report Card
// ─────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final DonorMedicalReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDonated = report.status == DonorProcessStatus.donated;
    final isRestricted = report.status == DonorProcessStatus.restricted;

    final statusColor = isDonated
        ? Colors.green
        : isRestricted
        ? Colors.orange
        : Colors.blue;

    final statusLabel = isDonated
        ? 'Donated'
        : isRestricted
        ? 'Restricted'
        : 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // ── Top bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Blood type pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.bloodType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (report.isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.urgentBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'URGENT',
                      style: TextStyle(
                        color: AppTheme.urgentRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDonated
                            ? Icons.favorite_rounded
                            : isRestricted
                            ? Icons.block_rounded
                            : Icons.hourglass_top_rounded,
                        size: 12,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hospital name
                Row(
                  children: [
                    const Icon(
                      Icons.local_hospital_rounded,
                      size: 14,
                      color: Colors.black38,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        report.bloodBankName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Date
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: Colors.black38,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDate(report.createdAt),
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // Restriction reason
                if (isRestricted && report.restrictionReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            report.restrictionReason!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Can donate again
                if (isRestricted && report.canDonateAgainAt != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_available,
                        size: 13,
                        color: Colors.black38,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Can donate again: ${_formatDate(report.canDonateAgainAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],

                // Notes
                if (report.notes != null && report.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    report.notes!,
                    style: const TextStyle(
                      color: Colors.black38,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                // View report button
                if (report.reportFileUrl != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      // TODO: open report URL
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.deepRed.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.deepRed.withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppTheme.deepRed,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'View Medical Report',
                            style: TextStyle(
                              color: AppTheme.deepRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
