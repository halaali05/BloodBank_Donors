import 'donor_medical_report.dart';

/// One donor listed under accept / reject for a blood request (blood bank view).
class DonorResponseEntry {
  final String donorId;
  final String fullName;
  final String email;

  /// E.164 or stored mobile from `users/{donorId}` (may be empty for legacy donors).
  final String phoneNumber;

  /// Hospital pipeline status from `donorResponses` (scheduled, tested, …).
  final String? processStatus;

  /// `appointmentAt` from Firestore as epoch ms (when set).
  final int? appointmentAtMillis;

  /// Appointment status from backend automation: scheduled, completed, missed.
  final String? appointmentStatus;

  /// The donor's blood type (e.g. 'A+', 'O-'). May be null/empty if unknown.
  final String? bloodType;

  /// Donor asked to reschedule (shown in blood bank pending tab until a new slot is set).
  final String? rescheduleReason;

  /// Donor's preferred new appointment instant (epoch ms).
  final int? reschedulePreferredAtMillis;

  /// When the reschedule request was submitted (epoch ms).
  final int? rescheduleRequestedAtMillis;

  /// Latest uploaded donor report, visible to blood banks when available.
  final DonorMedicalReport? latestMedicalReport;

  const DonorResponseEntry({
    required this.donorId,
    required this.fullName,
    required this.email,
    this.phoneNumber = '',
    this.processStatus,
    this.appointmentStatus,
    this.appointmentAtMillis,
    this.bloodType,
    this.rescheduleReason,
    this.reschedulePreferredAtMillis,
    this.rescheduleRequestedAtMillis,
    this.latestMedicalReport,
  });

  factory DonorResponseEntry.fromMap(Map<String, dynamic> m) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    int? readMillis(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) return null;
        return int.tryParse(s);
      }
      return null;
    }

    final donorId = pick(['donorId', 'userId', 'uid']);
    var fullName = pick(['fullName', 'name', 'displayName']);
    final email = pick(['email']);
    final phoneNumber = pick(['phoneNumber', 'phone']);
    if (fullName.isEmpty) fullName = 'Donor';

    int? appointmentAtMillis = readMillis(m['appointmentAtMillis']);

    final psRaw = m['processStatus'];
    final String? processStatus = psRaw == null
        ? null
        : psRaw.toString().trim().isEmpty
        ? null
        : psRaw.toString().trim();

    final apptStatusRaw = m['appointmentStatus'];
    final String? appointmentStatus = apptStatusRaw == null
        ? null
        : apptStatusRaw.toString().trim().isEmpty
        ? null
        : apptStatusRaw.toString().trim().toLowerCase();

    final btRaw = m['bloodType'];
    final String? bloodType = btRaw == null
        ? null
        : btRaw.toString().trim().isEmpty
        ? null
        : btRaw.toString().trim();

    final int? reschedulePreferredAtMillis = readMillis(
      m['reschedulePreferredAtMillis'],
    );

    final int? rescheduleRequestedAtMillis = readMillis(
      m['rescheduleRequestedAtMillis'],
    );

    final rrRaw = m['rescheduleReason'];
    final String? rescheduleReason = rrRaw == null
        ? null
        : rrRaw.toString().trim().isEmpty
        ? null
        : rrRaw.toString().trim();

    DonorMedicalReport? latestMedicalReport;
    final latestRaw = m['latestMedicalReport'];
    if (latestRaw is Map) {
      final latestMap = Map<String, dynamic>.from(latestRaw);
      latestMedicalReport = DonorMedicalReport.fromMap(
        latestMap,
        latestMap['id']?.toString() ?? '',
      );
    }

    return DonorResponseEntry(
      donorId: donorId,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      processStatus: processStatus,
      appointmentStatus: appointmentStatus,
      appointmentAtMillis: appointmentAtMillis,
      bloodType: bloodType,
      rescheduleReason: rescheduleReason,
      reschedulePreferredAtMillis: reschedulePreferredAtMillis,
      rescheduleRequestedAtMillis: rescheduleRequestedAtMillis,
      latestMedicalReport: latestMedicalReport,
    );
  }
}
