import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/models/blood_bank_past_donor.dart';

void main() {
  group('BloodBankPastDonor', () {

    // ================= BASIC =================
    test('fromMap creates object correctly', () {
      final data = {
        'donorId': 'd1',
        'fullName': 'Ali',
        'email': 'a@test.com',
        'phoneNumber': '079',
        'donationCount': 3,
        'lastDonatedAtMs': 123456,
        'messageRequestId': 'r1',
      };

      final result = BloodBankPastDonorSummary.fromMap(data);

      expect(result.donorId, 'd1');
      expect(result.fullName, 'Ali');
      expect(result.email, 'a@test.com');
      expect(result.phoneNumber, '079');
      expect(result.donationCount, 3);
      expect(result.lastDonatedAtMs, 123456);
      expect(result.messageRequestId, 'r1');
    });

    // ================= donationCount =================
    test('parses donationCount from num', () {
      final result = BloodBankPastDonorSummary.fromMap({
        'donationCount': 5.7,
      });

      expect(result.donationCount, 5);
    });

    test('defaults donationCount to 0 when invalid', () {
      final result = BloodBankPastDonorSummary.fromMap({
        'donationCount': 'invalid',
      });

      expect(result.donationCount, 0);
    });

    // ================= lastDonatedAtMs =================
    test('parses lastDonatedAtMs from num', () {
      final result = BloodBankPastDonorSummary.fromMap({
        'lastDonatedAtMs': 123.9,
      });

      expect(result.lastDonatedAtMs, 123);
    });

    test('lastDonatedAtMs null when invalid', () {
      final result = BloodBankPastDonorSummary.fromMap({
        'lastDonatedAtMs': 'invalid',
      });

      expect(result.lastDonatedAtMs, null);
    });

    // ================= messageRequestId =================
    test('trims messageRequestId', () {
      final result = BloodBankPastDonorSummary.fromMap({
        'messageRequestId': '  r1  ',
      });

      expect(result.messageRequestId, 'r1');
    });

    test('empty messageRequestId becomes null', () {
      final result = BloodBankPastDonorSummary.fromMap({
        'messageRequestId': '   ',
      });

      expect(result.messageRequestId, null);
    });

    test('null messageRequestId stays null', () {
      final result = BloodBankPastDonorSummary.fromMap({});

      expect(result.messageRequestId, null);
    });

    // ================= defaults =================
    test('defaults fullName to Donor when null', () {
      final result = BloodBankPastDonorSummary.fromMap({});

      expect(result.fullName, 'Donor');
    });

    test('defaults strings to empty', () {
      final result = BloodBankPastDonorSummary.fromMap({});

      expect(result.donorId, '');
      expect(result.email, '');
      expect(result.phoneNumber, '');
    });

  });
}