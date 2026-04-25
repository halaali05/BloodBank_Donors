import '../../models/donor_medical_report.dart';

/// One row in the donor pipeline UI (local list state for [DonorManagementScreen]).
class DonorPipelineRow {
  final String donorId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final DonorProcessStatus status;
  final String? appointmentStatus;
  final DateTime? appointmentAt;

  /// The donor's blood type (e.g. 'A+', 'O-'). May be null/empty if unknown.
  final String? bloodType;

  final String? rescheduleReason;
  final DateTime? reschedulePreferredAt;
  final DateTime? rescheduleRequestedAt;
  final DonorMedicalReport? latestMedicalReport;

  const DonorPipelineRow({
    required this.donorId,
    required this.fullName,
    required this.email,
    this.phoneNumber = '',
    required this.status,
    this.appointmentStatus,
    this.appointmentAt,
    this.bloodType,
    this.rescheduleReason,
    this.reschedulePreferredAt,
    this.rescheduleRequestedAt,
    this.latestMedicalReport,
  });

  /// True when donor is back in pending and asked for a new slot (reason / time
  /// may arrive even if requested-at millis failed to parse from JSON).
  bool get hasPendingRescheduleRequest {
    if (status != DonorProcessStatus.accepted) return false;
    if (rescheduleRequestedAt != null) return true;
    if (reschedulePreferredAt != null) return true;
    final r = rescheduleReason?.trim();
    return r != null && r.isNotEmpty;
  }

  DonorPipelineRow copyWith({
    DonorProcessStatus? status,
    String? appointmentStatus,
    DateTime? appointmentAt,
    String? bloodType,
    String? rescheduleReason,
    DateTime? reschedulePreferredAt,
    DateTime? rescheduleRequestedAt,
    DonorMedicalReport? latestMedicalReport,
  }) => DonorPipelineRow(
    donorId: donorId,
    fullName: fullName,
    email: email,
    phoneNumber: phoneNumber,
    status: status ?? this.status,
    appointmentStatus: appointmentStatus ?? this.appointmentStatus,
    appointmentAt: appointmentAt ?? this.appointmentAt,
    bloodType: bloodType ?? this.bloodType,
    rescheduleReason: rescheduleReason ?? this.rescheduleReason,
    reschedulePreferredAt: reschedulePreferredAt ?? this.reschedulePreferredAt,
    rescheduleRequestedAt: rescheduleRequestedAt ?? this.rescheduleRequestedAt,
    latestMedicalReport: latestMedicalReport ?? this.latestMedicalReport,
  );
}
