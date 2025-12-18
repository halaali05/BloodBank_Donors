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

  // ✅ دالة حذف الطلب + كل إشعاراته
  Future<void> _deleteRequestWithNotifications(
    BuildContext context,
    BloodRequest request,
  ) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      // تأكيد إنو اللي بحذف هو صاحب الطلب (البنك)
      if (currentUid == null || request.bloodBankId != currentUid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are not allowed to delete this request.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final requestId = request.id;

      // 1) مرجع الطلب
      final reqRef = FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId);

      // 2) كل الإشعارات اللي إلها نفس requestId
      final notifSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('requestId', isEqualTo: requestId)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      // حذف الطلب نفسه
      batch.delete(reqRef);

      // حذف كل الإشعارات المرتبطة
      for (final doc in notifSnap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request and its notifications deleted.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading requests:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // كل الطلبات الموجودة
                final requests = docs.map((doc) {
                  final data = doc.data();
                  return BloodRequest.fromMap(
                    Map<String, dynamic>.from(data),
                    doc.id,
                  );
                }).toList();

                // إحصائيات
                final urgentRequests = requests
                    .where((r) => r.isUrgent == true)
                    .toList();
                final normalRequests = requests
                    .where((r) => r.isUrgent != true)
                    .toList();

                final urgentCount = urgentRequests.length;
                final normalCount = normalRequests.length;
                final activeCount = requests.length;

                final urgentUnits = urgentRequests.fold<int>(
                  0,
                  (sum, r) => sum + r.units,
                );
                final normalUnits = normalRequests.fold<int>(
                  0,
                  (sum, r) => sum + r.units,
                );
                final totalUnits = urgentUnits + normalUnits;

                void goToNewRequest() {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewRequestScreen(
                        bloodBankName: bloodBankName,
                        initialHospitalLocation: location,
                      ),
                    ),
                  );
                }

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
                          if (!context.mounted) return;
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
                        activeCount: activeCount,
                        urgentCount: urgentCount,
                        normalCount: normalCount,
                        urgentUnits: urgentUnits,
                        normalUnits: normalUnits,
                      ),

                      const SizedBox(height: 16),

                      _BloodRequestsSection(
                        requests: requests,
                        onCreatePressed: goToNewRequest,
                        // ✅ نمرّر كولباك الحذف
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

/* -------------------- الإحصائيات -------------------- */

class _StatsGrid extends StatelessWidget {
  final int totalUnits;
  final int activeCount;
  final int urgentCount;
  final int normalCount;
  final int urgentUnits;
  final int normalUnits;

  const _StatsGrid({
    required this.totalUnits,
    required this.activeCount,
    required this.urgentCount,
    required this.normalCount,
    required this.urgentUnits,
    required this.normalUnits,
  });

  @override
  Widget build(BuildContext context) {
    const maxWidth = 650.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final usableWidth = screenWidth < maxWidth ? screenWidth - 32 : maxWidth;
    final cardWidth = (usableWidth - 12) / 2;

    final cards = <_StatCard>[
      const _StatCard(
        title: 'Total units',
        value: '',
        icon: Icons.bloodtype_outlined,
        iconBg: Color(0xffe3f2fd),
        borderColor: Color(0xff1976d2),
      ),
      const _StatCard(
        title: 'Active requests',
        value: '',
        icon: Icons.monitor_heart_outlined,
        iconBg: Color(0xffffebee),
        borderColor: Color(0xffc2185b),
      ),
      const _StatCard(
        title: 'Urgent requests',
        value: '',
        icon: Icons.trending_up,
        iconBg: Color(0xfffff3e0),
        borderColor: Color(0xffef6c00),
      ),
      const _StatCard(
        title: 'Normal requests',
        value: '',
        icon: Icons.check_circle_outline,
        iconBg: Color(0xffe8f5e9),
        borderColor: Color(0xff2e7d32),
      ),
      const _StatCard(
        title: 'Urgent units',
        value: '',
        icon: Icons.warning_amber_rounded,
        iconBg: Color(0xfffff3e0),
        borderColor: Color(0xffef5350),
      ),
      const _StatCard(
        title: 'Normal units',
        value: '',
        icon: Icons.inventory_2_outlined,
        iconBg: Color(0xffe8f5e9),
        borderColor: Color(0xff388e3c),
      ),
    ];

    final values = <String>[
      '$totalUnits',
      '$activeCount',
      '$urgentCount',
      '$normalCount',
      '$urgentUnits',
      '$normalUnits',
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(cards.length, (i) {
            final card = cards[i].copyWith(value: values[i]);
            return SizedBox(width: cardWidth, child: card);
          }),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String bloodBankName;
  final String location;
  final Future<void> Function() onLogout;

  const _TopBar({
    required this.bloodBankName,
    required this.location,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () async => await onLogout(),
              icon: const Icon(Icons.logout, color: Color(0xffb00020)),
              label: const Text(
                'Logout',
                style: TextStyle(color: Color(0xffb00020)),
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  bloodBankName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xff3b0f18),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xffffc2cc),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.favorite,
                color: Color(0xffb00020),
                size: 26,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 2, color: const Color(0xfff8ced4)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color borderColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.borderColor,
  });

  _StatCard copyWith({String? value}) {
    return _StatCard(
      title: title,
      value: value ?? this.value,
      icon: icon,
      iconBg: iconBg,
      borderColor: borderColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withOpacity(0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/* -------------------- قسم البوستات -------------------- */

class _BloodRequestsSection extends StatelessWidget {
  final List<BloodRequest> requests;
  final VoidCallback onCreatePressed;
  final Future<void> Function(BloodRequest request) onDeleteRequest;

  const _BloodRequestsSection({
    required this.requests,
    required this.onCreatePressed,
    required this.onDeleteRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Spacer(),
                  Text(
                    'Blood requests',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onCreatePressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Create new request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffe60012),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (requests.isEmpty)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(height: 16),
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0xffffe3e6),
                      child: Icon(
                        Icons.favorite_border,
                        color: Color(0xffe60012),
                        size: 34,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No blood requests yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Create a new blood request to reach donors',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _RequestCard(
                      request: request,
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete request?'),
                            content: const Text(
                              'This will delete the request and its notifications.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await onDeleteRequest(request);
                        }
                      },
                    );
                  },
                ),
            ],
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
    final location = request.hospitalLocation.trim();
    final details = request.details.trim();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool canDelete =
        currentUid != null && request.bloodBankId == currentUid;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xfffdfdfd),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe6e9f0)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
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
            const SizedBox(width: 10),
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
                            fontWeight: FontWeight.w600,
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
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Urgent',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xffc62828),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (canDelete) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.red,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onDelete,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Blood bank: ${request.bloodBankName}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  if (location.isNotEmpty) ...[
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
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      details,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChatScreen()),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text(
                        'Messages',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
