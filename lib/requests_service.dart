import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'requests_store.dart'; // لاستدعاء BloodRequest class from requests-store

class RequestsService {
  RequestsService._internal();
  static final RequestsService instance = RequestsService._internal();
  final db = FirebaseFirestore.instance;
  // to store blood requests in firestore
  final CollectionReference _requestsCollection = FirebaseFirestore.instance
      .collection('requests');

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

  Stream<List<BloodRequest>> getRequestsStream() {
    return _requestsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return BloodRequest(
              id: doc.id,
              bloodBankId: data['bloodBankId'] ?? '', // by rand
              bloodBankName: data['bloodBankName'] ?? '',
              bloodType: data['bloodType'] ?? '',
              units: data['units'] ?? 1,
              isUrgent: data['isUrgent'] ?? false,
              details: data['details'] ?? '',
              hospitalLocation: data['hospitalLocation'] ?? '',
            );
          }).toList(),
        );
  }

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
