import '../../models/donor_medical_report.dart';

/// One row in the donor pipeline UI (local list state for [DonorManagementScreen]).
class DonorPipelineRow {
  final String donorId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final DonorProcessStatus status;
  final DateTime? appointmentAt;

  const DonorPipelineRow({
    required this.donorId,
    required this.fullName,
    required this.email,
    this.phoneNumber = '',
    required this.status,
    this.appointmentAt,
  });

  DonorPipelineRow copyWith({
    DonorProcessStatus? status,
    DateTime? appointmentAt,
  }) =>
      DonorPipelineRow(
        donorId: donorId,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        status: status ?? this.status,
        appointmentAt: appointmentAt ?? this.appointmentAt,
      );
}
