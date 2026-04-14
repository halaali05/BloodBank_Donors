/// One donor listed under accept / reject for a blood request (blood bank view).
class DonorResponseEntry {
  final String donorId;
  final String fullName;
  final String email;

  /// Hospital pipeline status from `donorResponses` (scheduled, tested, …).
  final String? processStatus;

  /// `appointmentAt` from Firestore as epoch ms (when set).
  final int? appointmentAtMillis;

  const DonorResponseEntry({
    required this.donorId,
    required this.fullName,
    required this.email,
    this.processStatus,
    this.appointmentAtMillis,
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

    final donorId = pick(['donorId', 'userId', 'uid']);
    var fullName = pick(['fullName', 'name', 'displayName']);
    final email = pick(['email']);
    if (fullName.isEmpty) fullName = 'Donor';

    int? appointmentAtMillis;
    final apt = m['appointmentAtMillis'];
    if (apt is int) {
      appointmentAtMillis = apt;
    } else if (apt is num) {
      appointmentAtMillis = apt.toInt();
    }

    final psRaw = m['processStatus'];
    final String? processStatus = psRaw == null
        ? null
        : psRaw.toString().trim().isEmpty
        ? null
        : psRaw.toString().trim();

    return DonorResponseEntry(
      donorId: donorId,
      fullName: fullName,
      email: email,
      processStatus: processStatus,
      appointmentAtMillis: appointmentAtMillis,
    );
  }
}
