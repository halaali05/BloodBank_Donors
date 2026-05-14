import 'package:flutter/material.dart';
import '../../controllers/support_controller.dart';
import '../../models/support_ticket_model.dart';
import '../../shared/app_status/loading_status_messages.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/error_message_helper.dart';
import '../../shared/widgets/common/app_loading_overlay.dart';
import '../../shared/widgets/common/loading_indicator.dart';

/// شاشة الدعم والشكاوي — للمتبرعين وبنوك الدم
class SupportScreen extends StatefulWidget {
  final TicketSenderRole senderRole;
  final String? senderName;

  const SupportScreen({super.key, required this.senderRole, this.senderName});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupportController _controller = SupportController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Column(
          children: [
            Text(
              'Support & Complaints',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              'We are here to help you',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.deepRed,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.deepRed,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_comment_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('New Ticket'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('My Tickets'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NewTicketTab(
            controller: _controller,
            senderRole: widget.senderRole,
            senderName: widget.senderName,
            onSubmitted: () => _tabController.animateTo(1),
          ),
          _MyTicketsTab(controller: _controller),
        ],
      ),
    );
  }
}

// ─────────────────── تاب: إرسال تذكرة جديدة ───────────────────

class _NewTicketTab extends StatefulWidget {
  final SupportController controller;
  final TicketSenderRole senderRole;
  final String? senderName;
  final VoidCallback onSubmitted;

  const _NewTicketTab({
    required this.controller,
    required this.senderRole,
    required this.senderName,
    required this.onSubmitted,
  });

  @override
  State<_NewTicketTab> createState() => _NewTicketTabState();
}

class _NewTicketTabState extends State<_NewTicketTab> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  TicketType _selectedType = TicketType.help;
  bool _isSubmitting = false;
  bool _submitSuccessFlash = false;
  String? _submitOverlayMessage;
  bool _submitOverlayIsError = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _submitOverlayMessage = LoadingStatusMessages.submittingReport;
      _submitOverlayIsError = false;
    });
    try {
      await widget.controller.submitTicket(
        type: _selectedType,
        subject: _subjectCtrl.text,
        message: _messageCtrl.text,
        senderRole: widget.senderRole,
        senderName: widget.senderName,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitSuccessFlash = true;
        _submitOverlayMessage = LoadingStatusMessages.ticketSubmittedBrief;
        _submitOverlayIsError = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      _subjectCtrl.clear();
      _messageCtrl.clear();
      setState(() {
        _submitOverlayMessage = null;
        _submitSuccessFlash = false;
        _selectedType = TicketType.help;
      });
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitSuccessFlash = false;
        _submitOverlayMessage = LoadingStatusMessages.failedSubmitReport;
        _submitOverlayIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة توضيحية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.deepRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.deepRed.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    color: AppTheme.deepRed,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need help or want to report an issue?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.senderRole == TicketSenderRole.donor
                              ? 'Submit your request and our team will review it.'
                              : 'As a blood bank, your feedback helps us improve the system.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // نوع التذكرة
            const Text(
              'Ticket Type',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _TypeChip(
                  label: 'Help Request',
                  icon: Icons.help_outline_rounded,
                  selected: _selectedType == TicketType.help,
                  color: Colors.blue,
                  onTap: () => setState(() => _selectedType = TicketType.help),
                ),
                const SizedBox(width: 12),
                _TypeChip(
                  label: 'Complaint',
                  icon: Icons.report_problem_outlined,
                  selected: _selectedType == TicketType.complaint,
                  color: Colors.orange,
                  onTap: () =>
                      setState(() => _selectedType = TicketType.complaint),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // الموضوع
            const Text(
              'Subject',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectCtrl,
              maxLength: 100,
              decoration: _inputDecoration(
                hint: 'Brief description of your issue...',
                icon: Icons.title_rounded,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Subject is required';
                if (v.trim().length < 5) return 'Too short';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // الرسالة
            const Text(
              'Message',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 6,
              maxLength: 1000,
              decoration: _inputDecoration(
                hint: 'Describe your issue in detail...',
                icon: Icons.message_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Message is required';
                if (v.trim().length < 10) return 'Please provide more details';
                return null;
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_isSubmitting || _submitSuccessFlash) ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Ticket',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ),
        if (_isSubmitting || _submitOverlayMessage != null)
          AppLoadingOverlay(
            visible: true,
            showProgress: _isSubmitting,
            message: _submitOverlayMessage ??
                LoadingStatusMessages.submittingReport,
            isError: !_isSubmitting && _submitOverlayIsError,
            isSuccess: !_isSubmitting && _submitSuccessFlash,
            progressColor: AppTheme.deepRed,
            onRetry: (!_isSubmitting && _submitOverlayIsError) ? _submit : null,
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.black38, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.deepRed),
      ),
      counterStyle: const TextStyle(fontSize: 11, color: Colors.black38),
    );
  }
}

// ─────────────────── تاب: تذاكري ──────────────────────────────

class _MyTicketsTab extends StatefulWidget {
  final SupportController controller;

  const _MyTicketsTab({required this.controller});

  @override
  State<_MyTicketsTab> createState() => _MyTicketsTabState();
}

class _MyTicketsTabState extends State<_MyTicketsTab> {
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await widget.controller.fetchMyTickets();
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = ErrorMessageHelper.humanize(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingIndicator(
        message: LoadingStatusMessages.loadingData,
        color: AppTheme.deepRed,
      );
    }

    if (_loadError != null) {
      return LoadingIndicator(
        message: LoadingStatusMessages.looksLikeConnectivityIssue(_loadError!)
            ? LoadingStatusMessages.noInternet
            : _loadError!,
        color: AppTheme.deepRed,
        messageColor: LoadingStatusMessages.looksLikeConnectivityIssue(
              _loadError!,
            )
            ? Colors.deepOrange.shade900
            : Colors.red.shade800,
        showSpinner: false,
        connectivityIssue:
            LoadingStatusMessages.looksLikeConnectivityIssue(_loadError!),
        onRetry: _load,
      );
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No tickets yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit a help request or complaint\nand we\'ll respond shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.deepRed,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _TicketCard(ticket: _tickets[i]),
      ),
    );
  }
}

// ─────────────────── بطاقة التذكرة ────────────────────────────

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;

  const _TicketCard({required this.ticket});

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
            // Header: نوع + حالة + تاريخ
            Row(
              children: [
                _TypeBadge(type: ticket.type),
                const SizedBox(width: 8),
                _StatusBadge(status: ticket.status),
                const Spacer(),
                Text(
                  _formatDate(ticket.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // الموضوع
            Text(
              ticket.subject,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            // الرسالة
            Text(
              ticket.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),

            // رد الأدمن
            if (ticket.adminReply != null && ticket.adminReply!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Admin Reply',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket.adminReply!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
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

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ─────────────────── Widgets مساعدة ───────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final TicketType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isComplaint = type == TicketType.complaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isComplaint ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isComplaint ? Colors.orange.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplaint
                ? Icons.report_problem_outlined
                : Icons.help_outline_rounded,
            size: 12,
            color: isComplaint ? Colors.orange.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isComplaint ? 'Complaint' : 'Help',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isComplaint
                  ? Colors.orange.shade700
                  : Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TicketStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, border, text;
    IconData icon;
    String label;

    switch (status) {
      case TicketStatus.open:
        bg = Colors.red.shade50;
        border = Colors.red.shade200;
        text = Colors.red.shade700;
        icon = Icons.fiber_new_rounded;
        label = 'Open';
        break;
      case TicketStatus.inProgress:
        bg = Colors.purple.shade50;
        border = Colors.purple.shade200;
        text = Colors.purple.shade700;
        icon = Icons.hourglass_top_rounded;
        label = 'In Progress';
        break;
      case TicketStatus.resolved:
        bg = Colors.green.shade50;
        border = Colors.green.shade200;
        text = Colors.green.shade700;
        icon = Icons.check_circle_outline_rounded;
        label = 'Resolved';
        break;
      case TicketStatus.closed:
        bg = Colors.grey.shade100;
        border = Colors.grey.shade300;
        text = Colors.grey.shade600;
        icon = Icons.lock_outline_rounded;
        label = 'Closed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
