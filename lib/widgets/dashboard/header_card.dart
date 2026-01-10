import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Header card displayed at the top of dashboards
/// Shows organization name (blood bank) and location with an icon
class HeaderCard extends StatelessWidget {
  /// Main title (e.g., blood bank name)
  final String title;
  
  /// Optional subtitle (e.g., location)
  final String? subtitle;
  
  /// Icon to display (defaults to hospital icon)
  final IconData icon;
  
  /// Optional custom color for the icon
  final Color? iconColor;

  const HeaderCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.local_hospital,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.deepRed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(shadow: AppTheme.cardShadowLarge),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
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
                          subtitle!,
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
