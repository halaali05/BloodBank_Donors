import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../shared/theme/app_theme.dart';

/// Tab 2 — Donors overview for Admin
/// Shows all donors with eligibility status and filter chips
class AdminDonorsTab extends StatelessWidget {
  final List<User> donors;
  final int allCount;
  final int eligibleCount;
  final int restrictedCount;
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  const AdminDonorsTab({
    super.key,
    required this.donors,
    required this.allCount,
    required this.eligibleCount,
    required this.restrictedCount,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Summary row ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              _SummaryCol(
                label: 'Total',
                value: allCount,
                color: AppTheme.deepRed,
              ),
              _SummaryCol(
                label: 'Eligible',
                value: eligibleCount,
                color: Colors.green,
              ),
              _SummaryCol(
                label: 'Restricted',
                value: restrictedCount,
                color: Colors.orange,
              ),
            ],
          ),
        ),

        // ── Filter chips ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                    {'key': 'all', 'label': 'All'},
                    {'key': 'eligible', 'label': 'Eligible'},
                    {'key': 'restricted', 'label': 'Restricted'},
                  ].map((f) {
                    final isSelected = currentFilter == f['key'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f['label']!),
                        selected: isSelected,
                        onSelected: (_) => onFilterChanged(f['key']!),
                        selectedColor: AppTheme.deepRed.withValues(alpha: 0.12),
                        checkmarkColor: AppTheme.deepRed,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.deepRed
                              : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.deepRed
                              : Colors.grey.shade300,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),

        // ── Donor list ──
        Expanded(
          child: donors.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No donors found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.padding),
                  itemCount: donors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _DonorCard(donor: donors[i]),
                ),
        ),
      ],
    );
  }
}

// ─────────────────── Donor Card ───────────────────

class _DonorCard extends StatelessWidget {
  final User donor;
  const _DonorCard({required this.donor});

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(donor);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar circle ──
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.deepRed.withValues(alpha: 0.1),
              child: Text(
                _initials(donor.fullName ?? 'D'),
                style: const TextStyle(
                  color: AppTheme.deepRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          donor.fullName ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Blood type badge
                      if (donor.bloodType != null &&
                          donor.bloodType!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.deepRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            donor.bloodType!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    donor.email,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),

                  const SizedBox(height: 6),

                  // Meta row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (donor.location != null && donor.location!.isNotEmpty)
                        _MetaChip(
                          icon: Icons.location_on_outlined,
                          label: donor.location!,
                        ),
                      if (donor.gender != null && donor.gender!.isNotEmpty)
                        _MetaChip(
                          icon: donor.gender == 'male'
                              ? Icons.male
                              : Icons.female,
                          label: donor.gender!,
                        ),
                      if (donor.phoneNumber != null &&
                          donor.phoneNumber!.isNotEmpty)
                        _MetaChip(
                          icon: Icons.phone_outlined,
                          label: donor.phoneNumber!,
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Status chip
                  _StatusChip(status: status, donor: donor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DonorStatus _statusOf(User donor) {
    if (donor.isPermanentlyBlocked) return _DonorStatus.permanentlyBlocked;
    final now = DateTime.now();
    if (donor.restrictedUntil != null && donor.restrictedUntil!.isAfter(now)) {
      return _DonorStatus.medicalRestriction;
    }
    if (donor.nextDonationEligibleAt != null &&
        donor.nextDonationEligibleAt!.isAfter(now)) {
      return _DonorStatus.cooldown;
    }
    return _DonorStatus.eligible;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }
}

enum _DonorStatus { eligible, cooldown, medicalRestriction, permanentlyBlocked }

class _StatusChip extends StatelessWidget {
  final _DonorStatus status;
  final User donor;
  const _StatusChip({required this.status, required this.donor});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _DonorStatus.eligible:
        return _pill(
          '✓ Eligible to donate',
          Colors.green.shade700,
          Colors.green.shade50,
        );
      case _DonorStatus.cooldown:
        final until = donor.nextDonationEligibleAt!;
        final days = until.difference(DateTime.now()).inDays;
        return _pill(
          'Cooldown — $days days left',
          Colors.orange.shade800,
          Colors.orange.shade50,
        );
      case _DonorStatus.medicalRestriction:
        final until = donor.restrictedUntil!;
        return _pill(
          'Medical restriction until ${_fmt(until)}',
          Colors.red.shade700,
          Colors.red.shade50,
        );
      case _DonorStatus.permanentlyBlocked:
        return _pill(
          '⛔ Permanently blocked',
          Colors.red.shade900,
          Colors.red.shade50,
        );
    }
  }

  Widget _pill(String label, Color textColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
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

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _SummaryCol extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SummaryCol({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
