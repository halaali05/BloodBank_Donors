import 'package:cloud_functions/cloud_functions.dart';
import '../models/support_ticket_model.dart';

/// خدمة الدعم والشكاوي — تستدعي Cloud Functions بشكل آمن
class SupportService {
  final FirebaseFunctions _functions;

  SupportService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String> submitTicket({
    required TicketType type,
    required String subject,
    required String message,
    required TicketSenderRole senderRole,
    String? senderName,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitSupportTicket');
      final result = await callable.call({
        'type': type == TicketType.complaint ? 'complaint' : 'help',
        'subject': subject.trim(),
        'message': message.trim(),
        'senderRole': senderRole == TicketSenderRole.hospital
            ? 'hospital'
            : 'donor',
        if (senderName != null && senderName.trim().isNotEmpty)
          'senderName': senderName.trim(),
      });
      final data = Map<String, dynamic>.from(result.data);
      return data['ticketId']?.toString() ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to submit ticket.');
    }
  }

  Future<List<SupportTicket>> fetchMyTickets() async {
    try {
      final callable = _functions.httpsCallable('getMyTickets');
      final result = await callable.call({});
      final data = Map<String, dynamic>.from(result.data);
      final raw = data['tickets'];
      if (raw is! List) return [];
      return raw.whereType<Map>().map((d) {
        final m = Map<String, dynamic>.from(d);
        return SupportTicket.fromMap(m, m['id']?.toString() ?? '');
      }).toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to load tickets.');
    }
  }

  Future<List<SupportTicket>> fetchAllTickets({
    TicketStatus? filterStatus,
    TicketType? filterType,
  }) async {
    try {
      final callable = _functions.httpsCallable('getAllTickets');
      final result = await callable.call({
        if (filterStatus != null) 'status': _statusString(filterStatus),
        if (filterType != null)
          'type': filterType == TicketType.complaint ? 'complaint' : 'help',
      });
      final data = Map<String, dynamic>.from(result.data);
      final raw = data['tickets'];
      if (raw is! List) return [];
      return raw.whereType<Map>().map((d) {
        final m = Map<String, dynamic>.from(d);
        return SupportTicket.fromMap(m, m['id']?.toString() ?? '');
      }).toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to load tickets.');
    }
  }

  Future<void> replyToTicket({
    required String ticketId,
    required String reply,
    required TicketStatus newStatus,
  }) async {
    try {
      final callable = _functions.httpsCallable('replySupportTicket');
      await callable.call({
        'ticketId': ticketId,
        'reply': reply.trim(),
        'status': _statusString(newStatus),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to send reply.');
    }
  }

  Future<void> updateTicketStatus({
    required String ticketId,
    required TicketStatus status,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateTicketStatus');
      await callable.call({
        'ticketId': ticketId,
        'status': _statusString(status),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to update status.');
    }
  }

  Future<void> deleteTicket(String ticketId) async {
    try {
      final callable = _functions.httpsCallable('deleteSupportTicket');
      await callable.call({'ticketId': ticketId});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to delete ticket.');
    }
  }

  Future<int> countOpenTickets() async {
    try {
      final callable = _functions.httpsCallable('countOpenTickets');
      final result = await callable.call({});
      final data = Map<String, dynamic>.from(result.data);
      final count = data['count'];
      if (count is int) return count;
      if (count is num) return count.toInt();
      return 0;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to count tickets.');
    }
  }

  static String _statusString(TicketStatus s) {
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
}
