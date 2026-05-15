import 'package:cloud_functions/cloud_functions.dart';

import '../models/support_issue_model.dart';

/// خدمة الدعم والشكاوى — تستدعي Cloud Functions بشكل آمن
class SupportService {
  final FirebaseFunctions _functions;

  SupportService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  List<Map<String, dynamic>> _issuesPayload(Map<String, dynamic> data) {
    final raw = data['issues'] ?? data['tickets'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  String _parseSubmittedId(Map<String, dynamic> data) {
    final a = data['issueId']?.toString().trim();
    final b = data['ticketId']?.toString().trim();
    if (a != null && a.isNotEmpty) return a;
    if (b != null && b.isNotEmpty) return b;
    return '';
  }

  Future<String> submitIssue({
    required IssueType type,
    required String subject,
    required String message,
    required IssueSenderRole senderRole,
    String? senderName,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitSupportIssue');
      final result = await callable.call({
        'type': type == IssueType.complaint ? 'complaint' : 'help',
        'subject': subject.trim(),
        'message': message.trim(),
        'senderRole': senderRole == IssueSenderRole.hospital
            ? 'hospital'
            : 'donor',
        if (senderName != null && senderName.trim().isNotEmpty)
          'senderName': senderName.trim(),
      });
      final data = Map<String, dynamic>.from(result.data);
      return _parseSubmittedId(data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to submit issue.');
    }
  }

  Future<List<SupportIssue>> fetchMyIssues() async {
    try {
      final callable = _functions.httpsCallable('getMyIssues');
      final result = await callable.call({});
      final data = Map<String, dynamic>.from(result.data);
      return _issuesPayload(data).map((d) {
        return SupportIssue.fromMap(d, d['id']?.toString() ?? '');
      }).toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to load issues.');
    }
  }

  Future<List<SupportIssue>> fetchAllIssues({
    IssueStatus? filterStatus,
    IssueType? filterType,
  }) async {
    try {
      final callable = _functions.httpsCallable('getAllIssues');
      final result = await callable.call({
        if (filterStatus != null) 'status': _statusString(filterStatus),
        if (filterType != null)
          'type': filterType == IssueType.complaint ? 'complaint' : 'help',
      });
      final data = Map<String, dynamic>.from(result.data);
      return _issuesPayload(data).map((d) {
        return SupportIssue.fromMap(d, d['id']?.toString() ?? '');
      }).toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to load issues.');
    }
  }

  Future<void> replyToIssue({
    required String issueId,
    required String reply,
    required IssueStatus newStatus,
  }) async {
    try {
      final callable = _functions.httpsCallable('replySupportIssue');
      await callable.call({
        'issueId': issueId,
        'reply': reply.trim(),
        'status': _statusString(newStatus),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to send reply.');
    }
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required IssueStatus status,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateIssueStatus');
      await callable.call({
        'issueId': issueId,
        'status': _statusString(status),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to update status.');
    }
  }

  Future<void> deleteIssue(String issueId) async {
    try {
      final callable = _functions.httpsCallable('deleteSupportIssue');
      await callable.call({'issueId': issueId});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to delete issue.');
    }
  }

  Future<int> countOpenIssues() async {
    try {
      final callable = _functions.httpsCallable('countOpenIssues');
      final result = await callable.call({});
      final data = Map<String, dynamic>.from(result.data);
      final count = data['count'];
      if (count is int) return count;
      if (count is num) return count.toInt();
      return 0;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to count open issues.');
    }
  }

  static String _statusString(IssueStatus s) {
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
}
