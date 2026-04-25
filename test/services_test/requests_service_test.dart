import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bloodbank_donors/services/requests_service.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';

/// ---------------- MOCKS ----------------

class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

void main() {
  late MockCloudFunctionsService mockCloud;
  late RequestsService service;
  
  setUp(() {
    mockCloud = MockCloudFunctionsService();

    service = RequestsService.test(cloudFunctions: mockCloud);
  });

 /// addRequest
 
group('addRequest', () {
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

    when(
      () => mockCloud.addRequest(
        requestId: any(named: 'requestId'),
        bloodBankName: any(named: 'bloodBankName'),
        bloodType: any(named: 'bloodType'),
        units: any(named: 'units'),
        isUrgent: any(named: 'isUrgent'),
        details: any(named: 'details'),
        hospitalLocation: any(named: 'hospitalLocation'),
      ),
    ).thenAnswer((_) async => <String, dynamic>{});

    await service.addRequest(request);

    verify(
      () => mockCloud.addRequest(
        requestId: 'req001',
        bloodBankName: 'Jordan Hospital',
        bloodType: 'A+',
        units: 3,
        isUrgent: true,
        details: 'Emergency case',
        hospitalLocation: 'Amman',
      ),
    ).called(1);
  });

test('addRequest passes latitude and longitude when provided', () async {
  final request = BloodRequest(
    id: 'req002',
    bloodBankId: 'bank1',
    bloodBankName: 'Bank',
    bloodType: 'B+',
    units: 1,
    isUrgent: false,
    details: '', 
    hospitalLocation: 'Amman',
    hospitalLatitude: 31.95,
    hospitalLongitude: 35.91,
  );

  when(() => mockCloud.addRequest(
        requestId: any(named: 'requestId'),
        bloodBankName: any(named: 'bloodBankName'),
        bloodType: any(named: 'bloodType'),
        units: any(named: 'units'),
        isUrgent: any(named: 'isUrgent'),
        details: any(named: 'details'),
        hospitalLocation: any(named: 'hospitalLocation'),
        hospitalLatitude: any(named: 'hospitalLatitude'),
        hospitalLongitude: any(named: 'hospitalLongitude'),
      )).thenAnswer((_) async => {});

  await service.addRequest(request);

  verify(() => mockCloud.addRequest(
        requestId: 'req002',
        bloodBankName: 'Bank',
        bloodType: 'B+',
        units: 1,
        isUrgent: false,
        details: '',
        hospitalLocation: 'Amman',
        hospitalLatitude: 31.95,
        hospitalLongitude: 35.91,
      )).called(1);
});

});
  

  /// getRequests
  
group('getRequests', () {
  test('getRequests handles createdAt milliseconds safely', () async {
    when(
      () => mockCloud.getRequests(
        limit: any(named: 'limit'),
        lastRequestId: any(named: 'lastRequestId'),
      ),
    ).thenAnswer(
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
          },
        ],
        'hasMore': false,
      },
    );

    final result = await service.getRequests();

    expect(result['requests'], isA<List<BloodRequest>>());
    expect(result['requests'].length, 1);
    expect((result['requests'] as List).first.bloodType, 'O+');
  });

test('getRequests maps multiple requests correctly', () async {
  when(() => mockCloud.getRequests(
        limit: any(named: 'limit'),
        lastRequestId: any(named: 'lastRequestId'),
      )).thenAnswer((_) async => {
            'requests': [
              {
                'id': 'r1',
                'bloodType': 'A+',
                'units': 1,
                'isUrgent': false,
              },
              {
                'id': 'r2',
                'bloodType': 'B+',
                'units': 2,
                'isUrgent': true,
              },
            ],
            'hasMore': true,
          });

  final result = await service.getRequests();

  expect(result['requests'].length, 2);
  expect(result['hasMore'], true);
});

test('getRequests handles empty list', () async {
  when(() => mockCloud.getRequests(
        limit: any(named: 'limit'),
        lastRequestId: any(named: 'lastRequestId'),
      )).thenAnswer((_) async => {
            'requests': [],
            'hasMore': false,
          });

  final result = await service.getRequests();

  expect(result['requests'], isEmpty);
  expect(result['hasMore'], false);
});

test('getRequests handles null createdAt', () async {
  when(() => mockCloud.getRequests(
        limit: any(named: 'limit'),
        lastRequestId: any(named: 'lastRequestId'),
      )).thenAnswer((_) async => {
            'requests': [
              {
                'id': 'r1',
                'bloodType': 'A+',
                'units': 1,
                'isUrgent': false,
                'createdAt': null,
              },
            ],
            'hasMore': false,
          });

  final result = await service.getRequests();

  expect(result['requests'], isA<List<BloodRequest>>());
});

test('getRequests passes lastRequestId correctly', () async {
  when(() => mockCloud.getRequests(
        limit: any(named: 'limit'),
        lastRequestId: any(named: 'lastRequestId'),
      )).thenAnswer((invocation) async {
    expect(invocation.namedArguments[#lastRequestId], 'last123');
    return {'requests': [], 'hasMore': false};
  });

  await service.getRequests(lastRequestId: 'last123');
});

test('getRequestById maps data correctly', () async {
  when(() => mockCloud.getRequestById(requestId: any(named: 'requestId')))
      .thenAnswer((_) async => {
            'request': {
              'id': 'req1',
              'bloodType': 'O+',
              'units': 2,
              'isUrgent': true,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            }
          });

  final result = await service.getRequestById('req1');

  expect(result.id, 'req1');
  expect(result.bloodType, 'O+');
});

test('getRequestById handles null createdAt', () async {
  when(() => mockCloud.getRequestById(requestId: any(named: 'requestId')))
      .thenAnswer((_) async => {
            'request': {
              'id': 'req1',
              'bloodType': 'O+',
              'units': 2,
              'isUrgent': true,
              'createdAt': null,
            }
          });

  final result = await service.getRequestById('req1');

  expect(result, isA<BloodRequest>());
});
test('getRequests rethrows when cloud function fails', () async {
  when(() => mockCloud.getRequests(
        limit: any(named: 'limit'),
        lastRequestId: any(named: 'lastRequestId'),
      )).thenThrow(Exception('fail'));

  expect(() => service.getRequests(), throwsException);
}); 
});

}
