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

  /// ----------------------------------------------------
  /// getRequests
  /// ----------------------------------------------------

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
}
