import '../models/support_ticket_model.dart';
import '../services/support_service.dart';

/// Controller للتحكم في منطق قسم الدعم والشكاوي
class SupportController {
  final SupportService _service;

  SupportController({SupportService? service})
    : _service = service ?? SupportService();

  // ── إرسال تذكرة ────────────────────────────────────────────

  Future<String> submitTicket({
    required TicketType type,
    required String subject,
    required String message,
    required TicketSenderRole senderRole,
    String? senderName,
  }) async {
    if (subject.trim().isEmpty) {
      throw Exception('Please enter a subject.');
    }
    if (message.trim().length < 10) {
      throw Exception('Message must be at least 10 characters.');
    }
    return _service.submitTicket(
      type: type,
      subject: subject,
      message: message,
      senderRole: senderRole,
      senderName: senderName,
    );
  }

  // ── جلب تذاكر المستخدم ────────────────────────────────────

  Future<List<SupportTicket>> fetchMyTickets() => _service.fetchMyTickets();

  // ── جلب كل التذاكر (أدمن) ────────────────────────────────

  Future<List<SupportTicket>> fetchAllTickets({
    TicketStatus? filterStatus,
    TicketType? filterType,
  }) => _service.fetchAllTickets(
    filterStatus: filterStatus,
    filterType: filterType,
  );

  // ── رد الأدمن ─────────────────────────────────────────────

  Future<void> replyToTicket({
    required String ticketId,
    required String reply,
    required TicketStatus newStatus,
  }) async {
    if (reply.trim().isEmpty) throw Exception('Reply cannot be empty.');
    return _service.replyToTicket(
      ticketId: ticketId,
      reply: reply,
      newStatus: newStatus,
    );
  }

  Future<void> updateTicketStatus({
    required String ticketId,
    required TicketStatus status,
  }) => _service.updateTicketStatus(ticketId: ticketId, status: status);

  Future<void> deleteTicket(String ticketId) => _service.deleteTicket(ticketId);

  Future<int> countOpenTickets() => _service.countOpenTickets();
}
