import 'package:flutter/material.dart';

/// Header widget for sections with title, subtitle, and optional right widget
/// Used to organize content sections in dashboards
class SectionHeader extends StatelessWidget {
  /// Main section title
  final String title;
  
  /// Subtitle or description text
  final String subtitle;
  
  /// Optional widget to display on the right (e.g., action button)
  final Widget? rightWidget;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.rightWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        if (rightWidget != null) rightWidget!,
      ],
    );
  }
}
