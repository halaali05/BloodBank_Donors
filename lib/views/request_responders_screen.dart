import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/donor_response_entry.dart';
import '../shared/theme/app_theme.dart';
import '../shared/utils/snack_bar_helper.dart';
import 'chat_screen.dart';

/// Lists donors who selected "I can donate" for a request (blood bank).
/// Data is passed in from [BloodRequest] — no extra Cloud Function call.
class RequestRespondersScreen extends StatefulWidget {
  final String requestId;
  final String subtitle;
  final int initialTabIndex;
  final List<DonorResponseEntry> accepted;
  final List<DonorResponseEntry> rejected;

  const RequestRespondersScreen({
    super.key,
    required this.requestId,
    this.subtitle = '',
    this.initialTabIndex = 0,
    required this.accepted,
    required this.rejected,
  });

  @override
  State<RequestRespondersScreen> createState() =>
      _RequestRespondersScreenState();
}

class _RequestRespondersScreenState extends State<RequestRespondersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Donor responses')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                widget.subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ResponseSegment(
              selected: true,
              icon: Icons.volunteer_activism_outlined,
              label: 'I can donate',
              count: widget.accepted.length,
              color: const Color(0xFF2E7D32),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _DonorList(
              entries: widget.accepted,
              emptyLabel: 'No donors selected "I can donate" yet',
              requestId: widget.requestId,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseSegment extends StatelessWidget {
  const _ResponseSegment({
    required this.selected,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade400,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : Colors.black54),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$label: $count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonorList extends StatelessWidget {
  const _DonorList({
    required this.entries,
    required this.emptyLabel,
    required this.requestId,
  });

  final List<DonorResponseEntry> entries;
  final String emptyLabel;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(color: Colors.black45, fontSize: 15),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.deepRed.withValues(alpha: 0.12),
                    child: Text(
                      e.fullName.isNotEmpty ? e.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.deepRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF212121),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          e.email.isEmpty ? '—' : e.email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF616161),
                          ),
                          maxLines: 4,
                        ),
                        if (e.phoneNumber.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.phone_android_outlined,
                                size: 16,
                                color: Color(0xFF616161),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SelectableText(
                                  e.phoneNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF424242),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                tooltip: 'Copy number',
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: e.phoneNumber),
                                  );
                                  if (!context.mounted) return;
                                  SnackBarHelper.success(
                                    context,
                                    'Number copied',
                                    duration:
                                        const Duration(seconds: 1),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: e.donorId.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                requestId: requestId,
                                initialMessage: '',
                                recipientId: e.donorId,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.deepRed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
