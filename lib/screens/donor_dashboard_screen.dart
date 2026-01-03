import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_screen.dart';
import 'login_screen.dart';
import '../models/blood_request_model.dart';
import '../services/requests_service.dart';
import 'notifications_screen.dart';
import '../services/fcm_service.dart';

class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key, this.donorName = 'Donor'});
  final String donorName;

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen> {
  static const Color deepRed = Color(0xFF7A0009);
  static const Color bg = Color(0xFFF3F5F9);
  static const Color cardBorder = Color(0xFFE6EAF2);

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    // ✅ FCM مرة وحدة فقط + بدون ما يكسر الصفحة لو صار error
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FCMService.instance.initFCM();
      } catch (e) {
        debugPrint('⚠️ initFCM failed (ignored): $e');
      }
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: false,

        leadingWidth: 90,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'images/logoBLOOD.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),

        title: const SizedBox.shrink(),

        actions: [
          if (user != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(user.uid)
                  .collection('user_notifications')
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final hasUnread =
                    snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                return IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none),
                      if (hasUnread)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
          else
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_none),
            ),

          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: deepRed),
            onPressed: _logout,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: SafeArea(
        child: StreamBuilder<List<BloodRequest>>(
          stream: RequestsService.instance.getRequestsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorBox(message: '${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = snapshot.data ?? const <BloodRequest>[];
            final urgentCount = requests
                .where((r) => r.isUrgent == true)
                .length;

            // ✅ ListView واحد (Scroll مضمون)
            return RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  _DonorHeaderPro(
                    donorName: widget.donorName,
                    totalRequests: requests.length,
                    urgentCount: urgentCount,
                  ),
                  const SizedBox(height: 14),

                  _SectionHeader(
                    title: 'Blood Requests',
                    subtitle: requests.isEmpty
                        ? 'No requests yet'
                        : 'Latest posts from blood banks',
                  ),
                  const SizedBox(height: 10),

                  if (requests.isEmpty)
                    const _EmptyRequestsCardPro()
                  else
                    ...requests.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DonorRequestCardPro(request: r),
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

class _DonorHeaderPro extends StatelessWidget {
  const _DonorHeaderPro({
    required this.donorName,
    required this.totalRequests,
    required this.urgentCount,
  });

  static const Color deepRed = Color(0xFF7A0009);

  final String donorName;
  final int totalRequests;
  final int urgentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [deepRed.withOpacity(0.10), Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: deepRed.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: deepRed, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $donorName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Thank you for being a blood donor 💉',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PillStat(label: 'Requests', value: '$totalRequests'),
              const SizedBox(height: 6),
              _PillStat(
                label: 'Urgent',
                value: '$urgentCount',
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  const _PillStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? const Color(0xFFFFEBEE) : const Color(0xFFF1F3FB);
    final fg = highlight ? const Color(0xFFC62828) : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: fg,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg.withOpacity(0.85),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _EmptyRequestsCardPro extends StatelessWidget {
  const _EmptyRequestsCardPro();

  static const Color deepRed = Color(0xFF7A0009);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: deepRed.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bloodtype_outlined,
              color: deepRed,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No blood requests yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'When a blood bank posts a request, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DonorRequestCardPro extends StatelessWidget {
  const _DonorRequestCardPro({required this.request});

  static const Color deepRed = Color(0xFF7A0009);

  final BloodRequest request;

  @override
  Widget build(BuildContext context) {
    final isUrgent = request.isUrgent == true;

    final cardBg = isUrgent ? const Color(0xFFFFF5F5) : Colors.white;
    final border = isUrgent ? const Color(0xFFFFCDD2) : const Color(0xFFE6EAF2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: deepRed.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Blood bank: ${request.bloodBankName}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 6),

                if (request.hospitalLocation.trim().isNotEmpty)
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
                          request.hospitalLocation.trim(),
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

                if (request.details.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.details.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ],

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            requestId: request.id,

                            // ✅ المسج الثابتة
                            initialMessage:
                                'Please donate blood and save a life.',
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
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
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
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 34),
              const SizedBox(height: 10),
              const Text(
                'Error',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
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
