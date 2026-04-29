import 'package:flutter/material.dart';
import '../../models/blood_request_model.dart';
import '../../theme/app_theme.dart';

/// Tab 1 — Requests management for Admin
/// Shows all requests across all blood banks with filter chips
class AdminRequestsTab extends StatelessWidget {
  final List<BloodRequest> requests;
  final int allCount;
  final int activeCount;
  final int urgentCount;
  final int completedCount;
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function(BloodRequest) onDelete;
  final Future<void> Function(BloodRequest) onMarkCompleted;

  const AdminRequestsTab({
    super.key,
    required this.requests,
    required this.allCount,
    required this.activeCount,
    required this.urgentCount,
    required this.completedCount,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.onDelete,
    required this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Summary row ──
        _SummaryRow(
          items: [
            _SummaryItem(
              label: 'Total',
              value: allCount,
              color: AppTheme.deepRed,
            ),
            _SummaryItem(
              label: 'Active',
              value: activeCount,
              color: Colors.orange,
            ),
            _SummaryItem(
              label: 'Urgent',
              value: urgentCount,
              color: Colors.red,
            ),
            _SummaryItem(
              label: 'Done',
              value: completedCount,
              color: Colors.green,
            ),
          ],
        ),

        // ── Filter chips ──
        _FilterBar(
          filters: const {
            'all': 'All',
            'active': 'Active',
            'urgent': 'Urgent',
            'completed': 'Completed',
          },
          selected: currentFilter,
          onSelected: onFilterChanged,
        ),

        // ── Request list ──
        Expanded(
          child: requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No requests found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.padding),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _AdminRequestCard(
                    request: requests[index],
                    onDelete: () => onDelete(requests[index]),
                    onMarkCompleted: () => onMarkCompleted(requests[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────── Request Card ───────────────────

class _AdminRequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback onDelete;
  final VoidCallback onMarkCompleted;

  const _AdminRequestCard({
    required this.request,
    required this.onDelete,
    required this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = request.isUrgent && !request.isCompleted;
    final borderColor = request.isCompleted
        ? Colors.green.shade200
        : isUrgent
        ? AppTheme.urgentRed.withValues(alpha: 0.3)
        : AppTheme.cardBorder;

    return Container(
      decoration: BoxDecoration(
        color: request.isCompleted
            ? Colors.green.shade50
            : isUrgent
            ? AppTheme.urgentCardBg
            : Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              children: [
                // Blood type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.bloodType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                _StatusBadge(request: request),
                const Spacer(),
                // Units
                Row(
                  children: [
                    Icon(Icons.water_drop, size: 14, color: AppTheme.deepRed),
                    const SizedBox(width: 4),
                    Text(
                      '${request.units} units',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Hospital name ──
            Text(
              request.bloodBankName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            if (request.hospitalLocation.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    request.hospitalLocation,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // ── Donor response counts ──
            Row(
              children: [
                _CountChip(
                  icon: Icons.check_circle_outline,
                  count: request.acceptedCount,
                  label: 'accepted',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _CountChip(
                  icon: Icons.cancel_outlined,
                  count: request.rejectedCount,
                  label: 'rejected',
                  color: Colors.red,
                ),
                const Spacer(),
                if (request.createdAt != null)
                  Text(
                    _formatDate(request.createdAt!),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),

            if (request.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ── Admin Actions ──
            Row(
              children: [
                // Mark completed (only for active)
                if (!request.isCompleted)
                  TextButton.icon(
                    onPressed: onMarkCompleted,
                    icon: const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Mark Done',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                const Spacer(),
                // Delete — admin always can delete
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────── Status Badge ───────────────────

class _StatusBadge extends StatelessWidget {
  final BloodRequest request;
  const _StatusBadge({required this.request});

  @override
  Widget build(BuildContext context) {
    if (request.isCompleted) {
      return _pill('Completed', Colors.green.shade700, Colors.green.shade100);
    }
    if (request.isUrgent) {
      return _pill('Urgent', AppTheme.urgentRed, AppTheme.urgentBg);
    }
    return _pill('Normal', Colors.blue.shade700, Colors.blue.shade50);
  }

  Widget _pill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

// ─────────────────── Count Chip ───────────────────

class _CountChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  const _CountChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────── Shared widgets ───────────────────

class _SummaryRow extends StatelessWidget {
  final List<_SummaryItem> items;
  const _SummaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: items
            .map((item) => Expanded(child: _buildItem(item)))
            .toList(),
      ),
    );
  }

  Widget _buildItem(_SummaryItem item) {
    return Column(
      children: [
        Text(
          '${item.value}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: item.color,
          ),
        ),
        Text(
          item.label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _SummaryItem {
  final String label;
  final int value;
  final Color color;
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _FilterBar extends StatelessWidget {
  final Map<String, String> filters;
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterBar({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final isSelected = selected == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(e.value),
                selected: isSelected,
                onSelected: (_) => onSelected(e.key),
                selectedColor: AppTheme.deepRed.withValues(alpha: 0.12),
                checkmarkColor: AppTheme.deepRed,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.deepRed : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? AppTheme.deepRed : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
