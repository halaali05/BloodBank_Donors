import 'package:flutter/material.dart';

import '../../controllers/support_controller.dart';
import '../../models/support_ticket_model.dart';
import '../../shared/app_status/loading_status_messages.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/error_message_helper.dart';
import '../../shared/widgets/common/app_bar_with_logo.dart';
import '../../shared/widgets/common/loading_indicator.dart';
import 'support_screen.dart';

/// Full-screen view for one support ticket (e.g. deep link from admin-reply push).
/// After load, scrolls the admin reply section into view when present.
class SupportTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final TicketSenderRole senderRole;
  final String? senderName;

  const SupportTicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.senderRole,
    this.senderName,
  });

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final SupportController _controller = SupportController();
  final GlobalKey _adminReplyKey = GlobalKey();

  bool _loading = true;
  String? _error;
  bool _missingInList = false;
  SupportTicket? _ticket;

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
      _ticket = null;
    });
    try {
      final list = await _controller.fetchMyTickets();
      if (!mounted) return;
      SupportTicket? found;
      for (final t in list) {
        if (t.id == widget.ticketId) {
          found = t;
          break;
        }
      }
      setState(() {
        _ticket = found;
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

  String _statusLabel(TicketStatus s) {
    switch (s) {
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
      case TicketStatus.open:
        return 'Open';
    }
  }

  String _typeLabel(TicketType t) =>
      t == TicketType.complaint ? 'Complaint' : 'Help';

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: const AppBarWithLogo(title: 'Ticket'),
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
                      'This ticket is not in your recent list. It may be older than the items we show, or the link may be outdated.',
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
              child: _TicketDetailBody(
                ticket: _ticket!,
                adminReplyKey: _adminReplyKey,
                statusLabel: _statusLabel,
                typeLabel: _typeLabel,
                formatDate: _formatDate,
              ),
            ),
    );
  }
}

class _TicketDetailBody extends StatelessWidget {
  final SupportTicket ticket;
  final GlobalKey adminReplyKey;
  final String Function(TicketStatus) statusLabel;
  final String Function(TicketType) typeLabel;
  final String Function(DateTime) formatDate;

  const _TicketDetailBody({
    required this.ticket,
    required this.adminReplyKey,
    required this.statusLabel,
    required this.typeLabel,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasReply =
        ticket.adminReply != null && ticket.adminReply!.trim().isNotEmpty;

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
                    typeLabel(ticket.type),
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
                    statusLabel(ticket.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDate(ticket.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              ticket.subject,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ticket.message,
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
                        ticket.adminReply!.trim(),
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
                'No admin reply on this ticket yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
