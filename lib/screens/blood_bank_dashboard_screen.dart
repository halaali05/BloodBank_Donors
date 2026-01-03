import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'chat_screen.dart';
import 'new_request_screen.dart';
import 'login_screen.dart';
import '../models/blood_request_model.dart';
import '../services/cloud_functions_service.dart';

class BloodBankDashboardScreen extends StatelessWidget {
  final String bloodBankName;
  final String location;

  const BloodBankDashboardScreen({
    super.key,
    required this.bloodBankName,
    required this.location,
  });

  // ===== Theme colors =====
  static const Color deepRed = Color(0xFF7A0009);
  static const Color offWhite = Color(0xFFFDF7F6); // أبيض مائل للسكني
  static const Color cardBorder = Color(0xFFE9E2E1);

  Future<void> _deleteRequestWithNotifications(
    BuildContext context,
    BloodRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || request.bloodBankId != currentUid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only delete your own requests.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Deleting request...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final cloudFunctions = CloudFunctionsService();
      final result = await cloudFunctions.deleteRequest(requestId: request.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Request deleted successfully.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        String errorMessage = 'Failed to delete request. Please try again.';
        switch (e.code) {
          case 'permission-denied':
            errorMessage =
                e.message ??
                'You do not have permission to delete this request.';
            break;
          case 'not-found':
            errorMessage =
                e.message ??
                'Request not found. It may have already been deleted.';
            break;
          case 'invalid-argument':
            errorMessage = e.message ?? 'Invalid request ID. Please try again.';
            break;
          case 'unauthenticated':
            errorMessage = 'Please log in to delete requests.';
            break;
          case 'internal':
            if (e.message != null && e.message!.isNotEmpty) {
              errorMessage = e.message!;
            } else {
              errorMessage = 'Server error occurred. Please try again.';
            }
            break;
          default:
            errorMessage = e.message ?? errorMessage;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: offWhite,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          titleSpacing: 12,
          title: Row(
            children: [
              Image.asset(
                'images/logoBLOOD.png',
                height: 34,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              const Text(
                'Blood Bank',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout, color: deepRed),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                // ignore: use_build_context_synchronously
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFDF7F6)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('bloodBankId', isEqualTo: currentUserId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorBox(
                    title: 'Error loading requests',
                    message: '${snapshot.error}',
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final requests = docs.map((doc) {
                  return BloodRequest.fromMap(
                    Map<String, dynamic>.from(doc.data()),
                    doc.id,
                  );
                }).toList();

                final totalUnits = requests.fold<int>(
                  0,
                  (sum, r) => sum + r.units,
                );
                final urgentCount = requests.where((r) => r.isUrgent).length;
                final normalCount = requests.where((r) => !r.isUrgent).length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(
                        bloodBankName: bloodBankName,
                        location: location,
                      ),
                      const SizedBox(height: 14),

                      _StatsGrid(
                        totalUnits: totalUnits,
                        activeCount: requests.length,
                        urgentCount: urgentCount,
                        normalCount: normalCount,
                      ),

                      const SizedBox(height: 14),

                      _SectionHeader(
                        title: 'Blood Requests',
                        subtitle: requests.isEmpty
                            ? 'No active requests'
                            : 'Manage your current posts',
                        rightWidget: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NewRequestScreen(
                                  bloodBankName: bloodBankName,
                                  initialHospitalLocation: location,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (requests.isEmpty)
                        const _EmptyRequests()
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: requests.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final r = requests[index];
                            return _RequestCard(
                              request: r,
                              onDelete: () =>
                                  _deleteRequestWithNotifications(context, r),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.bloodBankName, required this.location});

  static const Color deepRed = Color(0xFF7A0009);
  static const Color cardBorder = Color(0xFFE9E2E1);

  final String bloodBankName;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: deepRed.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_hospital, color: deepRed, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bloodBankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
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
                        maxLines: 1,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.rightWidget,
  });

  final String title;
  final String subtitle;
  final Widget rightWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        rightWidget,
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.totalUnits,
    required this.activeCount,
    required this.urgentCount,
    required this.normalCount,
  });

  final int totalUnits;
  final int activeCount;
  final int urgentCount;
  final int normalCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              title: 'Total Units',
              value: '$totalUnits',
              icon: Icons.bloodtype,
              tint: const Color(0xFF1565C0),
              width: w,
            ),
            _StatCard(
              title: 'Active Requests',
              value: '$activeCount',
              icon: Icons.list_alt,
              tint: const Color(0xFF7A0009),
              width: w,
            ),
            _StatCard(
              title: 'Urgent',
              value: '$urgentCount',
              icon: Icons.warning_amber_rounded,
              tint: const Color(0xFFF57C00),
              width: w,
            ),
            _StatCard(
              title: 'Normal',
              value: '$normalCount',
              icon: Icons.check_circle,
              tint: const Color(0xFF2E7D32),
              width: w,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    required this.width,
  });

  static const Color cardBorder = Color(0xFFE9E2E1);

  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onDelete});

  static const Color deepRed = Color(0xFF7A0009);
  static const Color cardBorder = Color(0xFFE9E2E1);

  final BloodRequest request;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool canDelete =
        FirebaseAuth.instance.currentUser?.uid == request.bloodBankId;
    final bool isUrgent = request.isUrgent;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: deepRed.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    request.bloodType,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: deepRed,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${request.units} units needed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Urgent',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (canDelete) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Delete',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
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
                    request.hospitalLocation,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
            if (request.details != null &&
                request.details!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.details!.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      requestId: request.id,
                      initialMessage: 'Please donate and save a life ❤️',
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: deepRed,
                ),
                label: const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 12,
                    color: deepRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  static const Color deepRed = Color(0xFF7A0009);
  static const Color cardBorder = Color(0xFFE9E2E1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: deepRed.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.inbox_outlined, color: deepRed, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'No active requests',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a new request to reach donors quickly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9E2E1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 34),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
