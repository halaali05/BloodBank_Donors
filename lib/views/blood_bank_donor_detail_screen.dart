import 'package:flutter/material.dart';

import '../models/blood_bank_past_donor.dart';
import '../models/donor_medical_report.dart';
import '../services/cloud_functions_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_bar_with_logo.dart';
import '../widgets/common/error_box.dart';
import '../widgets/donation_history_section.dart';
import 'chat_screen.dart';

class BloodBankDonorDetailScreen extends StatefulWidget {
  final BloodBankPastDonorSummary summary;

  const BloodBankDonorDetailScreen({super.key, required this.summary});

  @override
  State<BloodBankDonorDetailScreen> createState() =>
      _BloodBankDonorDetailScreenState();
}

class _BloodBankDonorDetailScreenState extends State<BloodBankDonorDetailScreen> {
  final CloudFunctionsService _cloud = CloudFunctionsService();
  List<DonorMedicalReport> _reports = [];
  bool _loadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _openMessage(BuildContext context) {
    final d = widget.summary;
    final rid = d.messageRequestId;
    if (rid == null || rid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No open blood request is linked for in-app chat. '
            'Use phone or email below.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          requestId: rid,
          initialMessage: '',
          recipientId: d.donorId,
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final data = await _cloud.getBloodBankDonorMedicalHistory(
        donorId: widget.summary.donorId,
      );
      final raw = data['reports'];
      final list = <DonorMedicalReport>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            final id = m['id']?.toString() ?? '';
            list.add(DonorMedicalReport.fromMap(m, id));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _reports = list;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString().replaceFirst('Exception: ', '');
        _loadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBarWithLogo(
        title: s.fullName,
        actions: [
          IconButton(
            tooltip: 'Message',
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              color: s.messageRequestId != null &&
                      s.messageRequestId!.isNotEmpty
                  ? AppTheme.deepRed
                  : Colors.black26,
            ),
            onPressed: () => _openMessage(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.padding),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppTheme.deepRed.withValues(alpha: 0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.deepRed,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ContactRow(
                        icon: Icons.badge_outlined,
                        label: 'Name',
                        value: s.fullName,
                      ),
                      const SizedBox(height: 10),
                      _ContactRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: s.phoneNumber.isEmpty ? '—' : s.phoneNumber,
                      ),
                      const SizedBox(height: 10),
                      _ContactRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: s.email.isEmpty ? '—' : s.email,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_historyError != null)
                ErrorBox(
                  title: 'Could not load history',
                  message: _historyError!,
                )
              else
                DonationHistorySection(
                  reports: _reports,
                  isLoading: _loadingHistory,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.black45),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
