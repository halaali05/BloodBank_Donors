/// نوع التذكرة: شكوى أو طلب مساعدة
enum TicketType { complaint, help }

/// حالة التذكرة
enum TicketStatus { open, inProgress, resolved, closed }

/// من هو المرسل
enum TicketSenderRole { donor, hospital }

/// نموذج تذكرة الدعم والشكاوي
class SupportTicket {
  final String id;
  final String senderId;
  final String senderEmail;
  final String? senderName; // اسم المتبرع أو اسم البنك
  final TicketSenderRole senderRole;
  final TicketType type;
  final String subject;
  final String message;
  final TicketStatus status;
  final String? adminReply;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SupportTicket({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    this.senderName,
    required this.senderRole,
    required this.type,
    required this.subject,
    required this.message,
    required this.status,
    this.adminReply,
    required this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> data, String id) {
    return SupportTicket(
      id: id,
      senderId: data['senderId']?.toString() ?? '',
      senderEmail: data['senderEmail']?.toString() ?? '',
      senderName: data['senderName']?.toString(),
      senderRole: data['senderRole'] == 'hospital'
          ? TicketSenderRole.hospital
          : TicketSenderRole.donor,
      type: data['type'] == 'complaint'
          ? TicketType.complaint
          : TicketType.help,
      subject: data['subject']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      status: _parseStatus(data['status']?.toString()),
      adminReply: data['adminReply']?.toString(),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      if (senderName != null) 'senderName': senderName,
      'senderRole': senderRole == TicketSenderRole.hospital
          ? 'hospital'
          : 'donor',
      'type': type == TicketType.complaint ? 'complaint' : 'help',
      'subject': subject,
      'message': message,
      'status': _statusToString(status),
      if (adminReply != null) 'adminReply': adminReply,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
    };
  }

  static TicketStatus _parseStatus(String? s) {
    switch (s) {
      case 'inProgress':
        return TicketStatus.inProgress;
      case 'resolved':
        return TicketStatus.resolved;
      case 'closed':
        return TicketStatus.closed;
      default:
        return TicketStatus.open;
    }
  }

  static String _statusToString(TicketStatus s) {
    switch (s) {
      case TicketStatus.inProgress:
        return 'inProgress';
      case TicketStatus.resolved:
        return 'resolved';
      case TicketStatus.closed:
        return 'closed';
      case TicketStatus.open:
        return 'open';
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    if (v is Map && v.containsKey('_seconds')) {
      final seconds = v['_seconds'];
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return null;
  }
}
