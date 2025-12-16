import 'package:flutter/material.dart';
import 'requests_service.dart'; // لاستدعاء RequestsService class by Rand
import 'requests_store.dart'; // لاستدعاء BloodRequest class from requests-store by Rand
import 'package:firebase_auth/firebase_auth.dart'; // لاستدعاء uid by rand

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
  static const _fieldRadius = 12.0;

  String _bloodType = 'A+';
  int _units = 1;
  bool _isUrgent = false;

  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _hospitalLocationController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // ✅ يعبّي اللوكيشن اللي انحط بالتسجيل
    _hospitalLocationController.text = widget.initialHospitalLocation.trim();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _hospitalLocationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final request = BloodRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bloodBankId: uid, // by rand
      bloodBankName: widget.bloodBankName,
      bloodType: _bloodType,
      units: _units,
      isUrgent: _isUrgent,
      details: _detailsController.text.trim(),
      hospitalLocation: _hospitalLocationController.text.trim(),
    );

    //RequestsStore.instance.addRequest(request); edit to use Requests service by Rand
    // Navigator.of(context).pop();
    await RequestsService.instance.addRequest(request);
    Navigator.of(context).pop();
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('New blood request')),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              _pagePadding,
              _pagePadding,
              _pagePadding,
              _pagePadding + bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Blood type'),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _bloodType,
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

                Row(
                  children: [
                    const Text('Units:'),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if (_units > 1) setState(() => _units--);
                      },
                    ),
                    Text('$_units'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _units++),
                    ),
                  ],
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Urgent request'),
                  value: _isUrgent,
                  onChanged: (v) => setState(() => _isUrgent = v),
                ),

                const SizedBox(height: 8),
                const Text('Hospital location'),
                const SizedBox(height: 8),
                TextField(
                  controller: _hospitalLocationController,
                  decoration: _decoration('Enter hospital location'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),
                const Text('Details'),
                const SizedBox(height: 8),
                TextField(
                  controller: _detailsController,
                  maxLines: 4,
                  decoration: _decoration('Enter request details'),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Create request'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
