import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Card widget that displays a statistic with icon, title, and value
/// Used in dashboards to show metrics (e.g., total units, urgent count)
class StatCard extends StatelessWidget {
  /// Label text (e.g., "Total Units")
  final String title;
  
  /// The numeric or text value to display
  final String value;
  
  /// Icon to display at the top
  final IconData icon;
  
  /// Color for the icon
  final Color tint;
  
  /// Optional width (used in grid layouts)
  final double? width;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppTheme.paddingSmall),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
