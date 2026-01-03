import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/services/requests_service.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';

/// ---------------- MOCKS ----------------

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late MockFirebaseFirestore mockDb;
  late MockCollectionReference mockCollection;
  late MockCloudFunctionsService mockCloud;
  late MockFirebaseAuth mockAuth;
  late RequestsService service;

  setUp(() {
    mockDb = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockCloud = MockCloudFunctionsService();
    mockAuth = MockFirebaseAuth();

    // Firestore -> collection('requests')
    when(() => mockDb.collection('requests'))
        .thenReturn(mockCollection);

    service = RequestsService.test(
      mockDb,
      mockAuth,
      mockCloud,
    );
  });

  /// ----------------------------------------------------
  /// addRequest
  /// ----------------------------------------------------

  test('addRequest calls CloudFunctionsService with correct data', () async {
    final request = BloodRequest(
      id: 'req001',
      bloodBankId: 'bank123',
      bloodBankName: 'Jordan Hospital',
      bloodType: 'A+',
      units: 3,
      isUrgent: true,
      details: 'Emergency case',
      hospitalLocation: 'Amman',
    );

    when(() => mockCloud.addRequest(
          requestId: any(named: 'requestId'),
          bloodBankName: any(named: 'bloodBankName'),
          bloodType: any(named: 'bloodType'),
          units: any(named: 'units'),
          isUrgent: any(named: 'isUrgent'),
          details: any(named: 'details'),
          hospitalLocation: any(named: 'hospitalLocation'),
        )).thenAnswer((_) async => <String, dynamic>{});

    await service.addRequest(request);

    verify(() => mockCloud.addRequest(
          requestId: 'req001',
          bloodBankName: 'Jordan Hospital',
          bloodType: 'A+',
          units: 3,
          isUrgent: true,
          details: 'Emergency case',
          hospitalLocation: 'Amman',
        )).called(1);
  });

  /// ----------------------------------------------------
  /// getRequestsStream
  /// ----------------------------------------------------

  test('getRequestsStream returns list of BloodRequest', () async {
    final mockSnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(() => mockCollection.orderBy('createdAt', descending: true))
        .thenReturn(mockCollection);

    when(() => mockCollection.snapshots())
        .thenAnswer((_) => Stream.value(mockSnapshot));

    when(() => mockSnapshot.docs).thenReturn([mockDoc]);

    when(() => mockDoc.id).thenReturn('req123');

    when(() => mockDoc.data()).thenReturn({
      'bloodBankId': 'bank1',
      'bloodBankName': 'City Bank',
      'bloodType': 'O-',
      'units': 2,
      'isUrgent': false,
      'details': 'Normal case',
      'hospitalLocation': 'Zarqa',
      'createdAt': DateTime.now(),
    });

    final result = await service.getRequestsStream().first;

    expect(result.length, 1);
    expect(result.first.id, 'req123');
    expect(result.first.bloodType, 'O-');
    expect(result.first.units, 2);
  });

  /// ----------------------------------------------------
  /// getRequestsStream
  /// ----------------------------------------------------

test('getRequests handles createdAt milliseconds safely', () async {
  final mockCloud = MockCloudFunctionsService();

  final service = RequestsService.test(
    FakeFirebaseFirestore(),
    MockFirebaseAuth(),
    mockCloud,
  );

  when(() => mockCloud.getRequests(
        limit: any(named: 'limit'),
        lastRequestId: any(named: 'lastRequestId'),
      )).thenAnswer(
    (_) async => {
      'requests': [
        {
          'id': 'req100',
          'bloodBankName': 'Test Bank',
          'bloodType': 'O+',
          'units': 2,
          'isUrgent': false,
          'details': '',
          'hospitalLocation': 'Amman',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        }
      ],
      'hasMore': false,
    },
  );

  final result = await service.getRequests();

  expect(result['requests'], isA<List<BloodRequest>>());
  expect(result['requests'].length, 1);
  expect((result['requests'] as List).first.bloodType, 'O+');
});


}
