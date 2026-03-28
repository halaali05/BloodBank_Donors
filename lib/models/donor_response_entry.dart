/// One donor listed under accept / reject for a blood request (blood bank view).
class DonorResponseEntry {
  final String donorId;
  final String fullName;
  final String email;

  const DonorResponseEntry({
    required this.donorId,
    required this.fullName,
    required this.email,
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
    return DonorResponseEntry(
      donorId: donorId,
      fullName: fullName,
      email: email,
    );
  }
}
