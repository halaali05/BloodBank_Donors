import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/models/support_issue_model.dart';

void main() {

  group('SupportIssue.fromMap', () {

    test('creates object correctly from full map',
        () {

      final now =
          DateTime.now().millisecondsSinceEpoch;

      final map = {
        'senderId': 'USER_1',
        'senderEmail': 'test@test.com',
        'senderName': 'Ahmad',
        'senderRole': 'hospital',
        'type': 'complaint',
        'subject': 'Subject',
        'message': 'Message',
        'status': 'resolved',
        'adminReply': 'Done',
        'createdAt': now,
        'updatedAt': now,
      };

      final issue =
          SupportIssue.fromMap(map, 'ISSUE_1');

      expect(issue.id, 'ISSUE_1');
      expect(issue.senderId, 'USER_1');
      expect(issue.senderEmail, 'test@test.com');
      expect(issue.senderName, 'Ahmad');

      expect(
        issue.senderRole,
        IssueSenderRole.hospital,
      );

      expect(
        issue.type,
        IssueType.complaint,
      );

      expect(
        issue.status,
        IssueStatus.resolved,
      );

      expect(issue.subject, 'Subject');
      expect(issue.message, 'Message');
      expect(issue.adminReply, 'Done');
    });

    test('uses fallback values for missing fields',
        () {

      final issue =
          SupportIssue.fromMap({}, 'ID');

      expect(issue.id, 'ID');
      expect(issue.senderId, '');
      expect(issue.senderEmail, '');
      expect(issue.subject, '');
      expect(issue.message, '');

      expect(
        issue.senderRole,
        IssueSenderRole.donor,
      );

      expect(
        issue.type,
        IssueType.help,
      );

      expect(
        issue.status,
        IssueStatus.open,
      );
    });

    test('parses inProgress status correctly',
        () {

      final issue =
          SupportIssue.fromMap({
        'status': 'inProgress',
      }, '1');

      expect(
        issue.status,
        IssueStatus.inProgress,
      );
    });

    test('parses closed status correctly',
        () {

      final issue =
          SupportIssue.fromMap({
        'status': 'closed',
      }, '1');

      expect(
        issue.status,
        IssueStatus.closed,
      );
    });

    test('parses Firestore timestamp map',
        () {

      final issue =
          SupportIssue.fromMap({
        'createdAt': {
          '_seconds': 1000,
        },
      }, '1');

      expect(
        issue.createdAt,
        DateTime.fromMillisecondsSinceEpoch(
          1000 * 1000,
        ),
      );
    });

    test('parses ISO string date',
        () {

      final issue =
          SupportIssue.fromMap({
        'createdAt': '2025-01-01T00:00:00.000',
      }, '1');

      expect(
        issue.createdAt.year,
        2025,
      );
    });

    test('parses DateTime directly',
        () {

      final date = DateTime.now();

      final issue =
          SupportIssue.fromMap({
        'createdAt': date,
      }, '1');

      expect(issue.createdAt, date);
    });

    test('defaults unknown status to open',
        () {

      final issue =
          SupportIssue.fromMap({
        'status': 'UNKNOWN',
      }, '1');

      expect(
        issue.status,
        IssueStatus.open,
      );
    });
  });

  group('toMap', () {

    test('converts object correctly',
        () {

      final issue = SupportIssue(
        id: '1',
        senderId: 'USER_1',
        senderEmail: 'test@test.com',
        senderName: 'Ahmad',
        senderRole: IssueSenderRole.hospital,
        type: IssueType.complaint,
        subject: 'Subject',
        message: 'Message',
        status: IssueStatus.resolved,
        adminReply: 'Done',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(
          1000,
        ),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(
          2000,
        ),
      );

      final map = issue.toMap();

      expect(map['senderId'], 'USER_1');
      expect(map['senderEmail'], 'test@test.com');
      expect(map['senderName'], 'Ahmad');

      expect(
        map['senderRole'],
        'hospital',
      );

      expect(
        map['type'],
        'complaint',
      );

      expect(
        map['status'],
        'resolved',
      );

      expect(map['adminReply'], 'Done');
      expect(map['subject'], 'Subject');
      expect(map['message'], 'Message');
    });

    test('omits nullable fields when null',
        () {

      final issue = SupportIssue(
        id: '1',
        senderId: 'USER_1',
        senderEmail: 'test@test.com',
        senderRole: IssueSenderRole.donor,
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        status: IssueStatus.open,
        createdAt: DateTime.now(),
      );

      final map = issue.toMap();

      expect(
        map.containsKey('senderName'),
        false,
      );

      expect(
        map.containsKey('adminReply'),
        false,
      );

      expect(
        map.containsKey('updatedAt'),
        false,
      );
    });

    test('converts donor role correctly',
        () {

      final issue = SupportIssue(
        id: '1',
        senderId: 'USER_1',
        senderEmail: 'test@test.com',
        senderRole: IssueSenderRole.donor,
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        status: IssueStatus.open,
        createdAt: DateTime.now(),
      );

      final map = issue.toMap();

      expect(
        map['senderRole'],
        'donor',
      );
    });

    test('converts help type correctly',
        () {

      final issue = SupportIssue(
        id: '1',
        senderId: 'USER_1',
        senderEmail: 'test@test.com',
        senderRole: IssueSenderRole.donor,
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        status: IssueStatus.open,
        createdAt: DateTime.now(),
      );

      final map = issue.toMap();

      expect(map['type'], 'help');
    });

    test('converts open status correctly',
        () {

      final issue = SupportIssue(
        id: '1',
        senderId: 'USER_1',
        senderEmail: 'test@test.com',
        senderRole: IssueSenderRole.donor,
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        status: IssueStatus.open,
        createdAt: DateTime.now(),
      );

      final map = issue.toMap();

      expect(map['status'], 'open');
    });

    test('converts inProgress status correctly',
        () {

      final issue = SupportIssue(
        id: '1',
        senderId: 'USER_1',
        senderEmail: 'test@test.com',
        senderRole: IssueSenderRole.donor,
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        status: IssueStatus.inProgress,
        createdAt: DateTime.now(),
      );

      final map = issue.toMap();

      expect(
        map['status'],
        'inProgress',
      );
    });

    test('converts closed status correctly',
        () {

      final issue = SupportIssue(
        id: '1',
        senderId: 'USER_1',
        senderEmail: 'test@test.com',
        senderRole: IssueSenderRole.donor,
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        status: IssueStatus.closed,
        createdAt: DateTime.now(),
      );

      final map = issue.toMap();

      expect(map['status'], 'closed');
    });
  });
}
