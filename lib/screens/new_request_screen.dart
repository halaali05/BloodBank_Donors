import 'package:flutter/material.dart';
import '../services/requests_service.dart';
import '../models/blood_request_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class NewRequestScreen extends StatefulWidget {
  final String bloodBankName;
  final String initialHospitalLocation;

  const NewRequestScreen({
    super.key,
    required this.bloodBankName,
    required this.initialHospitalLocation,
  });

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  static const _pagePadding = 16.0;
  static const _fieldRadius = 14.0;

  String _bloodType = 'A+';
  int _units = 1;
  bool _isUrgent = false;

  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _hospitalLocationController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _hospitalLocationController.text = widget.initialHospitalLocation.trim();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _hospitalLocationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_hospitalLocationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter hospital location')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final request = BloodRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bloodBankId: uid,
      bloodBankName: widget.bloodBankName,
      bloodType: _bloodType,
      units: _units,
      isUrgent: _isUrgent,
      details: _detailsController.text.trim(),
      hospitalLocation: _hospitalLocationController.text.trim(),
    );

    await RequestsService.instance.addRequest(request);

    final donorsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'donor')
        .get();

    for (final donor in donorsSnapshot.docs) {
      await NotificationService.instance.createNotification(
        userId: donor.id,
        requestId: request.id,
        title: 'New blood request',
        body: '${request.bloodType} - ${request.units} units needed',
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request created successfully')),
    );

    Navigator.of(context).pop();
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xfff8f9ff),
      labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: Color(0xffd0d4f0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: Color(0xffd0d4f0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: Color(0xffe60012), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('New blood request'),
          backgroundColor: const Color(0xffe60012),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xfffff1f3), Color(0xfffde6eb)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                _pagePadding,
                _pagePadding,
                _pagePadding,
                _pagePadding + bottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // header
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xffffe3e6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.bloodtype,
                                color: Color(0xffe60012),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Fill the details to create a new blood request.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Blood type
                        const Text(
                          'Blood type',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _bloodType,
                          decoration: _decoration(
                            'Choose the required blood type',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'A+', child: Text('A+')),
                            DropdownMenuItem(value: 'A-', child: Text('A-')),
                            DropdownMenuItem(value: 'B+', child: Text('B+')),
                            DropdownMenuItem(value: 'B-', child: Text('B-')),
                            DropdownMenuItem(value: 'O+', child: Text('O+')),
                            DropdownMenuItem(value: 'O-', child: Text('O-')),
                            DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                            DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _bloodType = v);
                          },
                        ),

                        const SizedBox(height: 16),

                        // Units (سطر لحال)
                        const Text(
                          'Units needed',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xfff8f9ff),
                            borderRadius: BorderRadius.circular(_fieldRadius),
                            border: const BorderSide(
                              color: Color(0xffd0d4f0),
                            ).toBorderSide(),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'Units',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.remove, size: 20),
                                splashRadius: 18,
                                onPressed: () {
                                  if (_units > 1) {
                                    setState(() => _units--);
                                  }
                                },
                              ),
                              Text(
                                '$_units',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                splashRadius: 18,
                                onPressed: () => setState(() => _units++),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Urgent (سطر تحت الوحدات)
                        const Text(
                          'Urgency',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xfffdf4f5),
                            borderRadius: BorderRadius.circular(_fieldRadius),
                            border: Border.all(
                              color: _isUrgent
                                  ? const Color(0xffe60012)
                                  : const Color(0xfff3c6cc),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: Color(0xffc62828),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Mark as urgent request',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _isUrgent,
                                onChanged: (v) => setState(() => _isUrgent = v),
                                activeThumbColor: Colors.white,
                                activeTrackColor: const Color(0xffe60012),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Hospital location
                        TextField(
                          controller: _hospitalLocationController,
                          decoration: _decoration('Hospital location'),
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 16),

                        // Details
                        TextField(
                          controller: _detailsController,
                          maxLines: 4,
                          decoration: _decoration('Extra details (optional)'),
                        ),

                        const SizedBox(height: 22),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffe60012),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 1,
                            ),
                            child: const Text(
                              'Create request',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on BorderSide {
  Border toBorderSide() => Border.all(color: color, width: width);
}
