import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> signUpDonor({
    required String fullName,
    required String email,
    required String password,
    required String bloodType,
    required String location,
    String? medicalFileUrl,//for uploud
  }) async {
    // 1) Create account in Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;

    // 2) Save extra data in Firestore
    await _db.collection('users').doc(uid).set({
      'role': 'donor',
      'fullName': fullName.trim(),
      'email': email.trim(),
      'bloodType': bloodType,
      'location': location.trim(),
      'medicalFileUrl': medicalFileUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String> getUserRole(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = doc.data();
  return (data?['role'] ?? '') as String;
}
}
