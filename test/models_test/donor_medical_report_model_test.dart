import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/models/donor_medical_report.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';

void main() {

  // =====================================================
  // ENUM + PARSING
  // =====================================================

  group('DonorProcessStatus parsing', () {

    test('parse valid values', () {
      expect(parseDonorProcessStatus('scheduled'),
          DonorProcessStatus.scheduled);
      expect(parseDonorProcessStatus('tested'),
          DonorProcessStatus.tested);
      expect(parseDonorProcessStatus('donated'),
          DonorProcessStatus.donated);
      expect(parseDonorProcessStatus('restricted'),
          DonorProcessStatus.restricted);
    });

    test('defaults to accepted for invalid', () {
      expect(parseDonorProcessStatus('unknown'),
          DonorProcessStatus.accepted);
      expect(parseDonorProcessStatus(null),
          DonorProcessStatus.accepted);
    });

    test('toString conversion', () {
      expect(donorProcessStatusToString(DonorProcessStatus.accepted),
          'accepted');
    });
  });

  // =====================================================
  // DonorMedicalReport.fromMap
  // =====================================================

  group('DonorMedicalReport.fromMap', () {

    test('creates object correctly', () {
      final data = {
        'requestId': 'r1',
        'bloodBankId': 'b1',
        'bloodBankName': 'Bank',
        'bloodType': 'A+',
        'isUrgent': true,
        'status': 'donated',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final report = DonorMedicalReport.fromMap(data, 'id1');

      expect(report.id, 'id1');
      expect(report.requestId, 'r1');
      expect(report.status, DonorProcessStatus.donated);
    });

    test('parses date from milliseconds', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      final report = DonorMedicalReport.fromMap({
        'createdAt': now,
      }, 'id1');

      expect(report.createdAt, isNotNull);
    });

    test('handles invalid date gracefully', () {
      final report = DonorMedicalReport.fromMap({
        'createdAt': 'invalid',
      }, 'id1');

      expect(report.createdAt, isA<DateTime>());
    });
  });

  // =====================================================
  // fromActiveBloodRequest 
  // =====================================================

  group('fromActiveBloodRequest', () {

    test('keeps accepted when no appointment', () {
      final req = BloodRequest(
        id: 'r1',
        bloodBankId: 'b',
        bloodBankName: 'Bank',
        bloodType: 'A+',
        units: 1,
        isUrgent: false,
        donorProcessStatus: 'accepted',
      );

      final result =
          DonorMedicalReport.fromActiveBloodRequest(req, 'u1');

      expect(result.status, DonorProcessStatus.accepted);
    });

    test('changes to scheduled when appointment exists', () {
      final req = BloodRequest(
        id: 'r1',
        bloodBankId: 'b',
        bloodBankName: 'Bank',
        bloodType: 'A+',
        units: 1,
        isUrgent: false,
        donorProcessStatus: 'accepted',
        appointmentAt: DateTime.now(),
      );

      final result =
          DonorMedicalReport.fromActiveBloodRequest(req, 'u1');

      expect(result.status, DonorProcessStatus.scheduled);
    });
  });

  // =====================================================
  // DonorProcessEntry
  // =====================================================

  group('DonorProcessEntry', () {

    test('creates object correctly', () {
      final data = {
        'donorId': 'd1',
        'fullName': 'Ali',
        'email': 'a@test.com',
        'bloodType': 'A+',
        'processStatus': 'tested',
      };

      final entry = DonorProcessEntry.fromMap(data);

      expect(entry.donorId, 'd1');
      expect(entry.fullName, 'Ali');
      expect(entry.status, DonorProcessStatus.tested);
    });

    test('uses fallback name', () {
      final entry = DonorProcessEntry.fromMap({});

      expect(entry.fullName, 'Donor');
    });

    test('parses appointmentAt', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      final entry = DonorProcessEntry.fromMap({
        'appointmentAt': now,
      });

      expect(entry.appointmentAt, isNotNull);
    });

    test('parses nested medicalReport', () {
      final entry = DonorProcessEntry.fromMap({
        'medicalReport': {
          'id': 'r1',
          'createdAt': DateTime.now().toIso8601String(),
        }
      });

      expect(entry.medicalReport, isNotNull);
    });
  });

// =====================================================
// EXTRA COVERAGE - parseDonorProcessStatus
// =====================================================

group('parseDonorProcessStatus edge cases', () {
  test('handles uppercase and spaces', () {
    expect(parseDonorProcessStatus('  TESTED '),
        DonorProcessStatus.tested);
  });

  test('handles null-like strings', () {
    expect(parseDonorProcessStatus('null'),
        DonorProcessStatus.accepted);
  });
});


// =====================================================
// EXTRA COVERAGE - effectiveRequestId
// =====================================================

group('effectiveRequestId', () {
  test('returns trimmed requestId', () {
    final report = DonorMedicalReport(
      id: 'id1',
      requestId: '  r1  ',
      bloodBankId: '',
      bloodBankName: '',
      bloodType: '',
      isUrgent: false,
      status: DonorProcessStatus.accepted,
      createdAt: DateTime.now(),
    );

    expect(report.effectiveRequestId, 'r1');
  });

  test('extracts from active id when empty requestId', () {
    final report = DonorMedicalReport(
      id: 'active_req123_user1',
      requestId: '',
      bloodBankId: '',
      bloodBankName: '',
      bloodType: '',
      isUrgent: false,
      status: DonorProcessStatus.accepted,
      createdAt: DateTime.now(),
    );

    expect(report.effectiveRequestId, 'req123');
  });

  test('returns empty if no valid source', () {
    final report = DonorMedicalReport(
      id: 'random',
      requestId: '',
      bloodBankId: '',
      bloodBankName: '',
      bloodType: '',
      isUrgent: false,
      status: DonorProcessStatus.accepted,
      createdAt: DateTime.now(),
    );

    expect(report.effectiveRequestId, '');
  });
});


// =====================================================
// EXTRA COVERAGE - fromMap advanced parsing
// =====================================================

group('DonorMedicalReport.fromMap advanced', () {

  test('uses fallback keys correctly', () {
    final report = DonorMedicalReport.fromMap({
      'hospitalId': 'h1',
      'hospitalName': 'Hosp',
      'confirmedBloodType': 'B+',
    }, 'id1');

    expect(report.bloodBankId, 'h1');
    expect(report.bloodBankName, 'Hosp');
    expect(report.bloodType, 'B+');
  });

  test('extracts requestId from alternative keys', () {
    final report = DonorMedicalReport.fromMap({
      'bloodRequestId': 'r99',
    }, 'id1');

    expect(report.requestId, 'r99');
  });

  test('extracts requestId from docId', () {
    final report = DonorMedicalReport.fromMap({}, 'active_r77_u1');

    expect(report.requestId, 'r77');
  });

  test('parses Firestore timestamp map', () {
    final report = DonorMedicalReport.fromMap({
      'createdAt': {'_seconds': 1000},
    }, 'id1');

    expect(report.createdAt, isNotNull);
  });

  test('handles reportFileUrl normalization', () {
    final report = DonorMedicalReport.fromMap({
      'url': 'http://file.com',
    }, 'id1');

    expect(report.reportFileUrl, 'http://file.com');
  });

  test('empty url becomes null', () {
    final report = DonorMedicalReport.fromMap({
      'url': '',
    }, 'id1');

    expect(report.reportFileUrl, isNull);
  });

  test('parses canDonateAgainAt', () {
    final now = DateTime.now().millisecondsSinceEpoch;

    final report = DonorMedicalReport.fromMap({
      'canDonateAgainAt': now,
    }, 'id1');

    expect(report.canDonateAgainAt, isNotNull);
  });
});


// =====================================================
// EXTRA COVERAGE - toMap
// =====================================================

group('DonorMedicalReport.toMap', () {

  test('includes optional fields when present', () {
    final report = DonorMedicalReport(
      id: 'id1',
      requestId: 'r1',
      bloodBankId: 'b1',
      bloodBankName: 'Bank',
      bloodType: 'A+',
      isUrgent: true,
      status: DonorProcessStatus.restricted,
      createdAt: DateTime.now(),
      restrictionReason: 'test',
      notes: 'note',
      reportFileUrl: 'url',
      canDonateAgainAt: DateTime.now(),
      appointmentAt: DateTime.now(),
    );

    final map = report.toMap();

    expect(map.containsKey('restrictionReason'), true);
    expect(map.containsKey('appointmentAt'), true);
  });

  test('excludes null optional fields', () {
    final report = DonorMedicalReport(
      id: 'id1',
      requestId: 'r1',
      bloodBankId: 'b1',
      bloodBankName: 'Bank',
      bloodType: 'A+',
      isUrgent: false,
      status: DonorProcessStatus.accepted,
      createdAt: DateTime.now(),
    );

    final map = report.toMap();

    expect(map.containsKey('restrictionReason'), false);
    expect(map.containsKey('appointmentAt'), false);
  });
});


// =====================================================
// EXTRA COVERAGE - fromActiveBloodRequest
// =====================================================

group('fromActiveBloodRequest edge cases', () {

  test('does not override non-accepted status', () {
    final req = BloodRequest(
      id: 'r1',
      bloodBankId: 'b',
      bloodBankName: 'Bank',
      bloodType: 'A+',
      units: 1,
      isUrgent: false,
      donorProcessStatus: 'tested',
      appointmentAt: DateTime.now(),
    );

    final result =
        DonorMedicalReport.fromActiveBloodRequest(req, 'u1');

    expect(result.status, DonorProcessStatus.tested);
  });
});


// =====================================================
// EXTRA COVERAGE - DonorProcessEntry
// =====================================================

group('DonorProcessEntry edge cases', () {

  test('uses alternative donorId keys', () {
    final entry = DonorProcessEntry.fromMap({
      'userId': 'u1',
    });

    expect(entry.donorId, 'u1');
  });

  test('defaults status to accepted', () {
    final entry = DonorProcessEntry.fromMap({});

    expect(entry.status, DonorProcessStatus.accepted);
  });

  test('handles empty email and bloodType', () {
    final entry = DonorProcessEntry.fromMap({});

    expect(entry.email, '');
    expect(entry.bloodType, '');
  });

  test('medicalReport parses id correctly', () {
    final entry = DonorProcessEntry.fromMap({
      'medicalReport': {
        'id': 'r123',
      }
    });

    expect(entry.medicalReport?.id, 'r123');
  });
});
}