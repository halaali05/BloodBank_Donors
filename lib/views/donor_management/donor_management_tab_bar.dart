import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class DonorManagementTabBar extends StatelessWidget {
  final TabController controller;
  final int pendingCount;
  final int scheduledCount;
  final int doneCount;

  /// When > 0, Pending tab shows an extra hint that someone asked to reschedule.
  final int pendingRescheduleCount;

  const DonorManagementTabBar({
    super.key,
    required this.controller,
    required this.pendingCount,
    required this.scheduledCount,
    required this.doneCount,
    this.pendingRescheduleCount = 0,
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
          _TabLabel(
            'Pending',
            pendingCount,
            rescheduleRequests: pendingRescheduleCount,
          ),
          _TabLabel('Scheduled', scheduledCount),
          _TabLabel('Done', doneCount),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;
  /// Pending tab only: number of donors waiting with a reschedule request.
  final int rescheduleRequests;

  const _TabLabel(
    this.label,
    this.count, {
    this.rescheduleRequests = 0,
  });

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
          if (rescheduleRequests > 0) ...[
            const SizedBox(width: 4),
            Tooltip(
              message:
                  '$rescheduleRequests donor(s) asked to reschedule — check Pending list',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'R·$rescheduleRequests',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
