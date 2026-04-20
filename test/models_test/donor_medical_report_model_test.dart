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
  // fromActiveBloodRequest 🔥
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
}