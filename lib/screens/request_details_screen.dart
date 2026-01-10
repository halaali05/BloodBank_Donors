import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/blood_request_model.dart';
import '../services/requests_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_bar_with_logo.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/urgent_badge.dart';
import '../widgets/common/error_box.dart';
import 'chat_screen.dart';

/// Screen that displays detailed information about a blood request
/// Shown when user taps on a notification or request card
///
/// SECURITY ARCHITECTURE:
/// - Read operations: All go through Cloud Functions (server-side)
///   - Request data: Read via getRequests Cloud Function
/// - No direct Firestore access
class RequestDetailsScreen extends StatefulWidget {
  /// ID of the blood request to display
  final String requestId;

  /// [Deprecated] This parameter is ignored - notifications are always marked as read when opened
  final bool skipAutoMarkAsRead;

  const RequestDetailsScreen({
    super.key,
    required this.requestId,
    this.skipAutoMarkAsRead = false,
  });

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final RequestsService _requestsService = RequestsService.instance;

  BloodRequest? _request;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _loadRequest();
  }

  /// Check if user is authenticated, if not navigate back
  void _checkAuthentication() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to view notification details'),
            ),
          );
        }
      });
    }
  }

  /// Loads request data via Cloud Functions
  Future<void> _loadRequest() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch requests via Cloud Functions
      final result = await _requestsService.getRequests(limit: 100);
      final requests = result['requests'] as List<BloodRequest>;

      // Find the request with matching ID
      final request = requests.firstWhere(
        (r) => r.id == widget.requestId,
        orElse: () => throw Exception('Request not found'),
      );

      if (mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.softBg,
        body: LoadingIndicator(),
      );
    }

    if (_error != null || _request == null) {
      return Scaffold(
        backgroundColor: AppTheme.softBg,
        appBar: AppBarWithLogo(
          title: 'Request details',
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ErrorBox(
          message: _error ?? 'Request not found',
          onRetry: _loadRequest,
        ),
      );
    }

    final request = _request!;
    final location = request.hospitalLocation.trim();
    final details = request.details.trim();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.softBg,
        appBar: AppBarWithLogo(
          title: 'Request details',
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppTheme.padding),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.padding),
            decoration: AppTheme.cardDecoration(
              shadow: AppTheme.cardShadowLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.urgentBg,
                      child: Text(
                        request.bloodType,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.deepRed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${request.units} units needed',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (request.isUrgent) const UrgentBadge(),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Blood bank: ${request.bloodBankName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                          location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(details, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            requestId: widget.requestId,
                            initialMessage: 'Please donate as soon as possible',
                            recipientId: currentUserId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Messages'),
                    style: AppTheme.primaryButtonStyle(
                      borderRadius: 24,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
