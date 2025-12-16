import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_screen.dart';
import 'login_screen.dart';
import '../models/blood_request_model.dart';

class DonorDashboardScreen extends StatelessWidget {
  const DonorDashboardScreen({super.key, this.donorName = 'Donor'});

  final String donorName;

  @override
  Widget build(BuildContext context) {
    const hasNotifications = true;

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fb),
      appBar: AppBar(
        title: const Text('Hayat'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                if (hasNotifications)
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DonorHeaderCard(
                      donorName: donorName,
                      totalRequests: 0,
                      urgentCount: 0,
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _EmptyRequestsCard()),
                  ],
                ),
              );
            }

            final requests = snapshot.data!.docs.map((doc) {
              final data = doc.data();
              return BloodRequest.fromMap(
                Map<String, dynamic>.from(data),
                doc.id,
              );
            }).toList();

            final urgentCount = requests
                .where((r) => r.isUrgent == true)
                .length;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DonorHeaderCard(
                    donorName: donorName,
                    totalRequests: requests.length,
                    urgentCount: urgentCount,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Text(
                                'Blood requests',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.bloodtype_outlined,
                                size: 18,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // list
                          Expanded(
                            child: ListView.separated(
                              itemCount: requests.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _DonorRequestPost(
                                  request: requests[index],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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

/// الكرت اللي فوق: ترحيب + عدد الطلبات + عدد العاجلة
class _DonorHeaderCard extends StatelessWidget {
  final String donorName;
  final int totalRequests;
  final int urgentCount;

  const _DonorHeaderCard({
    required this.donorName,
    required this.totalRequests,
    required this.urgentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffffe3e6), Color(0xfffff6f7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.favorite, color: Color(0xffe60012)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $donorName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thank you for being a blood donor 💉',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SmallPillStat(label: 'Requests', value: '$totalRequests'),
              const SizedBox(height: 4),
              _SmallPillStat(
                label: 'Urgent',
                value: '$urgentCount',
                isHighlighted: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallPillStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _SmallPillStat({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isHighlighted
        ? const Color(0xffffebee)
        : const Color(0xfff1f3fb);
    final Color textColor = isHighlighted
        ? const Color(0xffc62828)
        : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Text(
            '$value ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

/// كرت فاضي لو ما في طلبات
class _EmptyRequestsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircleAvatar(
            radius: 36,
            backgroundColor: Color(0xffffe3e6),
            child: Icon(
              Icons.bloodtype_outlined,
              color: Color(0xffe60012),
              size: 32,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No blood requests yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'When a blood bank posts a request,\n'
            'it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _DonorRequestPost extends StatelessWidget {
  final BloodRequest request;

  const _DonorRequestPost({required this.request});

  @override
  Widget build(BuildContext context) {
    final location = request.hospitalLocation.trim();
    final details = request.details.trim();

    final bool isUrgent = request.isUrgent;

    final Color cardBg = isUrgent
        ? const Color(0xfffff5f5)
        : const Color(0xfffdfdfd);
    final Color borderColor = isUrgent
        ? const Color(0xffffcdd2)
        : const Color(0xffe6e9f0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الدم
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xffffe3e6),
            child: Text(
              request.bloodType,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xffe60012),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // التفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // السطر الأعلى: عدد الوحدات + badge عاجل
                Row(
                  children: [
                    Text(
                      '${request.units} units needed',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isUrgent)
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
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
                const SizedBox(height: 8),

                // زر الرسائل يمين
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
