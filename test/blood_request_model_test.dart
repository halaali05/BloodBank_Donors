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
    
    

    ///handles missing optional fields correctly
    test('fromMap handles missing optional fields correctly', () {
      final data = {
        'bloodBankId': 'bank999',
        'bloodBankName': 'Irbid Blood Bank',
        'bloodType': 'O-',
        'units': 2,
        'isUrgent': false,
        
      };

      final request = BloodRequest.fromMap(data, 'req777');

      expect(request.details, '');
      expect(request.hospitalLocation, '');
    });
  

  });
  
}
