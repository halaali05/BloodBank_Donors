/// Model representing a blood bank account awaiting admin approval.
/// Pulled from Firestore's `pending_profiles` collection where status == 'awaiting_admin_approval'.
class PendingApproval {
  final String uid;
  final String email;
  final String role; // always 'hospital' for now
  final String? bloodBankName;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final String status; // 'awaiting_admin_approval' | 'approved' | 'rejected'

  const PendingApproval({
    required this.uid,
    required this.email,
    required this.role,
    this.bloodBankName,
    this.location,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.status = 'awaiting_admin_approval',
  });

  factory PendingApproval.fromMap(Map<String, dynamic> data, String uid) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      if (v is Map && v.containsKey('_seconds')) {
        final s = v['_seconds'];
        if (s is int) return DateTime.fromMillisecondsSinceEpoch(s * 1000);
      }
      return null;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return PendingApproval(
      uid: uid,
      email: (data['email'] ?? '') as String,
      role: (data['role'] ?? 'hospital') as String,
      bloodBankName: data['bloodBankName'] as String?,
      location: data['location'] as String?,
      latitude: parseDouble(data['latitude']),
      longitude: parseDouble(data['longitude']),
      createdAt: parseDate(data['createdAt']),
      status: (data['status'] ?? 'awaiting_admin_approval') as String,
    );
  }
}
