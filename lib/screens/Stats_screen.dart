import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/stat_card.dart';

class StatsScreen extends StatelessWidget {
  final Map<String, int> stats;

  const StatsScreen({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text("Statistics"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _StatsGrid(
          totalUnits: stats['totalUnits'] ?? 0,
          activeCount: stats['activeCount'] ?? 0,
          urgentCount: stats['urgentCount'] ?? 0,
          normalCount: stats['normalCount'] ?? 0,
          totalAccepted: stats['totalAccepted'] ?? 0,
          totalRejected: stats['totalRejected'] ?? 0,
        ),
      ),
    );
  }
}

/// نفس اللي عندك
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.totalUnits,
    required this.activeCount,
    required this.urgentCount,
    required this.normalCount,
    required this.totalAccepted,
    required this.totalRejected,
  });

  final int totalUnits;
  final int activeCount;
  final int urgentCount;
  final int normalCount;
  final int totalAccepted;
  final int totalRejected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(
              title: 'Total Units',
              value: '$totalUnits',
              icon: Icons.bloodtype,
              tint: const Color(0xFF1565C0),
              width: cardWidth,
            ),
            StatCard(
              title: 'Active Requests',
              value: '$activeCount',
              icon: Icons.list_alt,
              tint: AppTheme.deepRed,
              width: cardWidth,
            ),
            StatCard(
              title: 'Urgent Requests',
              value: '$urgentCount',
              icon: Icons.warning_amber_rounded,
              tint: const Color(0xFFF57C00),
              width: cardWidth,
            ),
            StatCard(
              title: 'Normal Requests',
              value: '$normalCount',
              icon: Icons.check_circle,
              tint: const Color(0xFF2E7D32),
              width: cardWidth,
            ),
            StatCard(
              title: 'Donor acceptances',
              value: '$totalAccepted',
              icon: Icons.thumb_up_alt_outlined,
              tint: const Color(0xFF2E7D32),
              width: cardWidth,
            ),
            StatCard(
              title: 'Donor rejections',
              value: '$totalRejected',
              icon: Icons.thumb_down_alt_outlined,
              tint: const Color(0xFFC62828),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }
}