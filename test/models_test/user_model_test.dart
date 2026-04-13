import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/models/user_model.dart';

class _FakeTimestamp {
  final DateTime _date;
  _FakeTimestamp(this._date);

  DateTime toDate() => _date;
}

void main() {
  group('User Model Tests', () {

    /// creates DONOR user correctly
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
      expect(user.fullName, 'Test Donor');
    });

    /// returns correct donor map
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
      expect(map.containsKey('bloodBankName'), false);
    });

    /// creates HOSPITAL user correctly
    test('fromMap creates HOSPITAL user correctly', () {
      final data = {
        'email': 'hospital@test.com',
        'role': 'hospital',
        'bloodBankName': 'City Hospital',
        'location': 'Amman',
      };

      final user = User.fromMap(data, '456');

      expect(user.uid, '456');
      expect(user.email, 'hospital@test.com');
      expect(user.role, UserRole.hospital);
      expect(user.bloodBankName, 'City Hospital');
      expect(user.location, 'Amman');
      expect(user.fullName, isNull);
    });

    /// uses "name" field when fullName is missing
    test('fromMap uses name as fallback for fullName', () {
      final data = {
        'email': 'test@test.com',
        'role': 'donor',
        'name': 'Fallback Name',
      };

      final user = User.fromMap(data, '789');

      expect(user.fullName, 'Fallback Name');
    });

    /// parses createdAt from milliseconds (int)
    test('createdAt is parsed from milliseconds integer', () {
      final now = DateTime.now();

      final data = {
        'email': 'test@test.com',
        'role': 'donor',
        'createdAt': now.millisecondsSinceEpoch,
      };

      final user = User.fromMap(data, '001');

      expect(user.createdAt, isNotNull);
      expect(
        user.createdAt!.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });

    /// parses createdAt from ISO-8601 string
    test('createdAt is parsed from ISO string', () {
      final dateString = '2024-01-01T10:00:00.000Z';

      final data = {
        'email': 'test@test.com',
        'role': 'donor',
        'createdAt': dateString,
      };

      final user = User.fromMap(data, '002');

      expect(user.createdAt, DateTime.parse(dateString));
    });

    /// parses createdAt from Firestore-like seconds map
    test('createdAt is parsed from seconds map', () {
      final data = {
        'email': 'test@test.com',
        'role': 'donor',
        'createdAt': {'_seconds': 1700000000},
      };

      final user = User.fromMap(data, '003');

      expect(user.createdAt, isNotNull);
    });

    /// returns correct hospital map
    test('toMap returns correct hospital map', () {
      final user = User(
        uid: '999',
        email: 'hospital@test.com',
        role: UserRole.hospital,
        bloodBankName: 'Red Cross',
        location: 'Irbid',
      );

      final map = user.toMap();

      expect(map['email'], 'hospital@test.com');
      expect(map['role'], 'hospital');
      expect(map['bloodBankName'], 'Red Cross');
      expect(map['location'], 'Irbid');
      expect(map.containsKey('fullName'), false);
    });
    /// parses createdAt from object that has toDate() returning DateTime
test('createdAt is parsed from object with toDate()', () {
  final now = DateTime.now();

  // Fake object that mimics Firestore Timestamp behavior
  final fakeTimestamp = _FakeTimestamp(now);

  final data = {
    'email': 'test@test.com',
    'role': 'donor',
    'createdAt': fakeTimestamp,
  };

  final user = User.fromMap(data, '004');

  expect(user.createdAt, now);
});

  });
}
