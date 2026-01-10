import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Small badge that displays "Urgent" text
/// Used to mark urgent blood requests with red styling
class UrgentBadge extends StatelessWidget {
  /// Whether to show a warning icon before the text
  final bool showIcon;

  const UrgentBadge({super.key, this.showIcon = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.urgentBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: AppTheme.urgentRed,
            ),
            const SizedBox(width: 4),
          ],
          const Text(
            'Urgent',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.urgentRed,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
