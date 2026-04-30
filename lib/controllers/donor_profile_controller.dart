import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/blood_request_model.dart';
import '../models/donor_medical_report.dart';
import '../services/cloud_functions_service.dart';

/// Loads/saves donor profile slices (Firestore access only through callables).
class DonorProfileController {
  final CloudFunctionsService _cloudFunctions;

  final FirebaseAuth _auth;

  DonorProfileController({
    CloudFunctionsService? cloudFunctions,
    FirebaseAuth? auth,
  }) : _cloudFunctions = cloudFunctions ?? CloudFunctionsService(),
       _auth = auth ?? FirebaseAuth.instance;

  Future<User?> _waitForCurrentUser() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    try {
      return await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return _auth.currentUser;
    }
  }

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
  /// Fetches the donor journey through Cloud Functions so Firestore remains
  /// server-only for app data reads.
  Future<List<DonorMedicalReport>> fetchDonationHistory({
    bool includeActiveProgress = true,
  }) async {
    final uid = (await _waitForCurrentUser())?.uid ?? '';
    if (uid.isEmpty) return [];

    final reports = <DonorMedicalReport>[];
    var activeProgressIncluded = false;
    try {
      final result = includeActiveProgress
          ? await _cloudFunctions.getDonationHistory()
          : await _cloudFunctions.getDonationHistory(
              includeActiveProgress: false,
            );
      activeProgressIncluded = result['activeProgressIncluded'] == true;
      final rawReports = result['reports'] as List<dynamic>? ?? const [];
      reports.addAll(
        rawReports.map((data) {
          final map = Map<String, dynamic>.from(data as Map);
          return DonorMedicalReport.fromMap(map, map['id']?.toString() ?? '');
        }),
      );
    } catch (e) {
      debugPrint('Donation history load error: $e');
      if (!includeActiveProgress) rethrow;
    }
    if (includeActiveProgress && !activeProgressIncluded && reports.isEmpty) {
      await _mergeActiveDonationProgress(reports, uid);
    }
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  Future<void> _mergeActiveDonationProgress(
    List<DonorMedicalReport> reports,
    String uid,
  ) async {
    final seenRequestIds = <String>{
      for (final report in reports)
        if (report.requestId.trim().isNotEmpty) report.requestId.trim(),
    };

    try {
      final feedResult = await _cloudFunctions.getRequests(limit: 100);
      final rawRequests = feedResult['requests'] as List<dynamic>? ?? const [];
      for (final raw in rawRequests) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final requestId = map['id']?.toString() ?? '';
        if (requestId.isEmpty || seenRequestIds.contains(requestId)) continue;

        final request = BloodRequest.fromMap(map, requestId);
        if (request.myResponse != 'accepted') continue;
        if (request.isCompleted) continue;

        reports.add(DonorMedicalReport.fromActiveBloodRequest(request, uid));
        seenRequestIds.add(requestId);
      }
    } catch (e) {
      debugPrint('Active donation progress fallback failed: $e');
    }
  }

  /// Upload bytes to Firebase Storage under `profile_images/{uid}` and sync
  /// [User.photoURL] via Auth.
  Future<String> uploadProfileAvatarBytes({
    required Uint8List bytes,
    required String extension,
  }) async {
    final user = await _waitForCurrentUser();
    if (user == null) {
      throw Exception('You are not authenticated. Please login again.');
    }
    final ext = extension.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child(user.uid)
        .child('avatar_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    await user.updatePhotoURL(url);
    return url;
  }
}
