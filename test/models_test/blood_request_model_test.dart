import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';

void main() {
  group('BloodRequest Model Tests', () {

    ///creates BloodRequest correctly
    test('fromMap creates BloodRequest correctly', () {
      final data = {
        'bloodBankId': 'bank123',
        'bloodBankName': 'Jordan Hospital Bank',
        'bloodType': 'A+',
        'units': 4,
        'isUrgent': true,
        'details': 'Emergency surgery',
        'hospitalLocation': 'Amman',
      };

      final request = BloodRequest.fromMap(data, 'req001');

      expect(request.id, 'req001');
      expect(request.bloodBankId, 'bank123');
      expect(request.bloodBankName, 'Jordan Hospital Bank');
      expect(request.bloodType, 'A+');
      expect(request.units, 4);
      expect(request.isUrgent, true);
      expect(request.details, 'Emergency surgery');
      expect(request.hospitalLocation, 'Amman');
      expect(request.acceptedCount, 0);
      expect(request.rejectedCount, 0);
      expect(request.myResponse, isNull);
      expect(request.acceptedDonors, isEmpty);
      expect(request.rejectedDonors, isEmpty);
    });

    test('fromMap parses acceptedDonors and rejectedDonors', () {
      final request = BloodRequest.fromMap({
        'bloodBankId': 'b',
        'bloodBankName': 'Bank',
        'bloodType': 'A+',
        'units': 1,
        'isUrgent': false,
        'acceptedDonors': [
          {
            'donorId': 'd1',
            'fullName': 'Ali',
            'email': 'a@x.com',
            'phoneNumber': '+962791234567',
          },
        ],
        'rejectedDonors': [
          {'donorId': 'd2', 'fullName': 'Sara', 'email': 's@x.com'},
        ],
      }, 'r1');

      expect(request.acceptedDonors.length, 1);
      expect(request.acceptedDonors.first.fullName, 'Ali');
      expect(request.acceptedDonors.first.phoneNumber, '+962791234567');
      expect(request.rejectedDonors.length, 1);
      expect(request.rejectedDonors.first.email, 's@x.com');
      expect(request.rejectedDonors.first.phoneNumber, isEmpty);
    });

    test('fromMap parses donor entries using displayName and dynamic-key maps', () {
      final rawList = <dynamic>[
        <Object?, Object?>{
          'donorId': 'd1',
          'displayName': 'From Auth',
          'email': 'auth@x.com',
        },
      ];
      final request = BloodRequest.fromMap({
        'bloodBankId': 'b',
        'bloodBankName': 'Bank',
        'bloodType': 'A+',
        'units': 1,
        'isUrgent': false,
        'acceptedDonors': rawList,
      }, 'r1');

      expect(request.acceptedDonors.length, 1);
      expect(request.acceptedDonors.first.fullName, 'From Auth');
      expect(request.acceptedDonors.first.email, 'auth@x.com');
    });

    test('fromMap parses counts and myResponse', () {
      final request = BloodRequest.fromMap({
        'bloodBankId': 'b',
        'bloodBankName': 'Bank',
        'bloodType': 'A+',
        'units': 1,
        'isUrgent': false,
        'acceptedCount': 5,
        'rejectedCount': 2,
        'myResponse': 'accepted',
      }, 'r1');

      expect(request.acceptedCount, 5);
      expect(request.rejectedCount, 2);
      expect(request.myResponse, 'accepted');
    });

    ///returns correct map structure
    test('toMap returns correct map structure', () {
      final request = BloodRequest(
        id: 'req010',
        bloodBankId: 'bank500',
        bloodBankName: 'City Blood Center',
        bloodType: 'B-',
        units: 3,
        isUrgent: true,
        details: 'Critical case',
        hospitalLocation: 'Zarqa',
      );

      final map = request.toMap();

      expect(map['bloodBankId'], 'bank500');
      expect(map['bloodBankName'], 'City Blood Center');
      expect(map['bloodType'], 'B-');
      expect(map['units'], 3);
      expect(map['isUrgent'], true);
      expect(map['details'], 'Critical case');
      expect(map['hospitalLocation'], 'Zarqa');
    });
    
    test('units defaults to 1', () {
  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': 0,
    'isUrgent': false,
  }, 'r1');

  expect(request.units, 1);
});

  test('parses units from string', () {
  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': '5',
    'isUrgent': false,
  }, 'r1');

  expect(request.units, 5);
});

  test('parses isUrgent from string', () {
  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': 1,
    'isUrgent': 'true',
  }, 'r1');

  expect(request.isUrgent, true);
});

  test('parses myResponse correctly', () {
  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': 1,
    'isUrgent': false,
    'myResponse': 'ACCEPTED',
  }, 'r1');

  expect(request.myResponse, 'accepted');
});

  test('invalid myResponse returns null', () {
  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': 1,
    'isUrgent': false,
    'myResponse': 'maybe',
  }, 'r1');

  expect(request.myResponse, null);
});

  test('parses createdAt from milliseconds', () {
  final now = DateTime.now().millisecondsSinceEpoch;

  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': 1,
    'isUrgent': false,
    'createdAt': now,
  }, 'r1');

  expect(request.createdAt, isNotNull);
});

  test('parses createdAt from string', () {
  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': 1,
    'isUrgent': false,
    'createdAt': '2024-01-01T00:00:00.000Z',
  }, 'r1');

  expect(request.createdAt, isNotNull);
});

  test('handles invalid donor list gracefully', () {
  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': 1,
    'isUrgent': false,
    'acceptedDonors': 'invalid',
  }, 'r1');

  expect(request.acceptedDonors, isEmpty);
});

  test('parses latitude/longitude correctly', () {
  final request = BloodRequest.fromMap({
    'bloodBankId': 'b',
    'bloodBankName': 'Bank',
    'bloodType': 'A+',
    'units': 1,
    'isUrgent': false,
    'hospitalLatitude': '31.95',
    'hospitalLongitude': 35.91,
  }, 'r1');

  expect(request.hospitalLatitude, 31.95);
  expect(request.hospitalLongitude, 35.91);
});

  });
}