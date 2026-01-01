import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/blood_request_model.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final String uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _markAllAsRead();
  }

  /// نعلّم كل إشعارات هذا المستخدم isRead = true
  Future<void> _markAllAsRead() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {
      // نتجاهل الخطأ عشان ما يطيح التطبيق
    }
  }

  /// فتح الطلب من الإشعار
  Future<void> _openRequestFromNotification(
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    final requestId = data['requestId'] as String?;
    if (requestId == null || requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request not found for this notification.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reqSnap = await FirebaseFirestore.instance
        .collection('requests')
        .doc(requestId)
        .get();

    if (!reqSnap.exists) {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This request was deleted by the blood bank.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(requestId: requestId),
      ),
    );
  }

  /// تنسيق الوقت: Today / Yesterday / تاريخ عادي
  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dateTime = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      final t = TimeOfDay.fromDateTime(dateTime).format(context);
      return 'Today • $t';
    } else if (diff.inDays == 1) {
      final t = TimeOfDay.fromDateTime(dateTime).format(context);
      return 'Yesterday • $t';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xffe60012),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xfff5f6fb),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: uid) // فقط إشعارات هذا المستخدم
              .orderBy('createdAt', descending: true)
              .snapshots(),
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

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No notifications yet.',
                  style: TextStyle(color: Colors.black54),
                ),
              );
            }

            final seenRequestIds = <String>{};
            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data();
              final rid = data['requestId'] as String?;
              if (rid == null) return true;
              if (seenRequestIds.contains(rid)) return false;
              seenRequestIds.add(rid);
              return true;
            }).toList();

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();

                final isRead = data['isRead'] == true;
                final String bloodBankName =
                    (data['bloodBankName'] ?? data['hospitalName'] ?? '')
                        as String;
                final createdAt = data['createdAt'] as Timestamp?;
                final createdAtText = _formatTime(createdAt);
                const String titleText = 'New blood request';
                final String subtitleText = bloodBankName;
                final bool isUrgent = (data['isUrgent'] == true);
                final Color stripeColor = isUrgent
                    ? const Color(0xffe53935)
                    : const Color(0xff00897b);
                final Color iconBg = isUrgent
                    ? const Color(0xffffebee)
                    : const Color(0xffe0f2f1);
                final IconData iconData = isUrgent
                    ? Icons.warning_amber_rounded
                    : Icons.notifications;

                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: InkWell(
                    onTap: () async =>
                        _openRequestFromNotification(doc.id, data),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 70,
                            decoration: BoxDecoration(
                              color: stripeColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: iconBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          iconData,
                                          size: 18,
                                          color: stripeColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          titleText,
                                          style: TextStyle(
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (subtitleText.isNotEmpty)
                                    Text(
                                      subtitleText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  if (createdAtText.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      createdAtText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black45,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request details'),
        backgroundColor: const Color(0xffe60012),
        foregroundColor: Colors.white,
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
          final details = request.details.trim();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xfffdfdfd),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xffe6e9f0)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                        fontSize: 15,
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
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                              const SizedBox(height: 6),
                              Text(
                                'Blood bank: ${request.bloodBankName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChatScreen()),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Messages'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffe60012),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
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
    );
  }
}
