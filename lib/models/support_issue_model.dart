/// Issue type: complaint or help request
enum IssueType { complaint, help }

/// Issue workflow status
enum IssueStatus { open, inProgress, resolved, closed }

/// Who submitted the issue
enum IssueSenderRole { donor, hospital }

/// Support / complaint issue model
class SupportIssue {
  final String id;
  final String senderId;
  final String senderEmail;
  final String? senderName;
  final IssueSenderRole senderRole;
  final IssueType type;
  final String subject;
  final String message;
  final IssueStatus status;
  final String? adminReply;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SupportIssue({
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

  factory SupportIssue.fromMap(Map<String, dynamic> data, String id) {
    return SupportIssue(
      id: id,
      senderId: data['senderId']?.toString() ?? '',
      senderEmail: data['senderEmail']?.toString() ?? '',
      senderName: data['senderName']?.toString(),
      senderRole: data['senderRole'] == 'hospital'
          ? IssueSenderRole.hospital
          : IssueSenderRole.donor,
      type: data['type'] == 'complaint'
          ? IssueType.complaint
          : IssueType.help,
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
      'senderRole': senderRole == IssueSenderRole.hospital
          ? 'hospital'
          : 'donor',
      'type': type == IssueType.complaint ? 'complaint' : 'help',
      'subject': subject,
      'message': message,
      'status': _statusToString(status),
      if (adminReply != null) 'adminReply': adminReply,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
    };
  }

  static IssueStatus _parseStatus(String? s) {
    switch (s) {
      case 'inProgress':
        return IssueStatus.inProgress;
      case 'resolved':
        return IssueStatus.resolved;
      case 'closed':
        return IssueStatus.closed;
      default:
        return IssueStatus.open;
    }
  }

  static String _statusToString(IssueStatus s) {
    switch (s) {
      case IssueStatus.inProgress:
        return 'inProgress';
      case IssueStatus.resolved:
        return 'resolved';
      case IssueStatus.closed:
        return 'closed';
      case IssueStatus.open:
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
