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
          {'donorId': 'd1', 'fullName': 'Ali', 'email': 'a@x.com'},
        ],
        'rejectedDonors': [
          {'donorId': 'd2', 'fullName': 'Sara', 'email': 's@x.com'},
        ],
      }, 'r1');

      expect(request.acceptedDonors.length, 1);
      expect(request.acceptedDonors.first.fullName, 'Ali');
      expect(request.rejectedDonors.length, 1);
      expect(request.rejectedDonors.first.email, 's@x.com');
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
    

  });
  
}