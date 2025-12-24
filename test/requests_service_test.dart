import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:bloodbank_donors/services/requests_service.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late RequestsService service;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();

    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: "bank123"),
    );

    service = RequestsService.test(fakeDb, mockAuth);
  });

  
              /// TEST CASES ///
               
               
    ///  addRequest adds correctly to Firestore
  
    test('addRequest stores blood request in Firestore', () async {
    final request = BloodRequest(
      id: "req001",
      bloodBankId: "bank123",
      bloodBankName: "Jordan Hospital",
      bloodType: "A+",
      units: 4,
      isUrgent: false,
      details: "Emergency",
      hospitalLocation: "Amman",
    );

    await service.addRequest(request);

    final doc =await fakeDb.collection('requests').doc("req001").get();

    expect(doc.exists, true);
    expect(doc.data()!['bloodBankName'], "Jordan Hospital");
    expect(doc.data()!['bloodType'], "A+");
    expect(doc.data()!['units'], 4);
  });

  
            /// urgent request creates notifications///
  
  test('urgent request sends notifications to donors', () async {
    
    await fakeDb.collection('users').doc("d1").set({
      'role': 'donor',
      'email': 'd1@test.com'
    });

    await fakeDb.collection('users').doc("d2").set({
      'role': 'donor',
      'email': 'd2@test.com'
    });

    final request = BloodRequest(
      id: "req002",
      bloodBankId: "bank123",
      bloodBankName: "Irbid Hospital",
      bloodType: "O-",
      units: 3,
      isUrgent: true,
      details: "Urgent case",
      hospitalLocation: "Irbid",
    );

    await service.addRequest(request);

    final notif1 = await fakeDb.collection('notifications').doc("d1").collection('user_notifications').get();

    final notif2 = await fakeDb.collection('notifications').doc("d2").collection('user_notifications').get();

    expect(notif1.docs.length, 1);
    expect(notif2.docs.length, 1);
  });

  
       /// getRequestsStream returns stream correctly ///
  
    test('getRequestsStream returns list of BloodRequest', () async {
    await fakeDb.collection('requests').doc("r1").set({
      'bloodBankId': 'bank123',
      'bloodBankName': 'City Bank',
      'bloodType': 'B+',
      'units': 2,
      'isUrgent': false,
      'details': 'Normal',
      'hospitalLocation': 'Zarqa',
      'createdAt': DateTime.now(),
    });

    final stream = service.getRequestsStream();

    final result = await stream.first;

    expect(result.length, 1);
    expect(result.first.bloodType, "B+");
  });
}
