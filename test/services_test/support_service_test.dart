
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bloodbank_donors/models/support_issue_model.dart';
import 'package:bloodbank_donors/services/support_service.dart';

class MockFirebaseFunctions extends Mock
    implements FirebaseFunctions {}

class MockHttpsCallable extends Mock
    implements HttpsCallable {}

class MockHttpsCallableResult extends Mock
    implements HttpsCallableResult {}

void main() {
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;

  late SupportService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();

    service = SupportService(
      functions: mockFunctions,
    );
  });

  group('submitIssue', () {

    test('submits complaint correctly',
        () async {

      when(() => mockFunctions.httpsCallable(
            'submitSupportIssue',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'issueId': 'ISSUE_1',
      });

      final result = await service.submitIssue(
        type: IssueType.complaint,
        subject: ' Subject ',
        message: ' Message ',
        senderRole: IssueSenderRole.hospital,
        senderName: ' Ahmad ',
      );

      expect(result, 'ISSUE_1');

      verify(() => mockCallable.call({
            'type': 'complaint',
            'subject': 'Subject',
            'message': 'Message',
            'senderRole': 'hospital',
            'senderName': 'Ahmad',
          })).called(1);
    });

    test('returns ticketId fallback',
        () async {

      when(() => mockFunctions.httpsCallable(
            'submitSupportIssue',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'ticketId': 'TICKET_1',
      });

      final result = await service.submitIssue(
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        senderRole: IssueSenderRole.donor,
      );

      expect(result, 'TICKET_1');
    });

    test('returns empty string if ids missing',
        () async {

      when(() => mockFunctions.httpsCallable(
            'submitSupportIssue',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({});

      final result = await service.submitIssue(
        type: IssueType.help,
        subject: 'Subject',
        message: 'Message',
        senderRole: IssueSenderRole.donor,
      );

      expect(result, '');
    });

    test('throws firebase exception message',
        () async {

      when(() => mockFunctions.httpsCallable(
            'submitSupportIssue',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenThrow(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Denied',
        ),
      );

      expect(
        () => service.submitIssue(
          type: IssueType.help,
          subject: 'Subject',
          message: 'Message',
          senderRole: IssueSenderRole.donor,
        ),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('Denied'),
          ),
        ),
      );
    });
  });

  group('fetchMyIssues', () {

    test('returns parsed issues',
        () async {

      when(() => mockFunctions.httpsCallable(
            'getMyIssues',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'issues': [
          {
            'id': '1',
            'senderId': 'U1',
            'senderEmail': 'a@test.com',
            'senderRole': 'donor',
            'type': 'help',
            'subject': 'Subject',
            'message': 'Message',
            'status': 'open',
            'createdAt':
                DateTime.now().millisecondsSinceEpoch,
          }
        ],
      });

      final result =
          await service.fetchMyIssues();

      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('supports tickets payload',
        () async {

      when(() => mockFunctions.httpsCallable(
            'getMyIssues',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'tickets': [],
      });

      final result =
          await service.fetchMyIssues();

      expect(result, isEmpty);
    });

    test('returns empty when payload invalid',
        () async {

      when(() => mockFunctions.httpsCallable(
            'getMyIssues',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'issues': 'INVALID',
      });

      final result =
          await service.fetchMyIssues();

      expect(result, isEmpty);
    });
  });

  group('fetchAllIssues', () {

    test('passes filters correctly',
        () async {

      when(() => mockFunctions.httpsCallable(
            'getAllIssues',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'issues': [],
      });

      await service.fetchAllIssues(
        filterStatus: IssueStatus.closed,
        filterType: IssueType.complaint,
      );

      verify(() => mockCallable.call({
            'status': 'closed',
            'type': 'complaint',
          })).called(1);
    });

    test('works without filters',
        () async {

      when(() => mockFunctions.httpsCallable(
            'getAllIssues',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'issues': [],
      });

      await service.fetchAllIssues();

      verify(() => mockCallable.call({}))
          .called(1);
    });
  });

  group('replyToIssue', () {

    test('sends reply correctly',
        () async {

      when(() => mockFunctions.httpsCallable(
            'replySupportIssue',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      await service.replyToIssue(
        issueId: '1',
        reply: ' Reply ',
        newStatus: IssueStatus.resolved,
      );

      verify(() => mockCallable.call({
            'issueId': '1',
            'reply': 'Reply',
            'status': 'resolved',
          })).called(1);
    });
  });

  group('updateIssueStatus', () {

    test('updates status correctly',
        () async {

      when(() => mockFunctions.httpsCallable(
            'updateIssueStatus',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      await service.updateIssueStatus(
        issueId: '1',
        status: IssueStatus.inProgress,
      );

      verify(() => mockCallable.call({
            'issueId': '1',
            'status': 'inProgress',
          })).called(1);
    });
  });

  group('deleteIssue', () {

    test('deletes issue correctly',
        () async {

      when(() => mockFunctions.httpsCallable(
            'deleteSupportIssue',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      await service.deleteIssue('1');

      verify(() => mockCallable.call({
            'issueId': '1',
          })).called(1);
    });
  });

  group('countOpenIssues', () {

    test('returns int count',
        () async {

      when(() => mockFunctions.httpsCallable(
            'countOpenIssues',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'count': 5,
      });

      final result =
          await service.countOpenIssues();

      expect(result, 5);
    });

    test('converts num to int',
        () async {

      when(() => mockFunctions.httpsCallable(
            'countOpenIssues',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'count': 5.7,
      });

      final result =
          await service.countOpenIssues();

      expect(result, 5);
    });

    test('returns zero for invalid count',
        () async {

      when(() => mockFunctions.httpsCallable(
            'countOpenIssues',
          )).thenReturn(mockCallable);

      when(() => mockCallable.call(any()))
          .thenAnswer((_) async => mockResult);

      when(() => mockResult.data)
          .thenReturn({
        'count': 'invalid',
      });

      final result =
          await service.countOpenIssues();

      expect(result, 0);
    });
  });
}
