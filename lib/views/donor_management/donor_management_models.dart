import '../../models/donor_medical_report.dart';

/// One row in the donor pipeline UI (local list state for [DonorManagementScreen]).
class DonorPipelineRow {
  final String donorId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final DonorProcessStatus status;
  final DateTime? appointmentAt;

  /// The donor's blood type (e.g. 'A+', 'O-'). May be null/empty if unknown.
  final String? bloodType;

  const DonorPipelineRow({
    required this.donorId,
    required this.fullName,
    required this.email,
    this.phoneNumber = '',
    required this.status,
    this.appointmentAt,
    this.bloodType,
  });

  DonorPipelineRow copyWith({
    DonorProcessStatus? status,
    DateTime? appointmentAt,
    String? bloodType,
  }) => DonorPipelineRow(
    donorId: donorId,
    fullName: fullName,
    email: email,
    phoneNumber: phoneNumber,
    status: status ?? this.status,
    appointmentAt: appointmentAt ?? this.appointmentAt,
    bloodType: bloodType ?? this.bloodType,
  );
}
