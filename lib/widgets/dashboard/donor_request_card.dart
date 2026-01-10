import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/blood_request_model.dart';
import '../common/urgent_badge.dart';

/// Card widget that displays a blood request in the donor dashboard
/// Shows request details and allows donors to start a conversation
class DonorRequestCard extends StatelessWidget {
  /// The blood request data to display
  final BloodRequest request;

  /// Callback when "Messages" button is pressed
  final VoidCallback? onMessage;

  const DonorRequestCard({super.key, required this.request, this.onMessage});

  @override
  Widget build(BuildContext context) {
    final isUrgent = request.isUrgent == true;
    final cardBg = isUrgent ? AppTheme.urgentCardBg : Colors.white;
    final border = isUrgent ? const Color(0xFFFFCDD2) : const Color(0xFFE6EAF2);

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
                if (onMessage != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: AppTheme.primaryButtonStyle(),
                      onPressed: onMessage,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text(
                        'Messages',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
