import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_screen.dart';
import 'new_request_screen.dart';
import 'login_screen.dart';
import '../models/blood_request_model.dart';

class BloodBankDashboardScreen extends StatelessWidget {
  final String bloodBankName;
  final String location;

  const BloodBankDashboardScreen({
    super.key,
    required this.bloodBankName,
    required this.location,
  });

  Future<void> _deleteRequestWithNotifications(
    BuildContext context,
    BloodRequest request,
  ) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || request.bloodBankId != currentUid) return;

      final requestId = request.id;
      final batch = FirebaseFirestore.instance.batch();

      final reqRef = FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId);
      final notifSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('requestId', isEqualTo: requestId)
          .get();

      batch.delete(reqRef);
      for (final doc in notifSnap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xfffff1f3), Color(0xfffde6eb)],
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

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      _TopBar(
                        bloodBankName: bloodBankName,
                        location: location,
                        onLogout: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _StatsGrid(
                        totalUnits: totalUnits,
                        activeCount: requests.length,
                        urgentCount: requests.where((r) => r.isUrgent).length,
                        normalCount: requests.where((r) => !r.isUrgent).length,
                      ),
                      const SizedBox(height: 16),
                      _BloodRequestsSection(
                        requests: requests,
                        onCreatePressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NewRequestScreen(
                                bloodBankName: bloodBankName,
                                initialHospitalLocation: location,
                              ),
                            ),
                          );
                        },
                        onDeleteRequest: (request) =>
                            _deleteRequestWithNotifications(context, request),
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

class _RequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback onDelete;

  const _RequestCard({required this.request, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bool canDelete =
        FirebaseAuth.instance.currentUser?.uid == request.bloodBankId;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xfffdfdfd),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe6e9f0)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xffffe3e6),
                  child: Text(
                    request.bloodType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xffe60012),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${request.units} units needed',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (request.isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffffebee),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Urgent',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xffc62828),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (canDelete)
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: onDelete,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              request.hospitalLocation,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ✅ النص الإضافي يظهر هنا مباشرة تحت الموقع بدون أي عناوين
                      if (request.details != null &&
                          request.details!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          request.details!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Messages', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String bloodBankName;
  final String location;
  final VoidCallback onLogout;
  const _TopBar({
    required this.bloodBankName,
    required this.location,
    required this.onLogout,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bloodBankName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              location,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, color: Colors.red),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int totalUnits;
  final int activeCount;
  final int urgentCount;
  final int normalCount;
  const _StatsGrid({
    required this.totalUnits,
    required this.activeCount,
    required this.urgentCount,
    required this.normalCount,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              title: 'Total Units',
              value: '$totalUnits',
              icon: Icons.bloodtype,
              color: Colors.blue,
              width: w,
            ),
            _StatCard(
              title: 'Active Requests',
              value: '$activeCount',
              icon: Icons.list_alt,
              color: Colors.pink,
              width: w,
            ),
            _StatCard(
              title: 'Urgent',
              value: '$urgentCount',
              icon: Icons.warning,
              color: Colors.orange,
              width: w,
            ),
            _StatCard(
              title: 'Normal',
              value: '$normalCount',
              icon: Icons.check_circle,
              color: Colors.green,
              width: w,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final double width;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BloodRequestsSection extends StatelessWidget {
  final List<BloodRequest> requests;
  final VoidCallback onCreatePressed;
  final Function(BloodRequest) onDeleteRequest;
  const _BloodRequestsSection({
    required this.requests,
    required this.onCreatePressed,
    required this.onDeleteRequest,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: onCreatePressed,
          icon: const Icon(Icons.add),
          label: const Text('Create New Request'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xffe60012),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (requests.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No active requests'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _RequestCard(
              request: requests[index],
              onDelete: () => onDeleteRequest(requests[index]),
            ),
          ),
      ],
    );
  }
}
