import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  static const Color deepRed = Color(0xFF7A0009);
  static const Color bg = Color(0xFFF3F5F9);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  bool _isEditing = false;
  bool _saving = false;
  bool _didInit = false;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _initOnce(Map<String, dynamic> data) {
    if (_didInit) return;
    _didInit = true;
    _name.text = (data['name'] ?? '').toString();
  }

  Future<void> _save(DocumentReference<Map<String, dynamic>> ref) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final newName = _name.text.trim();

      await ref.set({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);

      if (!mounted) return;
      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: deepRed),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() ?? {};
          _initOnce(data);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: deepRed.withOpacity(0.12),
                          child: const Icon(Icons.person, color: deepRed),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name.text.isEmpty ? 'Donor' : _name.text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email ?? '',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _name,
                    enabled: _isEditing && !_saving,

                    // ✅ اختياري: يخلي الاسم فوق يتغير أثناء الكتابة
                    onChanged: (_) => setState(() {}),

                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().length < 2
                        ? 'Name is too short'
                        : null,
                  ),

                  const SizedBox(height: 14),

                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepRed,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _saving ? null : () => _save(ref),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save changes'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
