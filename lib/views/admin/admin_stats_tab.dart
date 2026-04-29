import 'package:flutter/material.dart';
import '../../controllers/admin_controller.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

/// Tab 3 — System-wide statistics for Admin
class AdminStatsTab extends StatelessWidget {
  final AdminStats? stats;
  final List<BloodRequest> requests;
  final List<User> donors;

  const AdminStatsTab({
    super.key,
    required this.stats,
    required this.requests,
    required this.donors,
  });

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const Center(child: Text('No data available'));
    }
    final s = stats!;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.padding),
      children: [
        // ── Overview cards ──
        _SectionTitle('System Overview'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            _StatCard(
              label: 'Total Requests',
              value: '${s.totalRequests}',
              icon: Icons.list_alt_rounded,
              color: AppTheme.deepRed,
            ),
            _StatCard(
              label: 'Active Requests',
              value: '${s.activeRequests}',
              icon: Icons.hourglass_empty_rounded,
              color: Colors.orange,
            ),
            _StatCard(
              label: 'Urgent',
              value: '${s.urgentRequests}',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
            ),
            _StatCard(
              label: 'Completed',
              value: '${s.completedRequests}',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
            ),
            _StatCard(
              label: 'Total Donors',
              value: '${s.totalDonors}',
              icon: Icons.people_outline_rounded,
              color: Colors.blue,
            ),
            _StatCard(
              label: 'Restricted Donors',
              value: '${s.restrictedDonors}',
              icon: Icons.block_rounded,
              color: Colors.orange,
            ),
            _StatCard(
              label: 'Units Needed',
              value: '${s.totalUnitsNeeded}',
              icon: Icons.water_drop_rounded,
              color: AppTheme.deepRed,
            ),
            _StatCard(
              label: 'Total Acceptances',
              value: '${s.totalAcceptances}',
              icon: Icons.thumb_up_outlined,
              color: Colors.teal,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Blood type distribution ──
        _SectionTitle('Donors by Blood Type'),
        const SizedBox(height: 10),
        if (s.bloodTypeDistribution.isEmpty)
          const _EmptyState(message: 'No blood type data')
        else
          _BarChart(data: s.bloodTypeDistribution, barColor: AppTheme.deepRed),

        const SizedBox(height: 24),

        // ── Requests by blood bank ──
        _SectionTitle('Requests per Hospital'),
        const SizedBox(height: 10),
        if (s.requestsPerBank.isEmpty)
          const _EmptyState(message: 'No hospital data')
        else
          _HorizontalBars(data: s.requestsPerBank, color: Colors.blueAccent),

        const SizedBox(height: 24),

        // ── Donors by governorate ──
        _SectionTitle('Donors by Governorate'),
        const SizedBox(height: 10),
        if (s.donorsPerGovernorate.isEmpty)
          const _EmptyState(message: 'No location data')
        else
          _HorizontalBars(data: s.donorsPerGovernorate, color: Colors.teal),

        const SizedBox(height: 24),

        // ── Recent completion rate ──
        _SectionTitle('Completion Rate'),
        const SizedBox(height: 10),
        _CompletionRateCard(stats: s),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────── Widgets ───────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 15,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<String, int> data;
  final Color barColor;
  const _BarChart({required this.data, required this.barColor});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.entries.map((e) {
          final pct = e.value / maxVal;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 80 * pct,
                    constraints: const BoxConstraints(minHeight: 4),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HorizontalBars extends StatelessWidget {
  final Map<String, int> data;
  final Color color;
  const _HorizontalBars({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    // Sort descending by count
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList(); // max 8 rows
    final maxVal = top.first.value;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: top.map((e) {
          final pct = maxVal > 0 ? e.value / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${e.value}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CompletionRateCard extends StatelessWidget {
  final AdminStats stats;
  const _CompletionRateCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rate = stats.totalRequests == 0
        ? 0.0
        : stats.completedRequests / stats.totalRequests;
    final pct = (rate * 100).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Circular indicator
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 8,
                  backgroundColor: Colors.green.shade50,
                  valueColor: AlwaysStoppedAnimation(Colors.green),
                ),
                Center(
                  child: Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Completion Rate',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.completedRequests} of ${stats.totalRequests} requests completed',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'Avg. ${stats.totalRequests > 0 ? (stats.totalAcceptances / stats.totalRequests).toStringAsFixed(1) : 0} donors/request',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}
