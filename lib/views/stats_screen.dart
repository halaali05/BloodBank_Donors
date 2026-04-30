import 'package:flutter/material.dart';
import '../models/blood_request_model.dart';
import '../shared/theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  final List<BloodRequest> requests;
  const StatsScreen({super.key, required this.requests});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int? _year;
  int? _month;

  static const _months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  List<int> get _years {
    final s =
        widget.requests
            .where((r) => r.createdAt != null)
            .map((r) => r.createdAt!.year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return s;
  }

  List<BloodRequest> get _filtered => widget.requests.where((r) {
    if (_year != null && (r.createdAt == null || r.createdAt!.year != _year)) {
      return false;
    }
    if (_month != null &&
        (r.createdAt == null || r.createdAt!.month != _month)) {
      return false;
    }
    return true;
  }).toList();

  String get _periodLabel {
    if (_year == null) return 'All Time';
    if (_month == null) return '$_year';
    return '${_months[_month!]} $_year';
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final active = list.where((r) => !r.isCompleted).toList();
    final urgent = active.where((r) => r.isUrgent).length;
    final completed = list.where((r) => r.isCompleted).length;
    final units = list.fold(0, (s, r) => s + r.units);
    final accepted = list.fold(0, (s, r) => s + r.acceptedCount);

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Overview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Filter Bar ──────────────────────────────────────
            _FilterBar(
              years: _years,
              selectedYear: _year,
              selectedMonth: _month,
              months: _months,
              onYearChanged: (y) => setState(() {
                _year = y;
                _month = null;
              }),
              onMonthChanged: (m) => setState(() => _month = m),
              onReset: () => setState(() {
                _year = null;
                _month = null;
              }),
            ),

            const SizedBox(height: 6),
            Text(
              _periodLabel,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),

            // ── Stat Chips row 1 ────────────────────────────────
            Row(
              children: [
                _StatChip(
                  label: 'Total',
                  value: '${list.length}',
                  bg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFF991B1B),
                  icon: Icons.list_alt_rounded,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Active',
                  value: '${active.length}',
                  bg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF1E40AF),
                  icon: Icons.pending_actions_rounded,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Urgent',
                  value: '$urgent',
                  bg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFF92400E),
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Stat Chips row 2 ────────────────────────────────
            Row(
              children: [
                _StatChip(
                  label: 'Done',
                  value: '$completed',
                  bg: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF065F46),
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Units',
                  value: '$units',
                  bg: const Color(0xFFEDE9FE),
                  iconColor: const Color(0xFF5B21B6),
                  icon: Icons.bloodtype_rounded,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'donors',
                  value: '$accepted',
                  bg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF065F46),
                  icon: Icons.volunteer_activism_rounded,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ── Table Header ────────────────────────────────────
            Row(
              children: [
                Text(
                  'Request Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: .3,
                  ),
                ),
                const Spacer(),
                if (list.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.urgentBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${list.length} records',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.deepRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Table ───────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: AppTheme.cardShadow,
              ),
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 38,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No requests for this period',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(0.8),
                          2: FlexColumnWidth(1.3),
                          3: FlexColumnWidth(1.4),
                          4: FlexColumnWidth(0.9),
                          5: FlexColumnWidth(1.6),
                        },
                        children: [
                          // Header row
                          TableRow(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8F8F8),
                            ),
                            children:
                                [
                                      'Blood',
                                      'Units',
                                      'Type',
                                      'Status',
                                      'Accept',
                                      'Date',
                                    ]
                                    .map(
                                      (h) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        child: Text(
                                          h,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                          // Data rows
                          ...list.map((r) {
                            final date = r.createdAt;
                            final dateStr = date != null
                                ? '${date.day.toString().padLeft(2, '0')} ${_months[date.month].substring(0, 3)} ${date.year}'
                                : '—';
                            return TableRow(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: AppTheme.cardBorder,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              children: [
                                _tableCell(_BloodPill(type: r.bloodType)),
                                _tableCell(
                                  Text(
                                    '${r.units}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _tableCell(_TypeBadge(isUrgent: r.isUrgent)),
                                _tableCell(
                                  _StatusBadge(isCompleted: r.isCompleted),
                                ),
                                _tableCell(
                                  Text(
                                    '${r.acceptedCount}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                _tableCell(
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableCell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: child,
  );
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<int> years;
  final int? selectedYear;
  final int? selectedMonth;
  final List<String> months;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int?> onMonthChanged;
  final VoidCallback onReset;

  const _FilterBar({
    required this.years,
    required this.selectedYear,
    required this.selectedMonth,
    required this.months,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list_rounded,
            size: 18,
            color: AppTheme.deepRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedYear,
                isDense: true,
                isExpanded: true,
                hint: const Text('Year', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Years', style: TextStyle(fontSize: 13)),
                  ),
                  ...years.map(
                    (y) => DropdownMenuItem<int?>(
                      value: y,
                      child: Text('$y', style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
                onChanged: onYearChanged,
              ),
            ),
          ),
          Container(
            width: 0.5,
            height: 26,
            color: AppTheme.cardBorder,
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          Expanded(
            child: Opacity(
              opacity: selectedYear == null ? 0.35 : 1,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedMonth,
                  isDense: true,
                  isExpanded: true,
                  hint: const Text('Month', style: TextStyle(fontSize: 13)),
                  items: selectedYear == null
                      ? null
                      : [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'All Months',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          ...List.generate(
                            12,
                            (i) => DropdownMenuItem<int?>(
                              value: i + 1,
                              child: Text(
                                months[i + 1],
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                  onChanged: selectedYear == null ? null : onMonthChanged,
                ),
              ),
            ),
          ),
          if (selectedYear != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bg;
  final Color iconColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: iconColor, size: 13),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────

class _BloodPill extends StatelessWidget {
  final String type;
  const _BloodPill({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF991B1B),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final bool isUrgent;
  const _TypeBadge({required this.isUrgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        isUrgent ? 'Urgent' : 'Normal',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isUrgent ? const Color(0xFF991B1B) : const Color(0xFF1E40AF),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isCompleted;
  const _StatusBadge({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        isCompleted ? 'Completed' : 'Active',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isCompleted
              ? const Color(0xFF065F46)
              : const Color(0xFF92400E),
        ),
      ),
    );
  }
}
