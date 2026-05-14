import 'package:flutter/material.dart';
import '../../controllers/support_controller.dart';
import '../../models/support_ticket_model.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/snack_bar_helper.dart';

class AdminSupportTab extends StatefulWidget {
  const AdminSupportTab({super.key});

  @override
  State<AdminSupportTab> createState() => _AdminSupportTabState();
}

class _AdminSupportTabState extends State<AdminSupportTab> {
  final SupportController _controller = SupportController();
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  TicketType? _filterType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _controller.fetchAllTickets(filterType: _filterType);
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarHelper.failureFrom(context, e);
    }
  }

  Future<void> _openReplyDialog(SupportTicket ticket) async {
    final replyCtrl = TextEditingController(text: ticket.adminReply ?? '');
    TicketStatus selectedStatus = ticket.status == TicketStatus.open
        ? TicketStatus.inProgress
        : ticket.status;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text(
            'Reply to Ticket',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.senderName ?? ticket.senderEmail,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        ticket.senderRole == TicketSenderRole.hospital
                            ? 'Blood Bank'
                            : 'Donor',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ticket.subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ticket.message,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Your Reply',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: replyCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write your response...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.deepRed),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (replyCtrl.text.trim().isEmpty) {
                  SnackBarHelper.failureFrom(context, 'Reply cannot be empty');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _controller.replyToTicket(
                    ticketId: ticket.id,
                    reply: replyCtrl.text,
                    newStatus: TicketStatus.resolved,
                  );
                  if (!mounted) return;
                  SnackBarHelper.success(context, 'Reply sent successfully.');
                  await _load();
                } catch (e) {
                  if (!mounted) return;
                  SnackBarHelper.failureFrom(context, e);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepRed,
              ),
              child: const Text(
                'Send Reply',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTicket(SupportTicket ticket) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Ticket'),
        content: Text('Delete "${ticket.subject}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _controller.deleteTicket(ticket.id);
      if (!mounted) return;
      SnackBarHelper.success(context, 'Ticket deleted.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.failureFrom(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // فلتر النوع فقط
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Types',
                  selected: _filterType == null,
                  onTap: () {
                    setState(() => _filterType = null);
                    _load();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Help',
                  icon: Icons.help_outline_rounded,
                  selected: _filterType == TicketType.help,
                  color: Colors.blue,
                  onTap: () {
                    setState(() => _filterType = TicketType.help);
                    _load();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Complaint',
                  icon: Icons.report_problem_outlined,
                  selected: _filterType == TicketType.complaint,
                  color: Colors.orange,
                  onTap: () {
                    setState(() => _filterType = TicketType.complaint);
                    _load();
                  },
                ),
              ],
            ),
          ),
        ),

        // القائمة
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.deepRed),
                )
              : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No tickets found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.deepRed,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AdminTicketCard(
                      ticket: _tickets[i],
                      onReply: () => _openReplyDialog(_tickets[i]),
                      onDelete: () => _deleteTicket(_tickets[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.deepRed;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? c : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? c : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _AdminTicketCard({
    required this.ticket,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoleBadge(role: ticket.senderRole),
                const SizedBox(width: 6),
                _TypeBadgeSmall(type: ticket.type),
                const Spacer(),
                Text(
                  '${ticket.createdAt.day}/${ticket.createdAt.month}/${ticket.createdAt.year}',
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: Colors.black45,
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.senderName ?? ticket.senderEmail,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.subject,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              ticket.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusBadgeSmall(status: ticket.status),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onReply,
                  icon: const Icon(
                    Icons.reply_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: Text(
                    ticket.adminReply != null ? 'Edit Reply' : 'Reply',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepRed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            if (ticket.adminReply != null && ticket.adminReply!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ticket.adminReply!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final TicketSenderRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isHospital = role == TicketSenderRole.hospital;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isHospital ? Colors.red.shade50 : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHospital ? Colors.red.shade200 : Colors.teal.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHospital
                ? Icons.local_hospital_rounded
                : Icons.volunteer_activism_rounded,
            size: 11,
            color: isHospital ? Colors.red.shade700 : Colors.teal.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isHospital ? 'Blood Bank' : 'Donor',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isHospital ? Colors.red.shade700 : Colors.teal.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadgeSmall extends StatelessWidget {
  final TicketType type;
  const _TypeBadgeSmall({required this.type});

  @override
  Widget build(BuildContext context) {
    final isComplaint = type == TicketType.complaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isComplaint ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isComplaint ? Colors.orange.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Text(
        isComplaint ? 'Complaint' : 'Help',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isComplaint ? Colors.orange.shade700 : Colors.blue.shade700,
        ),
      ),
    );
  }
}

class _StatusBadgeSmall extends StatelessWidget {
  final TicketStatus status;
  const _StatusBadgeSmall({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case TicketStatus.open:
        color = Colors.red;
        label = 'Open';
        break;
      case TicketStatus.inProgress:
        color = Colors.purple;
        label = 'In Progress';
        break;
      case TicketStatus.resolved:
        color = Colors.green;
        label = 'Resolved';
        break;
      case TicketStatus.closed:
        color = Colors.grey;
        label = 'Closed';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
