import 'package:flutter/material.dart';

import '../../controllers/support_controller.dart';
import '../../models/support_issue_model.dart';
import '../../shared/app_status/loading_status_messages.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/error_message_helper.dart';
import '../../shared/widgets/common/app_bar_with_logo.dart';
import '../../shared/widgets/common/loading_indicator.dart';
import 'support_screen.dart';

/// Full-screen view for one support issue (e.g. deep link from admin-reply push).
/// After load, scrolls the admin reply section into view when present.
class SupportIssueDetailScreen extends StatefulWidget {
  final String issueId;
  final IssueSenderRole senderRole;
  final String? senderName;

  const SupportIssueDetailScreen({
    super.key,
    required this.issueId,
    required this.senderRole,
    this.senderName,
  });

  @override
  State<SupportIssueDetailScreen> createState() =>
      _SupportIssueDetailScreenState();
}

class _SupportIssueDetailScreenState extends State<SupportIssueDetailScreen> {
  final SupportController _controller = SupportController();
  final GlobalKey _adminReplyKey = GlobalKey();

  bool _loading = true;
  String? _error;
  bool _missingInList = false;
  SupportIssue? _issue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _missingInList = false;
      _issue = null;
    });
    try {
      final list = await _controller.fetchMyIssues();
      if (!mounted) return;
      SupportIssue? found;
      for (final t in list) {
        if (t.id == widget.issueId) {
          found = t;
          break;
        }
      }
      setState(() {
        _issue = found;
        _loading = false;
        _missingInList = found == null;
        _error = null;
      });
      if (found != null &&
          found.adminReply != null &&
          found.adminReply!.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = _adminReplyKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.12,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMessageHelper.humanize(e);
        _missingInList = false;
      });
    }
  }

  String _statusLabel(IssueStatus s) {
    switch (s) {
      case IssueStatus.inProgress:
        return 'In Progress';
      case IssueStatus.resolved:
        return 'Resolved';
      case IssueStatus.closed:
        return 'Closed';
      case IssueStatus.open:
        return 'Open';
    }
  }

  String _typeLabel(IssueType t) =>
      t == IssueType.complaint ? 'Complaint' : 'Help';

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: const AppBarWithLogo(title: 'Issue'),
      body: _loading
          ? const LoadingIndicator(message: LoadingStatusMessages.loadingData)
          : _error != null
          ? LoadingIndicator(
              message: _error!,
              messageColor: Colors.red.shade800,
              showSpinner: false,
              onRetry: _load,
            )
          : _missingInList
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This issue is not in your recent list. It may be older than the items we show, or the link may be outdated.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => SupportScreen(
                              senderRole: widget.senderRole,
                              senderName: widget.senderName,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Support'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _IssueDetailBody(
                issue: _issue!,
                adminReplyKey: _adminReplyKey,
                statusLabel: _statusLabel,
                typeLabel: _typeLabel,
                formatDate: _formatDate,
              ),
            ),
    );
  }
}

class _IssueDetailBody extends StatelessWidget {
  final SupportIssue issue;
  final GlobalKey adminReplyKey;
  final String Function(IssueStatus) statusLabel;
  final String Function(IssueType) typeLabel;
  final String Function(DateTime) formatDate;

  const _IssueDetailBody({
    required this.issue,
    required this.adminReplyKey,
    required this.statusLabel,
    required this.typeLabel,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasReply =
        issue.adminReply != null && issue.adminReply!.trim().isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    typeLabel(issue.type),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepRed,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel(issue.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDate(issue.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              issue.subject,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              issue.message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.black87,
              ),
            ),
            if (hasReply) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: adminReplyKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 18,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Admin reply',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        issue.adminReply!.trim(),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Text(
                'No admin reply on this issue yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
