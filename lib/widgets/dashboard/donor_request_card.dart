import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/blood_request_model.dart';
import '../common/urgent_badge.dart';

/// Card widget that displays a blood request in the donor dashboard
/// Shows request details, accept/reject, and optional Messages action.
class DonorRequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback? onMessage;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isSubmittingResponse;

  const DonorRequestCard({
    super.key,
    required this.request,
    this.onMessage,
    this.onAccept,
    this.onReject,
    this.isSubmittingResponse = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = request.isUrgent == true;
    final isCompleted = request.isCompleted;
    final cardBg = isUrgent ? AppTheme.urgentCardBg : Colors.white;
    final border = isUrgent ? const Color(0xFFFFCDD2) : const Color(0xFFE6EAF2);
    final my = request.myResponse;
    final showResponseRow = onAccept != null && onReject != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.deepRed.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              request.bloodType,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.deepRed,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${request.units} units needed',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isUrgent) const UrgentBadge(),
                    if (isCompleted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Blood bank: ${request.bloodBankName}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                if (request.hospitalLocation.trim().isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.hospitalLocation.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (request.details.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.details.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ],
                if (showResponseRow) ...[
                  const SizedBox(height: 10),
                  if (isCompleted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Donation completed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    )
                  else
                  if (my == null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                isSubmittingResponse ? null : onReject,
                            icon: const Icon(Icons.close, size: 15),
                            label: const Text(
                              'Reject',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC62828),
                              side: const BorderSide(
                                color: Color(0xFFC62828),
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 34),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              elevation: 1,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 34),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed:
                                isSubmittingResponse ? null : onAccept,
                            icon: const Icon(Icons.check, size: 15),
                            label: const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _FinalChoicePill(
                            icon: Icons.close,
                            label: 'Reject',
                            isChosen: my == 'rejected',
                            isRejectStyle: true,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _FinalChoicePill(
                            icon: Icons.check,
                            label: 'Accept',
                            isChosen: my == 'accepted',
                            isRejectStyle: false,
                          ),
                        ),
                      ],
                    ),
                ],
                if (isSubmittingResponse && showResponseRow)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (onMessage != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: AppTheme.primaryButtonStyle().copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        minimumSize: WidgetStateProperty.all(
                          const Size(0, 36),
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onMessage,
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text(
                        'Messages',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
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
}

/// Non-interactive pill matching compact Accept/Reject size; shows final choice.
class _FinalChoicePill extends StatelessWidget {
  const _FinalChoicePill({
    required this.icon,
    required this.label,
    required this.isChosen,
    required this.isRejectStyle,
  });

  final IconData icon;
  final String label;
  final bool isChosen;
  final bool isRejectStyle;

  @override
  Widget build(BuildContext context) {
    if (isRejectStyle) {
      final border = const Color(0xFFC62828);
      final fg = isChosen ? border : border.withValues(alpha: 0.35);
      final bg = isChosen ? const Color(0xFFFFEBEE) : Colors.grey.shade100;
      return Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isChosen ? border : Colors.grey.shade400),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final green = isChosen ? const Color(0xFF1B5E20) : const Color(0xFF2E7D32);
    final bg = isChosen ? green : Colors.grey.shade400;
    final fg = Colors.white.withValues(alpha: isChosen ? 1 : 0.9);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      elevation: isChosen ? 2 : 0,
      child: SizedBox(
        height: 34,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
