import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/donor_medical_report.dart';
import '../theme/app_theme.dart';

/// Displays the donor's full donation history on their profile.
/// Each card shows a step-by-step journey timeline + PDF report link.
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
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bloodtype_rounded,
                        color: AppTheme.deepRed,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Donation History',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.deepRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        // ── Journey Cards ──────────────────────────────────────
        else
          ...reports.map((r) => _JourneyCard(report: r)),
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatCard(
          icon: Icons.favorite_rounded,
          label: 'Donated',
          value: '$donated',
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.emergency_rounded,
          label: 'Urgent',
          value: '$urgent',
          color: AppTheme.urgentRed,
        ),
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
  Widget build(BuildContext context) => SizedBox(
    width: 104,
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
// Journey Card — replaces the old _ReportCard
// Shows a step-by-step timeline for each donation request
// ─────────────────────────────────────────────────────────────
class _JourneyCard extends StatefulWidget {
  final DonorMedicalReport report;
  const _JourneyCard({required this.report});

  @override
  State<_JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<_JourneyCard> {
  bool _expanded = true;

  // Map each status to its index in the journey
  static const _statusOrder = {
    DonorProcessStatus.accepted: 0,
    DonorProcessStatus.scheduled: 1,
    DonorProcessStatus.tested: 1,
    DonorProcessStatus.donated: 2,
    DonorProcessStatus.restricted: 2, // same level as donated (final step)
  };

  // Journey step definitions
  List<_JourneyStep> get _steps {
    final s = widget.report.status;
    final currentIdx = _statusOrder[s] ?? 0;
    final isRestricted = s == DonorProcessStatus.restricted;

    return [
      _JourneyStep(
        index: 0,
        icon: Icons.check_circle_outline_rounded,
        activeIcon: Icons.check_circle_rounded,
        title: 'Request Accepted',
        subtitle: _formatDate(widget.report.createdAt),
        currentIdx: currentIdx,
      ),
      _JourneyStep(
        index: 1,
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        title: 'Appointment Scheduled',
        subtitle: widget.report.appointmentAt != null
            ? '${_formatDate(widget.report.appointmentAt!)} — ${_formatTime(widget.report.appointmentAt!)}'
            : currentIdx >= 1
            ? 'Appointment confirmed'
            : 'Waiting for hospital',
        currentIdx: currentIdx,
      ),
      _JourneyStep(
        index: 2,
        icon: isRestricted
            ? Icons.block_outlined
            : Icons.favorite_outline_rounded,
        activeIcon: isRestricted ? Icons.block_rounded : Icons.favorite_rounded,
        title: isRestricted ? 'Not Eligible' : 'Donation Completed',
        subtitle: isRestricted
            ? (widget.report.restrictionReason ?? 'See notes below')
            : currentIdx >= 2
            ? 'Report uploaded ... Thank you for saving lives! '
            : 'Awaiting results',
        currentIdx: currentIdx,
        isFinal: true,
        isRestricted: isRestricted,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.report.status;
    final isDone = s == DonorProcessStatus.donated;
    final isRestricted = s == DonorProcessStatus.restricted;

    final headerColor = isDone
        ? Colors.green
        : isRestricted
        ? Colors.orange
        : AppTheme.deepRed;

    final statusLabel = isDone
        ? 'Donated ✓'
        : isRestricted
        ? 'Not Eligible'
        : 'In Progress';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: headerColor.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: headerColor.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
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
                      widget.report.bloodType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.report.isUrgent)
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: headerColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDone
                                  ? Icons.favorite_rounded
                                  : isRestricted
                                  ? Icons.block_rounded
                                  : Icons.timelapse_rounded,
                              size: 12,
                              color: headerColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: headerColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.black38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Hospital + Date row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.local_hospital_rounded,
                  size: 14,
                  color: Colors.black38,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.report.bloodBankName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: Colors.black38,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _formatDate(widget.report.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // ── Animated Journey Timeline ──────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Column(
                children: [
                  // Timeline steps
                  ..._steps.map((step) => _TimelineStepRow(step: step)),

                  // ── Notes ──────────────────────────────────────
                  if (widget.report.notes != null &&
                      widget.report.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.07),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.notes_rounded,
                            size: 14,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              widget.report.notes!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Can donate again ───────────────────────────
                  if (isRestricted &&
                      widget.report.canDonateAgainAt != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_available,
                            size: 15,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Can donate again: ${_formatDate(widget.report.canDonateAgainAt!)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── PDF Report Button ──────────────────────────
                  if (widget.report.reportFileUrl != null) ...[
                    const SizedBox(height: 12),
                    _PdfReportButton(url: widget.report.reportFileUrl!),
                  ],

                  const SizedBox(height: 14),
                ],
              ),
            ),
            secondChild: const SizedBox(height: 12),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
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

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────────────────────
// Data class for one journey step
// ─────────────────────────────────────────────────────────────
class _JourneyStep {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final String subtitle;
  final int currentIdx;
  final bool isFinal;
  final bool isRestricted;

  const _JourneyStep({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.subtitle,
    required this.currentIdx,
    this.isFinal = false,
    this.isRestricted = false,
  });

  bool get isDone => currentIdx > index || (currentIdx == index && isFinal);
  bool get isActive => currentIdx == index && !isFinal;
  bool get isPending => currentIdx < index;
}

// ─────────────────────────────────────────────────────────────
// Single row in the timeline stepper
// ─────────────────────────────────────────────────────────────
class _TimelineStepRow extends StatelessWidget {
  final _JourneyStep step;
  const _TimelineStepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final isLast = step.isFinal;
    final isDone = step.isDone;
    final isActive = step.isActive;
    final isPending = step.isPending;

    final Color dotColor;
    final Color lineColor;

    if (step.isRestricted && isDone) {
      dotColor = Colors.orange;
      lineColor = Colors.orange.withOpacity(0.25);
    } else if (isDone) {
      dotColor = Colors.green;
      lineColor = Colors.green.withOpacity(0.25);
    } else if (isActive) {
      dotColor = AppTheme.deepRed;
      lineColor = AppTheme.deepRed.withOpacity(0.15);
    } else {
      dotColor = Colors.black12;
      lineColor = Colors.black.withOpacity(0.06);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left column: dot + vertical line ──────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: dotColor.withOpacity(isPending ? 0.08 : 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dotColor.withOpacity(isPending ? 0.2 : 0.6),
                      width: isActive ? 2 : 1.5,
                    ),
                  ),
                  child: Icon(
                    isDone || isActive ? step.activeIcon : step.icon,
                    size: 14,
                    color: dotColor.withOpacity(isPending ? 0.3 : 1.0),
                  ),
                ),
                // Vertical connector line (hidden for last step)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Right column: title + subtitle ────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isPending ? Colors.black26 : Colors.black87,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.deepRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NOW',
                            style: TextStyle(
                              color: AppTheme.deepRed,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isPending ? Colors.black26 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PDF Report Button — opens the URL in browser/PDF viewer
// ─────────────────────────────────────────────────────────────
class _PdfReportButton extends StatefulWidget {
  final String url;
  const _PdfReportButton({required this.url});

  @override
  State<_PdfReportButton> createState() => _PdfReportButtonState();
}

class _PdfReportButtonState extends State<_PdfReportButton> {
  bool _loading = false;

  Future<void> _open() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(widget.url);
      final canOpen = await canLaunchUrl(uri);
      if (canOpen) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open report. Try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open report.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _open,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.deepRed.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.deepRed.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.deepRed,
                ),
              )
            else
              const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppTheme.deepRed,
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              _loading ? 'Opening...' : 'Open Medical Attachment',
              style: const TextStyle(
                color: AppTheme.deepRed,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
