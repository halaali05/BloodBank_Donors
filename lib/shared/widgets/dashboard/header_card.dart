import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HeaderCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;

  final int activeUnits;
  final int urgentRequests;
  final int activeRequests; // 👈 جديد

  const HeaderCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.local_hospital,
    this.iconColor,
    required this.activeUnits,
    required this.urgentRequests,
    required this.activeRequests,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.deepRed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadowLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔴 Header Info
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
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

          const SizedBox(height: 18),

          /// Stats row: fixed equal height (avoid stretch + Expanded under
          /// unbounded height from [SingleChildScrollView], which can collapse on web).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeaderStat(
                  label: "Units Needed",
                  value: activeUnits.toString(),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: _HeaderStat(
                  label: "Active Requests",
                  value: activeRequests.toString(),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: _HeaderStat(
                  label: "Urgent Requests",
                  value: urgentRequests.toString(),
                  isUrgent: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isUrgent;

  const _HeaderStat({
    required this.label,
    required this.value,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? Colors.red : Colors.black87;

    return Container(
      width: double.infinity,
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}