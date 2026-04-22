import 'package:flutter/material.dart';

import '../models/blood_bank_past_donor.dart';
import '../services/cloud_functions_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_bar_with_logo.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/error_box.dart';
import '../widgets/common/loading_indicator.dart';
import 'blood_bank_donor_detail_screen.dart';
import 'chat_screen.dart';

class BloodBankPastDonorsScreen extends StatefulWidget {
  const BloodBankPastDonorsScreen({super.key});

  @override
  State<BloodBankPastDonorsScreen> createState() =>
      _BloodBankPastDonorsScreenState();
}

class _BloodBankPastDonorsScreenState extends State<BloodBankPastDonorsScreen> {
  final CloudFunctionsService _cloud = CloudFunctionsService();
  List<BloodBankPastDonorSummary> _donors = [];
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
      final data = await _cloud.listBloodBankPastDonors();
      final raw = data['donors'];
      final list = <BloodBankPastDonorSummary>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            list.add(
              BloodBankPastDonorSummary.fromMap(
                Map<String, dynamic>.from(e),
              ),
            );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _donors = list;
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

  void _openMessage(BuildContext context, BloodBankPastDonorSummary d) {
    final rid = d.messageRequestId;
    if (rid == null || rid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No open blood request is linked for in-app chat with this donor. '
            'Open their profile to call or email.',
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

  static String _formatDateMs(int? ms) {
    if (ms == null || ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: const AppBarWithLogo(title: 'Donors'),
      body: SafeArea(
        child: _loading
            ? const LoadingIndicator()
            : _error != null
            ? ErrorBox(title: 'Could not load donors', message: _error!)
            : RefreshIndicator(
                onRefresh: _load,
                child: _donors.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppTheme.padding),
                        children: const [
                          SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.volunteer_activism_outlined,
                            title: 'No donations yet',
                            subtitle:
                                'Donors who complete a donation here will appear in this list.',
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppTheme.padding),
                        children: [
                          ..._donors.map(
                            (d) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: AppTheme.deepRed.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.deepRed.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: AppTheme.deepRed,
                                    ),
                                  ),
                                  title: Text(
                                    d.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      if (d.bloodType.isNotEmpty) d.bloodType,
                                      '${d.donationCount} donation${d.donationCount == 1 ? '' : 's'}',
                                      'Last ${_formatDateMs(d.lastDonatedAtMs)}',
                                    ].join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Message',
                                        icon: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: d.messageRequestId != null &&
                                                  d.messageRequestId!.isNotEmpty
                                              ? AppTheme.deepRed
                                              : Colors.black26,
                                        ),
                                        onPressed: () =>
                                            _openMessage(context, d),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppTheme.deepRed,
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            BloodBankDonorDetailScreen(
                                          summary: d,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }
}
