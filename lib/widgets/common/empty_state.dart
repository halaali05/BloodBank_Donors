import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Displays an empty state message with icon
/// Used when there's no data to show (e.g., no requests, no notifications)
class EmptyState extends StatelessWidget {
  /// Icon to display in the center
  final IconData icon;

  /// Main title text
  final String title;

  /// Optional subtitle/description text
  final String? subtitle;

  /// Optional custom color for the icon (defaults to deepRed)
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.deepRed;
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
