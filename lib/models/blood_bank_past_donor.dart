/// Summary row for a donor who has donated at the authenticated blood bank.
class BloodBankPastDonorSummary {
  final String donorId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final int donationCount;
  final int? lastDonatedAtMs;

  /// Request id for in-app chat (only set when that request document still exists).
  final String? messageRequestId;

  const BloodBankPastDonorSummary({
    required this.donorId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
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
    return BloodBankPastDonorSummary(
      donorId: m['donorId']?.toString() ?? '',
      fullName: m['fullName']?.toString() ?? 'Donor',
      email: m['email']?.toString() ?? '',
      phoneNumber: m['phoneNumber']?.toString() ?? '',
      donationCount: count,
      lastDonatedAtMs: lastMs,
      messageRequestId: (msgRid != null && msgRid.isNotEmpty) ? msgRid : null,
    );
  }
}
