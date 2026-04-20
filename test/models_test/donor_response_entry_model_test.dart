import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/models/donor_response_entry.dart';

void main() {
  group('DonorResponseEntry', () {

    // ================= BASIC =================
    test('fromMap creates object correctly', () {
      final data = {
        'donorId': 'd1',
        'fullName': 'Ali',
        'email': 'a@test.com',
        'phoneNumber': '079',
        'processStatus': 'scheduled',
        'appointmentAtMillis': 123456,
      };

      final result = DonorResponseEntry.fromMap(data);

      expect(result.donorId, 'd1');
      expect(result.fullName, 'Ali');
      expect(result.email, 'a@test.com');
      expect(result.phoneNumber, '079');
      expect(result.processStatus, 'scheduled');
      expect(result.appointmentAtMillis, 123456);
    });

    // ================= pick() logic =================
    test('picks donorId from alternative keys', () {
      final result = DonorResponseEntry.fromMap({
        'userId': 'u1',
      });

      expect(result.donorId, 'u1');
    });

    test('picks donorId from uid if others missing', () {
      final result = DonorResponseEntry.fromMap({
        'uid': 'u2',
      });

      expect(result.donorId, 'u2');
    });

    // ================= fullName =================
    test('uses displayName when fullName missing', () {
      final result = DonorResponseEntry.fromMap({
        'displayName': 'From Auth',
      });

      expect(result.fullName, 'From Auth');
    });

    test('defaults fullName to Donor when empty', () {
      final result = DonorResponseEntry.fromMap({});

      expect(result.fullName, 'Donor');
    });

    // ================= email =================
    test('email defaults to empty string', () {
      final result = DonorResponseEntry.fromMap({});

      expect(result.email, '');
    });

    // ================= phone =================
    test('picks phone from alternative keys', () {
      final result = DonorResponseEntry.fromMap({
        'phone': '078',
      });

      expect(result.phoneNumber, '078');
    });

    test('phone defaults to empty', () {
      final result = DonorResponseEntry.fromMap({});

      expect(result.phoneNumber, '');
    });

    // ================= appointmentAtMillis =================
    test('parses appointmentAtMillis from num', () {
      final result = DonorResponseEntry.fromMap({
        'appointmentAtMillis': 123.9,
      });

      expect(result.appointmentAtMillis, 123);
    });

    test('appointmentAtMillis null when invalid', () {
      final result = DonorResponseEntry.fromMap({
        'appointmentAtMillis': 'invalid',
      });

      expect(result.appointmentAtMillis, null);
    });

    // ================= processStatus =================
    test('processStatus trims value', () {
      final result = DonorResponseEntry.fromMap({
        'processStatus': '  tested  ',
      });

      expect(result.processStatus, 'tested');
    });

    test('processStatus null when empty', () {
      final result = DonorResponseEntry.fromMap({
        'processStatus': '   ',
      });

      expect(result.processStatus, null);
    });

    test('processStatus null when missing', () {
      final result = DonorResponseEntry.fromMap({});

      expect(result.processStatus, null);
    });

  });
}