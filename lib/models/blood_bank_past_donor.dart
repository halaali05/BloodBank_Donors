/// Summary row for a donor who has donated at the authenticated blood bank.
class BloodBankPastDonorSummary {
  final String donorId;
  final String fullName;
  final String email;
  final String phoneNumber;

  /// From `users/{donorId}.bloodType` when set (e.g. after a lab-confirmed report).
  final String bloodType;

  final int donationCount;
  final int? lastDonatedAtMs;

  /// Request id for in-app chat (only set when that request document still exists).
  final String? messageRequestId;

  const BloodBankPastDonorSummary({
    required this.donorId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.bloodType = '',
    required this.donationCount,
    this.lastDonatedAtMs,
    this.messageRequestId,
  });

  factory BloodBankPastDonorSummary.fromMap(Map<String, dynamic> m) {
    final last = m['lastDonatedAtMs'];
    int? lastMs;
    if (last is int) {
      lastMs = last;
    } else if (last is num) {
      lastMs = last.toInt();
    }

    final countRaw = m['donationCount'];
    final count = countRaw is int
        ? countRaw
        : (countRaw is num ? countRaw.toInt() : 0);

    final msgRid = m['messageRequestId']?.toString().trim();
    final bt = m['bloodType']?.toString().trim() ?? '';
    return BloodBankPastDonorSummary(
      donorId: m['donorId']?.toString() ?? '',
      fullName: m['fullName']?.toString() ?? 'Donor',
      email: m['email']?.toString() ?? '',
      phoneNumber: m['phoneNumber']?.toString() ?? '',
      bloodType: bt,
      donationCount: count,
      lastDonatedAtMs: lastMs,
      messageRequestId: (msgRid != null && msgRid.isNotEmpty) ? msgRid : null,
    );
  }
}
