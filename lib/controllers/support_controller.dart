import '../models/support_issue_model.dart';
import '../services/support_service.dart';

class SupportController {
  final SupportService _service;

  SupportController({SupportService? service})
      : _service = service ?? SupportService();

  Future<String> submitIssue({
    required IssueType type,
    required String subject,
    required String message,
    required IssueSenderRole senderRole,
    String? senderName,
  }) {
    return _service.submitIssue(
      type: type,
      subject: subject,
      message: message,
      senderRole: senderRole,
      senderName: senderName,
    );
  }

  Future<List<SupportIssue>> fetchMyIssues() => _service.fetchMyIssues();

  Future<List<SupportIssue>> fetchAllIssues({
    IssueStatus? filterStatus,
    IssueType? filterType,
  }) =>
      _service.fetchAllIssues(filterStatus: filterStatus, filterType: filterType);

  Future<void> replyToIssue({
    required String issueId,
    required String reply,
    required IssueStatus newStatus,
  }) {
    return _service.replyToIssue(
      issueId: issueId,
      reply: reply,
      newStatus: newStatus,
    );
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required IssueStatus status,
  }) => _service.updateIssueStatus(issueId: issueId, status: status);

  Future<void> deleteIssue(String issueId) => _service.deleteIssue(issueId);

  Future<int> countOpenIssues() => _service.countOpenIssues();
}
