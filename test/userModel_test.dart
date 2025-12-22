import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/models/user_model.dart';


void main() {
  group('User Model Tests', () {

    ///creates DONOR user correctly
    test('fromMap creates DONOR user correctly', () {
      final data = {
        'email': 'donor@test.com',
        'role': 'donor',
        'fullName': 'Test Donor',
      };

      final user = User.fromMap(data, '123');

      expect(user.uid, '123');
      expect(user.email, 'donor@test.com');
      expect(user.role, UserRole.donor);
    });

    ///returns correct donor map
    test('toMap returns correct donor map', () {
      final user = User(
        uid: '111',
        email: 'donor@test.com',
        role: UserRole.donor,
        fullName: 'Donor Name',
      );

      final map = user.toMap();

      expect(map['email'], 'donor@test.com');
      expect(map['role'], 'donor');
      expect(map['fullName'], 'Donor Name');
    });
  });
}
