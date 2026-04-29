import '../models/blood_request_model.dart';
import '../models/user_model.dart';
import '../services/cloud_functions_service.dart';

/// Controller for admin dashboard — manages all data fetching and stats
class AdminController {
  final CloudFunctionsService _cloudFunctions;

  AdminController({CloudFunctionsService? cloudFunctions})
    : _cloudFunctions = cloudFunctions ?? CloudFunctionsService();

  // ─────────────────── Requests ───────────────────

  /// Fetches ALL requests across all blood banks (admin only)
  Future<List<BloodRequest>> fetchAllRequests({int limit = 200}) async {
    try {
      final result = await _cloudFunctions.getAdminRequests(limit: limit);
      final raw = result['requests'];
      if (raw is! List) return [];
      return raw.whereType<Map>().map((data) {
        final m = Map<String, dynamic>.from(data);
        return BloodRequest.fromMap(m, m['id']?.toString() ?? '');
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch requests: $e');
    }
  }

  /// Deletes any request (admin override)
  Future<void> deleteRequest(String requestId) async {
    await _cloudFunctions.deleteRequest(requestId: requestId);
  }

  /// Marks any request completed (admin override)
  Future<void> markCompleted(String requestId) async {
    await _cloudFunctions.markRequestCompleted(requestId: requestId);
  }

  // ─────────────────── Donors ───────────────────

  /// Fetches donors — optionally filtered by blood type
  Future<List<User>> fetchDonors({String? bloodType, int limit = 200}) async {
    try {
      final result = await _cloudFunctions.getDonors(
        bloodType: bloodType,
        limit: limit,
      );
      final raw = result['donors'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((data) {
            final m = Map<String, dynamic>.from(data);
            return User.fromMap(m, m['uid']?.toString() ?? '');
          })
          .where((u) => u.role == UserRole.donor)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch donors: $e');
    }
  }

  // ─────────────────── Statistics ───────────────────

  /// Computes overall admin statistics from a list of requests
  AdminStats computeStats(List<BloodRequest> requests, List<User> donors) {
    final active = requests.where((r) => !r.isCompleted).toList();
    final completed = requests.where((r) => r.isCompleted).toList();
    final urgent = active.where((r) => r.isUrgent).toList();

    final totalUnits = active.fold<int>(0, (s, r) => s + r.units);
    final totalAccepted = requests.fold<int>(0, (s, r) => s + r.acceptedCount);

    // Donors with restrictions
    final now = DateTime.now();
    final restricted = donors
        .where(
          (d) =>
              d.isPermanentlyBlocked ||
              (d.restrictedUntil != null && d.restrictedUntil!.isAfter(now)) ||
              (d.nextDonationEligibleAt != null &&
                  d.nextDonationEligibleAt!.isAfter(now)),
        )
        .length;

    // Blood type distribution
    final btMap = <String, int>{};
    for (final d in donors) {
      if (d.bloodType != null && d.bloodType!.isNotEmpty) {
        btMap[d.bloodType!] = (btMap[d.bloodType!] ?? 0) + 1;
      }
    }

    // Requests per blood bank
    final bankMap = <String, int>{};
    for (final r in requests) {
      bankMap[r.bloodBankName] = (bankMap[r.bloodBankName] ?? 0) + 1;
    }

    // Governorate distribution of donors
    final govMap = <String, int>{};
    for (final d in donors) {
      if (d.location != null && d.location!.isNotEmpty) {
        govMap[d.location!] = (govMap[d.location!] ?? 0) + 1;
      }
    }

    return AdminStats(
      totalRequests: requests.length,
      activeRequests: active.length,
      completedRequests: completed.length,
      urgentRequests: urgent.length,
      totalUnitsNeeded: totalUnits,
      totalAcceptances: totalAccepted,
      totalDonors: donors.length,
      restrictedDonors: restricted,
      bloodTypeDistribution: btMap,
      requestsPerBank: bankMap,
      donorsPerGovernorate: govMap,
    );
  }
}

/// Value object for admin-level statistics
class AdminStats {
  final int totalRequests;
  final int activeRequests;
  final int completedRequests;
  final int urgentRequests;
  final int totalUnitsNeeded;
  final int totalAcceptances;
  final int totalDonors;
  final int restrictedDonors;
  final Map<String, int> bloodTypeDistribution;
  final Map<String, int> requestsPerBank;
  final Map<String, int> donorsPerGovernorate;

  const AdminStats({
    required this.totalRequests,
    required this.activeRequests,
    required this.completedRequests,
    required this.urgentRequests,
    required this.totalUnitsNeeded,
    required this.totalAcceptances,
    required this.totalDonors,
    required this.restrictedDonors,
    required this.bloodTypeDistribution,
    required this.requestsPerBank,
    required this.donorsPerGovernorate,
  });
}
