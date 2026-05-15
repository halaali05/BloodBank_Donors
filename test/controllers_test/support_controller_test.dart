
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bloodbank_donors/controllers/support_controller.dart';
import 'package:bloodbank_donors/models/support_issue_model.dart';
import 'package:bloodbank_donors/services/support_service.dart';


class MockSupportService extends Mock
    implements SupportService {}

void main() {
  late MockSupportService mockService;
  late SupportController controller;

  setUp(() {
    mockService = MockSupportService();

    controller = SupportController(
      service: mockService,
    );
  });

   setUpAll(() {
  registerFallbackValue(IssueType.help);
  registerFallbackValue(IssueStatus.open);
  registerFallbackValue(IssueSenderRole.donor);

  });

  group('submitIssue', () {

    test('calls service submitIssue correctly',
        () async {

      when(() => mockService.submitIssue(
            type: any(named: 'type'),
            subject: any(named: 'subject'),
            message: any(named: 'message'),
            senderRole: any(named: 'senderRole'),
            senderName: any(named: 'senderName'),
          )).thenAnswer((_) async => 'ISSUE_1');

      final result = await controller.submitIssue(
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        senderRole: IssueSenderRole.donor,
        senderName: 'Ahmad',
      );

      expect(result, 'ISSUE_1');

      verify(() => mockService.submitIssue(
            type: IssueType.help,
            subject: 'Subject',
            message: 'Message',
            senderRole: IssueSenderRole.donor,
            senderName: 'Ahmad',
          )).called(1);
    });
  });

  group('fetchMyIssues', () {

    test('returns issues from service', () async {

      final issues = [
        SupportIssue(
          id: '1',
          subject: 'Test',
          message: 'Message',
          type: IssueType.help,
          senderRole: IssueSenderRole.donor,
          status: IssueStatus.open,
          createdAt: DateTime.now(),
          senderEmail: 'donor@test.com',
          senderId: 'donor_123',
        ),
      ];

      when(() => mockService.fetchMyIssues())
          .thenAnswer((_) async => issues);

      final result = await controller.fetchMyIssues();

      expect(result.length, 1);
      expect(result.first.id, '1');

      verify(() => mockService.fetchMyIssues())
          .called(1);
    });
  });

  group('fetchAllIssues', () {

    test('passes filters correctly',
        () async {

      when(() => mockService.fetchAllIssues(
            filterStatus: any(named: 'filterStatus'),
            filterType: any(named: 'filterType'),
          )).thenAnswer((_) async => []);

      await controller.fetchAllIssues(
        filterStatus: IssueStatus.open,
        filterType: IssueType.help,
      );

      verify(() => mockService.fetchAllIssues(
            filterStatus: IssueStatus.open,
            filterType: IssueType.help,
          )).called(1);
    });

    test('works without filters',
        () async {

      when(() => mockService.fetchAllIssues(
            filterStatus: any(named: 'filterStatus'),
            filterType: any(named: 'filterType'),
          )).thenAnswer((_) async => []);

      await controller.fetchAllIssues();

      verify(() => mockService.fetchAllIssues(
            filterStatus: null,
            filterType: null,
          )).called(1);
    });
  });

  group('replyToIssue', () {

    test('calls service replyToIssue',
        () async {

      when(() => mockService.replyToIssue(
            issueId: any(named: 'issueId'),
            reply: any(named: 'reply'),
            newStatus: any(named: 'newStatus'),
          )).thenAnswer((_) async {});

      await controller.replyToIssue(
        issueId: 'ISSUE_1',
        reply: 'Reply text',
        newStatus: IssueStatus.closed,
      );

      verify(() => mockService.replyToIssue(
            issueId: 'ISSUE_1',
            reply: 'Reply text',
            newStatus: IssueStatus.closed,
          )).called(1);
    });
  });

  group('updateIssueStatus', () {

    test('calls service updateIssueStatus',
        () async {

      when(() => mockService.updateIssueStatus(
            issueId: any(named: 'issueId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async {});

      await controller.updateIssueStatus(
        issueId: 'ISSUE_1',
        status: IssueStatus.closed,
      );

      verify(() => mockService.updateIssueStatus(
            issueId: 'ISSUE_1',
            status: IssueStatus.closed,
          )).called(1);
    });
  });

  group('deleteIssue', () {

    test('calls service deleteIssue',
        () async {

      when(() => mockService.deleteIssue(any()))
          .thenAnswer((_) async {});

      await controller.deleteIssue('ISSUE_1');

      verify(() => mockService.deleteIssue('ISSUE_1'))
          .called(1);
    });
  });

  group('countOpenIssues', () {

    test('returns count from service',
        () async {

      when(() => mockService.countOpenIssues())
          .thenAnswer((_) async => 5);

      final result =
          await controller.countOpenIssues();

      expect(result, 5);

      verify(() => mockService.countOpenIssues())
          .called(1);
    });
  });
}
