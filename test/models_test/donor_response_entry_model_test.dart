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

    test('parses reschedule fields', () {
      final result = DonorResponseEntry.fromMap({
        'donorId': 'd1',
        'rescheduleReason': '  Work trip  ',
        'reschedulePreferredAtMillis': 1700000000000,
        'rescheduleRequestedAtMillis': 1700000001000.0,
      });

      expect(result.rescheduleReason, 'Work trip');
      expect(result.reschedulePreferredAtMillis, 1700000000000);
      expect(result.rescheduleRequestedAtMillis, 1700000001000);
    });

    test('parses reschedule millis from string JSON', () {
      final result = DonorResponseEntry.fromMap({
        'donorId': 'd1',
        'rescheduleRequestedAtMillis': '1700000002000',
        'reschedulePreferredAtMillis': '1700000003000',
      });

      expect(result.rescheduleRequestedAtMillis, 1700000002000);
      expect(result.reschedulePreferredAtMillis, 1700000003000);
    });

  });

  // =====================================================
// EXTRA COVERAGE - appointmentStatus
// =====================================================

test('appointmentStatus is lowercased', () {
  final result = DonorResponseEntry.fromMap({
    'appointmentStatus': 'COMPLETED',
  });

  expect(result.appointmentStatus, 'completed');
});

test('appointmentStatus null when empty', () {
  final result = DonorResponseEntry.fromMap({
    'appointmentStatus': '   ',
  });

  expect(result.appointmentStatus, null);
});


// =====================================================
// EXTRA COVERAGE - bloodType
// =====================================================

test('bloodType trims correctly', () {
  final result = DonorResponseEntry.fromMap({
    'bloodType': '  A+  ',
  });

  expect(result.bloodType, 'A+');
});

test('bloodType null when empty', () {
  final result = DonorResponseEntry.fromMap({
    'bloodType': '   ',
  });

  expect(result.bloodType, null);
});


// =====================================================
// EXTRA COVERAGE - readMillis()
// =====================================================

test('appointmentAtMillis null when empty string', () {
  final result = DonorResponseEntry.fromMap({
    'appointmentAtMillis': '',
  });

  expect(result.appointmentAtMillis, null);
});

test('reschedule millis null when invalid string', () {
  final result = DonorResponseEntry.fromMap({
    'rescheduleRequestedAtMillis': 'abc',
  });

  expect(result.rescheduleRequestedAtMillis, null);
});

test('readMillis handles null correctly', () {
  final result = DonorResponseEntry.fromMap({
    'appointmentAtMillis': null,
  });

  expect(result.appointmentAtMillis, null);
});


// =====================================================
// EXTRA COVERAGE - processStatus robustness
// =====================================================

test('processStatus handles non-string values', () {
  final result = DonorResponseEntry.fromMap({
    'processStatus': 123,
  });

  expect(result.processStatus, '123');
});


// =====================================================
// EXTRA COVERAGE - latestMedicalReport
// =====================================================

test('parses latestMedicalReport correctly', () {
  final result = DonorResponseEntry.fromMap({
    'latestMedicalReport': {
      'id': 'r1',
      'createdAt': DateTime.now().toIso8601String(),
    }
  });

  expect(result.latestMedicalReport, isNotNull);
  expect(result.latestMedicalReport!.id, 'r1');
});

test('latestMedicalReport null when not map', () {
  final result = DonorResponseEntry.fromMap({
    'latestMedicalReport': 'invalid',
  });

  expect(result.latestMedicalReport, null);
});


// =====================================================
// EXTRA COVERAGE - pick() edge cases
// =====================================================

test('pick ignores empty and whitespace values', () {
  final result = DonorResponseEntry.fromMap({
    'donorId': '   ',
    'userId': '',
    'uid': 'realId',
  });

  expect(result.donorId, 'realId');
});

test('email trims correctly', () {
  final result = DonorResponseEntry.fromMap({
    'email': '  test@mail.com  ',
  });

  expect(result.email, 'test@mail.com');
});
}