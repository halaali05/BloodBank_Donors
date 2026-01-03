import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/blood_request_model.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color deepRed = Color(0xFF7A0009);
  static const Color bg = Color(0xFFF3F5F9);

  String _formatTime(BuildContext context, Timestamp? ts) {
    if (ts == null) return '';
    final dateTime = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    final t = TimeOfDay.fromDateTime(dateTime).format(context);

    if (diff.inDays == 0) return 'Today • $t';
    if (diff.inDays == 1) return 'Yesterday • $t';
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('user_notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ✅ لو مش مسجل دخول
    if (user == null) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Image.asset(
                  'images/logoBLOOD.png',
                  height: 34,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          body: const Center(
            child: Text(
              'Please login to see notifications.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    final uid = user.uid;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Notifications',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Image.asset(
                'images/logoBLOOD.png',
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _notificationsStream(uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No notifications yet.',
                  style: TextStyle(color: Colors.black54),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();

                final isRead =
                    (data['isRead'] == true) || (data['read'] == true);

                final requestId = (data['requestId'] as String?) ?? '';
                final bloodBankName =
                    (data['bloodBankName'] ?? data['hospitalName'] ?? '')
                        as String;

                final createdAt = data['createdAt'] as Timestamp?;
                final createdAtText = _formatTime(context, createdAt);

                final isUrgent = data['isUrgent'] == true;

                // ✅ كل شيء بالـ deepRed بدل الأخضر
                final Color stripeColor = deepRed;
                final Color iconBg = const Color(0xFFFFEBEE);
                final IconData iconData = isUrgent
                    ? Icons.warning_amber_rounded
                    : Icons.notifications;

                // ✅ لون الكرت (مائل خفيف للأحمر لو urgent)
                final Color cardBg = isUrgent
                    ? const Color(0xFFFFF5F6)
                    : Colors.white;

                return InkWell(
                  onTap: () {
                    if (requestId.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            RequestDetailsScreen(requestId: requestId),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6EAF2)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 12,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // ✅ الشريط الأحمر
                        Container(
                          width: 5,
                          height: 88,
                          decoration: BoxDecoration(
                            color: stripeColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              bottomLeft: Radius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // ✅ أيقونة داخل مربع ناعم
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: iconBg,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        iconData,
                                        size: 20,
                                        color: stripeColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    Expanded(
                                      child: Text(
                                        isUrgent
                                            ? 'Urgent blood request'
                                            : 'New blood request',
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.w700
                                              : FontWeight.w900,
                                          fontSize: 14.5,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),

                                    // ✅ شارة Unread
                                    if (!isRead)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEBEE),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          'Unread',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: deepRed,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                if (bloodBankName.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    bloodBankName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],

                                if (createdAtText.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    createdAtText,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.black45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class RequestDetailsScreen extends StatelessWidget {
  final String requestId;
  const RequestDetailsScreen({super.key, required this.requestId});

  static const Color deepRed = Color(0xFF7A0009);
  static const Color bg = Color(0xFFF3F5F9);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Request details',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Image.asset(
                'images/logoBLOOD.png',
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .doc(requestId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Request not found'));
            }

            final data = snapshot.data!.data()!;
            final request = BloodRequest.fromMap(data, requestId);

            final location = request.hospitalLocation.trim();
            final details = (request.details ?? '').trim();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6EAF2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFFFEBEE),
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
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (request.isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Urgent',
                              style: TextStyle(
                                fontSize: 11,
                                color: deepRed,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
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
                                requestId: requestId,
                                initialMessage:
                                    'Please donate as soon as possible',
                                recipientId:
                                    currentUserId, // Show personalized message for this donor
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Messages'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
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
            );
          },
        ),
      ),
    );
  }
}
