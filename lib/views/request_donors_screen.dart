import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/chat_controller.dart';
import '../services/cloud_functions_service.dart';
import '../shared/theme/app_theme.dart';
import '../shared/utils/snack_bar_helper.dart';
import 'chat_screen.dart';

/// Shows all registered donors and allows blood bank to start chat
/// for the current request with any selected donor.
class RequestDonorsScreen extends StatefulWidget {
  final String requestId;
  final String hospitalName;

  const RequestDonorsScreen({
    super.key,
    required this.requestId,
    required this.hospitalName,
  });

  @override
  State<RequestDonorsScreen> createState() => _RequestDonorsScreenState();
}

class _RequestDonorsScreenState extends State<RequestDonorsScreen> {
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final ChatController _chatController = ChatController();

  List<Map<String, dynamic>> _donors = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  Future<void> _loadDonors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final participantIds = await _chatController.getChatParticipants(
        widget.requestId,
      );
      final participantsSet = participantIds.toSet();

      final result = await _cloudFunctions.getDonors();
      final raw = result['donors'];
      if (!mounted) return;

      final parsed = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final item in raw) {
          Map<String, dynamic>? donor;
          if (item is Map<String, dynamic>) {
            donor = item;
          } else if (item is Map) {
            donor = Map<String, dynamic>.from(item);
          }
          if (donor != null) {
            final donorId = (donor['id'] ?? '').toString().trim();
            if (donorId.isNotEmpty && participantsSet.contains(donorId)) {
              parsed.add(donor);
            }
          }
        }
      }
      parsed.sort((a, b) {
        final an = (a['fullName'] ?? a['name'] ?? '').toString().toLowerCase();
        final bn = (b['fullName'] ?? b['name'] ?? '').toString().toLowerCase();
        return an.compareTo(bn);
      });

      setState(() {
        _donors = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Donors Who Contacted You',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadDonors, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _donors.isEmpty
          ? const Center(
              child: Text(
                'No donors have contacted this blood bank yet.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDonors,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _donors.length,
                itemBuilder: (context, index) {
                  final donor = _donors[index];
                  final donorId = (donor['id'] ?? '').toString().trim();
                  final donorName =
                      (donor['fullName'] ?? donor['name'] ?? 'Donor')
                          .toString()
                          .trim();
                  final donorLocation =
                      (donor['location'] ?? 'Unknown location').toString();
                  final donorBloodType =
                      (donor['bloodType'] ?? '').toString().trim();
                  final donorPhone =
                      (donor['phoneNumber'] ?? donor['phone'] ?? '')
                          .toString()
                          .trim();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: AppTheme.cardDecoration(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.deepRed.withValues(alpha: 0.1),
                          child: Text(
                            donorName.isNotEmpty ? donorName[0].toUpperCase() : '?',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                donorName.isEmpty ? 'Donor' : donorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (donorBloodType.isNotEmpty)
                                Text(
                                  'Blood type: $donorBloodType',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      donorLocation,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (donorPhone.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_android_outlined,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: SelectableText(
                                        donorPhone,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
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
                                          ClipboardData(text: donorPhone),
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
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  style: AppTheme.primaryButtonStyle(),
                                  onPressed: donorId.isEmpty
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                requestId: widget.requestId,
                                                initialMessage: '',
                                                recipientId: donorId,
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Message',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
