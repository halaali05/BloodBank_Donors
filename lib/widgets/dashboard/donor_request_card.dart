import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/blood_request_model.dart';
import '../common/urgent_badge.dart';

/// Card widget that displays a blood request in the donor dashboard
/// Shows request details, accept/reject, and optional Messages action.
class DonorRequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback? onMessage;
  final VoidCallback? onDonate;
  final VoidCallback? onUndoDonate;
  final bool isSubmittingResponse;

  const DonorRequestCard({
    super.key,
    required this.request,
    this.onMessage,
    this.onDonate,
    this.onUndoDonate,
    this.isSubmittingResponse = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = request.isUrgent == true;
    final isCompleted = request.isCompleted;
    final cardBg = isUrgent ? AppTheme.urgentCardBg : Colors.white;
    final border = isUrgent ? const Color(0xFFFFCDD2) : const Color(0xFFE6EAF2);
    final my = request.myResponse;
    final isDonating = my == 'accepted';
    final showResponseRow = onDonate != null;

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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDonating
                              ? const Color.fromARGB(255, 13, 161, 18)
                              : const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: isDonating ? 3 : 1,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: isDonating
                              ? const BorderSide(
                                  color: Color.fromARGB(255, 136, 255, 130),
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        onPressed: isSubmittingResponse
                            ? null
                            : (isDonating ? onUndoDonate : onDonate),
                        icon: Icon(
                          isDonating
                              ? Icons.check_circle_outline
                              : Icons.favorite_outline,
                          size: 16,
                        ),
                        label: Text(
                          isDonating ? 'Selected: I can donate' : 'I can donate',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
