import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/cloud_functions_service.dart';
import '../theme/app_theme.dart';

/// Screen that displays a list of available donors
/// Used by blood banks to select a donor to chat with
/// Can optionally filter by blood type
class ContactsScreen extends StatefulWidget {
  /// ID of the blood request (used when navigating to chat)
  final String requestId;

  /// Optional: Filter donors by specific blood type
  final String? bloodType;

  const ContactsScreen({super.key, required this.requestId, this.bloodType});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _cloudFunctions = CloudFunctionsService();

  // State
  List<Map<String, dynamic>>? _donors; // List of donor data
  bool _isLoading = true; // Show loading while fetching
  String? _error; // Error message if loading fails

  @override
  void initState() {
    super.initState();
    // Load donors list when screen opens
    _loadDonors();
  }

  /// Fetches the list of available donors from Cloud Functions
  /// Optionally filters by blood type if specified
  Future<void> _loadDonors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _cloudFunctions.getDonors(
        bloodType: widget.bloodType,
      );

      if (mounted) {
        setState(() {
          // Safely convert the donors list from the result
          final donorsList = result['donors'];
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
                .where((map) => map.isNotEmpty && map['id'] != null)
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
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Select Donor',
          style: TextStyle(fontWeight: FontWeight.w800),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Error loading donors: $_error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDonors,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: AppTheme.primaryButtonStyle(),
            ),
          ],
        ),
      );
    }

    if (_donors == null || _donors!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              widget.bloodType != null
                  ? 'No donors found with blood type ${widget.bloodType}'
                  : 'No donors found',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDonors,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _donors!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final donor = _donors![index];
          final donorId = donor['id'] as String? ?? '';
          final donorName =
              donor['fullName'] as String? ??
              donor['name'] as String? ??
              'Donor';
          final donorLocation =
              donor['location'] as String? ?? 'Unknown location';

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.deepRed.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      donorName.isNotEmpty ? donorName[0].toUpperCase() : 'D',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.deepRed,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
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
                                  initialMessage:
                                      'Please $donorName donate and save a life ❤️',
                                  recipientId: donorId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text(
                            'Messages',
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
