import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/blood_request_model.dart';
import '../models/donor_medical_report.dart';
import '../services/cloud_functions_service.dart';

/// Controller for donor profile business logic
/// Separates business logic from UI for better maintainability
class DonorProfileController {
  final CloudFunctionsService _cloudFunctions;

  DonorProfileController({CloudFunctionsService? cloudFunctions})
    : _cloudFunctions = cloudFunctions ?? CloudFunctionsService();

  // ------------------ Profile Data Fetching ------------------
  Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      return await _cloudFunctions.getUserData();
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  // ------------------ Profile Update Logic ------------------
  Future<Map<String, dynamic>> updateProfileName({required String name}) async {
    try {
      return await _cloudFunctions.updateUserProfile(name: name);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // ------------------ Donation History ------------------
  /// يجيب التقارير مباشرة من Firestore بدل Cloud Function
  Future<List<DonorMedicalReport>> fetchDonationHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return [];

    List<DonorMedicalReport> fromFirestore = [];

    try {
      // نقرأ مباشرة من medicalReports collection
      final snapshot = await FirebaseFirestore.instance
          .collection('medicalReports')
          .where('donorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      fromFirestore = snapshot.docs.map((doc) {
        return DonorMedicalReport.fromMap(doc.data(), doc.id);
      }).toList();

      print('✅ Firestore reports: ${fromFirestore.length}');
    } catch (e) {
      print('❌ Firestore read error: $e');
      fromFirestore = [];
    }

    final seenRequestIds = <String>{
      for (final r in fromFirestore)
        if (r.requestId.isNotEmpty) r.requestId,
    };

    List<BloodRequest> feed = [];
    try {
      final feedResult = await _cloudFunctions.getRequests(limit: 100);
      final list = feedResult['requests'] as List<dynamic>? ?? [];
      feed = list.map((data) {
        final map = Map<String, dynamic>.from(data as Map);
        final id = map['id'] as String? ?? '';
        return BloodRequest.fromMap(map, id);
      }).toList();
    } catch (_) {
      feed = [];
    }

    final merged = List<DonorMedicalReport>.from(fromFirestore);
    for (final req in feed) {
      if (req.myResponse != 'accepted') continue;
      if (req.isCompleted) continue;
      if (seenRequestIds.contains(req.id)) continue;
      merged.add(DonorMedicalReport.fromActiveBloodRequest(req, uid));
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}
