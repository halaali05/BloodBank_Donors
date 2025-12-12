import 'package:flutter/material.dart';
import 'requests_store.dart';

class NewRequestScreen extends StatefulWidget {
  final String bloodBankName;

  const NewRequestScreen({super.key, required this.bloodBankName});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  String bloodType = 'A+';
  int units = 1;
  bool isUrgent = false;

  final TextEditingController detailsController = TextEditingController();
  final TextEditingController hospitalLocationController =
      TextEditingController();

  @override
  void dispose() {
    detailsController.dispose();
    hospitalLocationController.dispose();
    super.dispose();
  }

  void _submit() {
    final request = BloodRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bloodBankName: widget.bloodBankName,
      bloodType: bloodType,
      units: units,
      isUrgent: isUrgent,
      details: detailsController.text.trim(),
      hospitalLocation: hospitalLocationController.text.trim(),
    );

    RequestsStore.instance.addRequest(request);
    Navigator.of(context).pop();
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
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Blood type'),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: bloodType,
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
                    if (v != null) setState(() => bloodType = v);
                  },
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    const Text('Units:'),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if (units > 1) setState(() => units--);
                      },
                    ),
                    Text('$units'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => units++),
                    ),
                  ],
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Urgent request'),
                  value: isUrgent,
                  onChanged: (v) => setState(() => isUrgent = v),
                ),

                const SizedBox(height: 8),

                const Text('Hospital location'),
                const SizedBox(height: 8),
                TextField(
                  controller: hospitalLocationController,
                  decoration: InputDecoration(
                    hintText: 'Enter hospital location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                const Text('Details'),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter request details',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
