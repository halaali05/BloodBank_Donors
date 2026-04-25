import 'package:flutter/material.dart';
import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';
import 'donation_history_section.dart';

class DonorProfileDonationHistoryPage extends StatefulWidget {
  final List<DonorMedicalReport> initialReports;
  final bool initialLoading;
  final Future<List<DonorMedicalReport>> Function()? reloadReports;

  const DonorProfileDonationHistoryPage({
    super.key,
    required this.initialReports,
    this.initialLoading = false,
    this.reloadReports,
  });

  @override
  State<DonorProfileDonationHistoryPage> createState() =>
      _DonorProfileDonationHistoryPageState();
}

class _DonorProfileDonationHistoryPageState
    extends State<DonorProfileDonationHistoryPage> {
  late List<DonorMedicalReport> _reports;
  late bool _loading;

  @override
  void initState() {
    super.initState();
    _reports = List<DonorMedicalReport>.from(widget.initialReports);
    _loading = widget.initialLoading && widget.initialReports.isEmpty;
    if (widget.reloadReports != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }
  }

  /// Always defer to the next frame so we never call [setState] during layout/build
  /// (avoids "wrong build scope" when overlapping with parent/timer updates).
  void _scheduleSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }

  Future<void> _reload() async {
    final fn = widget.reloadReports;
    if (fn == null) return;
    _scheduleSetState(() => _loading = _reports.isEmpty);
    try {
      final next = await fn();
      if (!mounted) return;
      _scheduleSetState(() {
        _reports = List<DonorMedicalReport>.from(next);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _scheduleSetState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Donation History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: DonationHistorySliverSection(
              reports: _reports,
              isLoading: _loading,
              onRescheduleSubmitted: widget.reloadReports == null
                  ? null
                  : _reload,
            ),
          ),
        ],
      ),
    );
  }
}
