import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:bloodbank_donors/services/notification_service.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late NotificationService service;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    service = NotificationService.test(fakeDb);
  });
              ///TEST CASES///
              
          /// CREATE NOTIFICATION ///
  test('createNotification adds notification to Firestore', () async {
    await service.createNotification(
      userId: 'user123',
      requestId: 'req001',
      title: 'Urgent Need',
      body: 'We need A+ blood ASAP',
    );

    final snapshot = await fakeDb.collection('notifications').get();
    expect(snapshot.docs.length, 1);

    final data = snapshot.docs.first.data();

    expect(data['userId'], 'user123');
    expect(data['requestId'], 'req001');
    expect(data['title'], 'Urgent Need');
    expect(data['body'], 'We need A+ blood ASAP');
    expect(data['isRead'], false);
  });

                /// MARK AS READ  ///
  test('markAsRead updates notification to isRead = true', () async {
  
    final doc = await fakeDb.collection('notifications').add({
      'userId': 'user1',
      'requestId': 'req1',
      'title': 'Hello',
      'body': 'Test body',
      'isRead': false,
      'createdAt': null,
    });

    await service.markAsRead(doc.id);

    final updated = await fakeDb.collection('notifications').doc(doc.id).get();
    expect(updated.data()?['isRead'], true);
  });

        ///multiple notifications///
test('multiple notifications can be added', () async {
      final fakeDb = FakeFirebaseFirestore();
      final service = NotificationService.test(fakeDb);

      await service.createNotification(
        userId: 'u1',
        requestId: 'r1',
        title: 'A',
        body: 'B',
      );

      await service.createNotification(
        userId: 'u2',
        requestId: 'r2',
        title: 'C',
        body: 'D',
      );

      final snapshot = await fakeDb.collection('notifications').get();
      expect(snapshot.docs.length, 2);
    });

}
