import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';

/// Service class for managing blood requests
/// Handles creating, retrieving, and notifying about blood requests
class RequestsService {
  RequestsService._internal();
  static final RequestsService instance = RequestsService._internal();

  final CollectionReference _requestsCollection = FirebaseFirestore.instance
      .collection('requests');

  /// Adds a new blood request to Firestore
  ///
  /// Creates a new blood request in the Firestore database and sends
  /// notifications to all donors if the request is marked as urgent.
  ///
  /// Parameters:
  /// - [request]: The [BloodRequest] object containing all request details
  ///
  /// Throws [FirebaseException] if the request fails to save
  Future<void> addRequest(BloodRequest request) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _requestsCollection.doc(request.id).set({
      'bloodBankId': uid,
      'bloodBankName': request.bloodBankName,
      'bloodType': request.bloodType,
      'units': request.units,
      'isUrgent': request.isUrgent,
      'details': request.details,
      'hospitalLocation': request.hospitalLocation,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (request.isUrgent) {
      await _sendNotificationToDonors(request);
    }
  }

  /// Gets a stream of all blood requests ordered by creation date
  ///
  /// Returns a real-time stream of all blood requests from Firestore,
  /// ordered by creation date (newest first). The stream automatically
  /// updates whenever requests are added, modified, or deleted.
  ///
  /// Returns:
  /// - A [Stream] of [List<BloodRequest>] that emits whenever the data changes
  Stream<List<BloodRequest>> getRequestsStream() {
    return _requestsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return BloodRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList(),
        );
  }

  /// Sends notifications to all donors for urgent requests
  ///
  /// Private method that creates notification documents in Firestore for
  /// all registered donors when an urgent blood request is created.
  ///
  /// Parameters:
  /// - [request]: The urgent [BloodRequest] that triggered the notifications
  ///
  /// Note: This is called automatically when a request with [isUrgent] = true is added
  Future<void> _sendNotificationToDonors(BloodRequest request) async {
    final donorsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'donor')
        .get();

    for (var doc in donorsSnapshot.docs) {
      final donorId = doc.id;
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(donorId)
          .collection('user_notifications')
          .add({
            'title': 'Urgent blood request: ${request.bloodType}',
            'body': '${request.units} units needed at ${request.bloodBankName}',
            'requestId': request.id,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
    }
  }
}
