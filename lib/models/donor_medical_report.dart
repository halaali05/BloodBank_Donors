import 'blood_request_model.dart';

/// Represents the status of a donor in relation to a specific blood request
enum DonorProcessStatus {
  /// Donor accepted the request, waiting to be scheduled
  accepted,

  /// Appointment has been scheduled with the donor
  scheduled,

  /// Blood was drawn and tests are being processed
  tested,

  /// Donation was successful — report issued
  donated,

  /// Donor was restricted due to medical findings
  restricted,
}

/// Parses a string into a [DonorProcessStatus]
DonorProcessStatus parseDonorProcessStatus(String? value) {
  switch (value?.toLowerCase().trim()) {
    case 'scheduled':
      return DonorProcessStatus.scheduled;
    case 'tested':
      return DonorProcessStatus.tested;
    case 'donated':
      return DonorProcessStatus.donated;
    case 'restricted':
      return DonorProcessStatus.restricted;
    default:
      return DonorProcessStatus.accepted;
  }
}

/// Converts a [DonorProcessStatus] to its string representation
String donorProcessStatusToString(DonorProcessStatus status) {
  switch (status) {
    case DonorProcessStatus.accepted:
      return 'accepted';
    case DonorProcessStatus.scheduled:
      return 'scheduled';
    case DonorProcessStatus.tested:
      return 'tested';
    case DonorProcessStatus.donated:
      return 'donated';
    case DonorProcessStatus.restricted:
      return 'restricted';
  }
}

/// Represents a medical report attached to a donor after a blood draw.
/// This is stored on the donor's profile under their donation history.
class DonorMedicalReport {
  /// Unique report ID
  final String id;

  /// The blood request this report is linked to
  final String requestId;

  /// The blood bank / hospital that issued the report
  final String bloodBankId;
  final String bloodBankName;

  /// Blood type confirmed during the draw
  final String bloodType;

  /// Whether the request was urgent
  final bool isUrgent;

  /// The outcome of the medical evaluation
  final DonorProcessStatus status;

  /// Reason for restriction (only when status == restricted)
  final String? restrictionReason;

  /// Optional notes from the blood bank
  final String? notes;

  /// URL to uploaded medical report file (PDF or image)
  final String? reportFileUrl;

  /// When the report was created
  final DateTime createdAt;

  /// When the donor can donate again (only when status == restricted)
  final DateTime? canDonateAgainAt;

  /// Scheduled appointment time — shown on donor's journey tracker
  // NEW FIELD: needed to display the appointment step in the journey timeline
  final DateTime? appointmentAt;

  const DonorMedicalReport({
    required this.id,
    required this.requestId,
    required this.bloodBankId,
    required this.bloodBankName,
    required this.bloodType,
    required this.isUrgent,
    required this.status,
    required this.createdAt,
    this.restrictionReason,
    this.notes,
    this.reportFileUrl,
    this.canDonateAgainAt,
    this.appointmentAt, // NEW
  });

  /// Request id for API calls: trims [requestId] and, if empty, parses
  /// `active_<requestId>_<donorUid>` style synthetic document ids.
  String get effectiveRequestId {
    final r = requestId.trim();
    if (r.isNotEmpty) return r;
    if (id.startsWith('active_')) {
      final body = id.substring('active_'.length);
      final i = body.lastIndexOf('_');
      if (i > 0) return body.substring(0, i);
    }
    return '';
  }

  static String _requestIdFromMap(Map<String, dynamic> data, String docId) {
    for (final key in ['requestId', 'requestID', 'bloodRequestId']) {
      final v = data[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    if (docId.startsWith('active_')) {
      final body = docId.substring('active_'.length);
      final i = body.lastIndexOf('_');
      if (i > 0) return body.substring(0, i);
    }
    return '';
  }

  /// Builds a journey row from dashboard request data (same source as "posts").
  factory DonorMedicalReport.fromActiveBloodRequest(
    BloodRequest req,
    String donorUid,
  ) {
    var status = parseDonorProcessStatus(req.donorProcessStatus);
    if (req.appointmentAt != null && status == DonorProcessStatus.accepted) {
      status = DonorProcessStatus.scheduled;
    }
    return DonorMedicalReport(
      id: 'active_${req.id}_$donorUid',
      requestId: req.id,
      bloodBankId: req.bloodBankId,
      bloodBankName: req.bloodBankName,
      bloodType: req.bloodType,
      isUrgent: req.isUrgent,
      status: status,
      createdAt: req.createdAt ?? DateTime.now(),
      appointmentAt: req.appointmentAt,
    );
  }

  factory DonorMedicalReport.fromMap(Map<String, dynamic> data, String id) {
    return DonorMedicalReport(
      id: id,
      requestId: _requestIdFromMap(data, id),
      bloodBankId: data['bloodBankId']?.toString() ?? '',
      bloodBankName: data['bloodBankName']?.toString() ?? '',
      bloodType: data['bloodType']?.toString() ?? '',
      isUrgent: data['isUrgent'] == true,
      status: parseDonorProcessStatus(data['status']?.toString()),
      restrictionReason: data['restrictionReason']?.toString(),
      notes: data['notes']?.toString(),
      reportFileUrl: data['reportFileUrl']?.toString(),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      canDonateAgainAt: _parseDate(data['canDonateAgainAt']),
      appointmentAt: _parseDate(data['appointmentAt']), // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'bloodBankId': bloodBankId,
      'bloodBankName': bloodBankName,
      'bloodType': bloodType,
      'isUrgent': isUrgent,
      'status': donorProcessStatusToString(status),
      if (restrictionReason != null) 'restrictionReason': restrictionReason,
      if (notes != null) 'notes': notes,
      if (reportFileUrl != null) 'reportFileUrl': reportFileUrl,
      'createdAt': createdAt.toIso8601String(),
      if (canDonateAgainAt != null)
        'canDonateAgainAt': canDonateAgainAt!.toIso8601String(),
      if (appointmentAt != null) // NEW
        'appointmentAt': appointmentAt!.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    try {
      final dt = v.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    if (v is Map && v.containsKey('_seconds')) {
      final s = v['_seconds'];
      if (s is int) return DateTime.fromMillisecondsSinceEpoch(s * 1000);
    }
    return null;
  }
}

/// Extended donor entry used by blood bank to manage each donor through the process
class DonorProcessEntry {
  final String donorId;
  final String fullName;
  final String email;
  final String bloodType;

  /// Current status of this donor in the process
  final DonorProcessStatus status;

  /// Scheduled appointment time (if status == scheduled)
  final DateTime? appointmentAt;

  /// Medical report (if status == donated or restricted)
  final DonorMedicalReport? medicalReport;

  const DonorProcessEntry({
    required this.donorId,
    required this.fullName,
    required this.email,
    required this.bloodType,
    required this.status,
    this.appointmentAt,
    this.medicalReport,
  });

  factory DonorProcessEntry.fromMap(Map<String, dynamic> m) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    DonorMedicalReport? report;
    if (m['medicalReport'] is Map) {
      final rm = Map<String, dynamic>.from(m['medicalReport'] as Map);
      report = DonorMedicalReport.fromMap(rm, rm['id']?.toString() ?? '');
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return DonorProcessEntry(
      donorId: pick(['donorId', 'userId', 'uid']),
      fullName: pick([
        'fullName',
        'name',
        'displayName',
      ]).let((n) => n.isEmpty ? 'Donor' : n),
      email: pick(['email']),
      bloodType: pick(['bloodType']),
      status: parseDonorProcessStatus(m['processStatus']?.toString()),
      appointmentAt: parseDate(m['appointmentAt']),
      medicalReport: report,
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

