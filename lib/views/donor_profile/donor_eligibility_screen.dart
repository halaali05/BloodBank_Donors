import 'package:flutter/material.dart';
import '../../controllers/donor_profile_controller.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/donor_eligibility.dart';

/// Shows eligibility end date, countdown, and a day-by-day timeline after last donation.
class DonorEligibilityScreen extends StatefulWidget {
  const DonorEligibilityScreen({super.key});

  @override
  State<DonorEligibilityScreen> createState() => _DonorEligibilityScreenState();
}

class _DonorEligibilityScreenState extends State<DonorEligibilityScreen> {
  final _controller = DonorProfileController();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _controller.fetchUserProfile();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _fmtDate(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month]} ${d.day}, ${d.year}';
  }

  String _fmtTime(DateTime d) {
    final h24 = d.hour;
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final mm = d.minute.toString().padLeft(2, '0');
    final ap = h24 < 12 ? 'AM' : 'PM';
    return '$h12:$mm $ap';
  }

  String _fmtDateTime(DateTime d) => '${_fmtDate(d)} · ${_fmtTime(d)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('When can I donate?'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              )
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final profile = _profile;
    final gender = (profile?['gender'] as String? ?? '').toLowerCase();
    final ruleDays = DonorEligibility.cooldownDaysForGender(gender);
    final end = DonorEligibility.cooldownEndsAt(profile);
    final startDate = DonorEligibility.cooldownWindowStartDate(profile);
    final active = DonorEligibility.isCooldownActive(profile);

    if (end == null || startDate == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.padding),
        children: [
          _infoCard(
            icon: Icons.info_outline_rounded,
            title: 'No waiting period right now',
            body:
                'After a recorded donation, men wait 90 days and women 120 days '
                'before using “I can donate” on new requests. This screen will '
                'show exact dates after your blood bank confirms a donation.',
            highlight: false,
          ),
          const SizedBox(height: 16),
          Text(
            'Your rule: $ruleDays days (${gender == 'female' ? 'women' : 'men'})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final calDaysLeft = DonorEligibility.calendarDaysRemaining(end);
    final totalCalDays = DonorEligibility.cooldownTotalCalendarDays(
      startDate: startDate,
      endInstant: end,
    );
    final elapsedCalDays = now.isBefore(startDate)
        ? 0
        : DateTime(now.year, now.month, now.day).difference(startDate).inDays +
              1;
    final progress = totalCalDays <= 0
        ? 1.0
        : (elapsedCalDays / totalCalDays).clamp(0.0, 1.0);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.padding),
      children: [
        _infoCard(
          icon: active
              ? Icons.hourglass_top_rounded
              : Icons.check_circle_rounded,
          title: active ? 'Waiting period active' : 'You can donate now',
          body: active
              ? 'You can donate again after the date and time below.'
              : 'you are eligible to donate.',
          highlight: active,
        ),
        const SizedBox(height: 16),
        _statRow('Eligible again on :', _fmtDateTime(end)),
        _statRow(
          'Your interval :',
          '$ruleDays days (${gender == 'female' ? 'women' : 'men'})',
        ),
        if (active) ...[
          _statRow('Days left :', '$calDaysLeft', valueColor: AppTheme.deepRed),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 255, 255),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color.fromARGB(255, 103, 19, 6),
                width: 1.5,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color.fromARGB(
                        255,
                        50,
                        2,
                        2,
                      ).withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6.5),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: AppTheme.deepRed,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Day $elapsedCalDays',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _statRow(
    String label,
    String value, {
    Color? labelColor,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: labelColor ?? Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
    required bool highlight,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: highlight
              ? const Color.fromARGB(255, 70, 49, 17)
              : AppTheme.cardBorder,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: highlight
                ? const Color.fromARGB(255, 183, 135, 15)
                : AppTheme.deepRed,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
