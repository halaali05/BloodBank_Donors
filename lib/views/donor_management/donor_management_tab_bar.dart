import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class DonorManagementTabBar extends StatelessWidget {
  final TabController controller;
  final int availableCount;
  final int scheduledCount;
  final int completedCount;
  final int missedCount;

  const DonorManagementTabBar({
    super.key,
    required this.controller,
    required this.availableCount,
    required this.scheduledCount,
    required this.completedCount,
    required this.missedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppTheme.deepRed,
          borderRadius: BorderRadius.circular(11),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black45,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: [
          _TabLabel('🟢 Available', availableCount),
          _TabLabel('Scheduled', scheduledCount),
          _TabLabel('✅ Completed', completedCount),
          _TabLabel('❌ Missed', missedCount),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;

  const _TabLabel(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }
}
