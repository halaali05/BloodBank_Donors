import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Welcome header for donor dashboard
/// Displays donor name, welcome message, and quick stats
class DonorHeader extends StatelessWidget {
  /// Name of the donor
  final String donorName;

  /// Total number of available blood requests
  final int totalRequests;

  /// Number of urgent requests
  final int urgentCount;

  const DonorHeader({
    super.key,
    required this.donorName,
    required this.totalRequests,
    required this.urgentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.deepRed.withOpacity(0.10), Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: const Color(0xFFE6EAF2)),
        boxShadow: AppTheme.cardShadowLarge,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.deepRed.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              color: AppTheme.deepRed,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $donorName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Thank you for being a blood donor 💉',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PillStat(label: 'Requests', value: '$totalRequests'),
              const SizedBox(height: 6),
              _PillStat(
                label: 'Urgent',
                value: '$urgentCount',
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _PillStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? AppTheme.urgentBg : const Color(0xFFF1F3FB);
    final fg = highlight ? AppTheme.urgentRed : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: fg,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg.withOpacity(0.85),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
