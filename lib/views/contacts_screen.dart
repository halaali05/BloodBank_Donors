import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_screen.dart';
import '../services/cloud_functions_service.dart';
import '../shared/theme/app_theme.dart';
import '../shared/utils/snack_bar_helper.dart';
import '../controllers/chat_controller.dart';

class ContactsScreen extends StatefulWidget {
  final String requestId;
  final String? bloodType;

  const ContactsScreen({super.key, required this.requestId, this.bloodType});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _cloudFunctions = CloudFunctionsService();
  final ChatController _chatController = ChatController();

  List<Map<String, dynamic>>? _donors;
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
      final result = await _cloudFunctions.getDonors(
        bloodType: widget.bloodType,
      );

      final donorsList = result['donors'];

      // 🔥 بس الناس اللي تواصلوا
      final chatUserIds =
          await _chatController.getChatParticipants(widget.requestId);

      if (mounted) {
        setState(() {
          if (donorsList is List && donorsList.isNotEmpty) {
            _donors = donorsList
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item);
                  } else {
                    return <String, dynamic>{};
                  }
                })
                .where((map) =>
                    map.isNotEmpty &&
                    map['id'] != null &&
                    chatUserIds.contains(map['id'])) // 🔥 الفلترة
                .toList();
          } else {
            _donors = [];
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'People who contacted you',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_donors == null || _donors!.isEmpty) {
      return const Center(child: Text('No contacts yet'));
    }

    return RefreshIndicator(
      onRefresh: _loadDonors,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _donors!.length,
        itemBuilder: (context, index) {
          final donor = _donors![index];
          final donorId = donor['id'];
          final donorName =
              donor['fullName'] ?? donor['name'] ?? 'Donor';
          final donorLocation =
              donor['location'] ?? 'Unknown location';
          final donorPhone = (donor['phoneNumber'] ?? donor['phone'] ?? '')
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
                  child: Text(donorName[0].toUpperCase()),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
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
                          onPressed: () {
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
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
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
    );
  }
}