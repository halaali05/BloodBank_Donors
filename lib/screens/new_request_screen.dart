import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  // ✅ Theme colors
  static const Color deepRed = Color(0xFF7A0009);
  static const Color softBg = Color(0xFFF6F3F4); // أبيض مائل للسكري
  static const Color fieldFill = Color(0xFFF8F9FF);

  static const _pagePadding = 16.0;
  static const _fieldRadius = 14.0;

  String _bloodType = 'A+';
  int _units = 1;
  bool _isUrgent = false;
  bool _isLoading = false;

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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create a request.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final requestData = {
      'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
      'bloodBankId': uid,
      'bloodBankName': widget.bloodBankName,
      'bloodType': _bloodType,
      'units': _units,
      'isUrgent': _isUrgent,
      'details': _detailsController.text.trim(),
      'hospitalLocation': _hospitalLocationController.text.trim(),
    };

    setState(() => _isLoading = true);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions.httpsCallable('addRequest').call(requestData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ رجوع للداشبورد مباشرة
      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to create request. Please try again.';

      switch (e.code) {
        case 'permission-denied':
          errorMessage =
              'You do not have permission to create requests. Only hospitals can create requests.';
          break;
        case 'invalid-argument':
          errorMessage =
              e.message ?? 'Please check your request details and try again.';
          break;
        case 'unauthenticated':
          errorMessage = 'Please log in to create a request.';
          break;
        case 'internal':
          errorMessage = 'Server error occurred. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorStr = e.toString().toLowerCase();
      String errorMessage =
          'Failed to create request. Please check your internet connection and try again.';

      if (errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('timeout')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey[700]) : null,
      filled: true,
      fillColor: fieldFill,
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
        borderSide: const BorderSide(color: deepRed, width: 1.6),
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
        backgroundColor: softBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          centerTitle: true,

          // ✅ لوغو يسار
          leadingWidth: 90,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'images/logoBLOOD.png',
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ),

          title: const Text(
            'New Request',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),

          // ✅ سهم رجوع يمين
          actions: [
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
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
                    border: Border.all(color: const Color(0xFFE6EAF2)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 6),
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
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: deepRed.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.bloodtype, color: deepRed),
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

                      const Text(
                        'Blood type',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _bloodType,
                        decoration: _decoration(
                          label: 'Choose the required blood type',
                          icon: Icons.water_drop_outlined,
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

                      const Text(
                        'Units needed',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 56,
                        decoration: BoxDecoration(
                          color: fieldFill,
                          borderRadius: BorderRadius.circular(_fieldRadius),
                          border: Border.all(color: const Color(0xffd0d4f0)),
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
                              onPressed: _units > 1
                                  ? () => setState(() => _units--)
                                  : null,
                            ),
                            Text(
                              '$_units',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
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

                      const Text(
                        'Urgency',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4F5),
                          borderRadius: BorderRadius.circular(_fieldRadius),
                          border: Border.all(
                            color: _isUrgent
                                ? deepRed
                                : const Color(0xFFF0C9CE),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 20,
                              color: Color(0xFFC62828),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Mark as urgent request',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            Switch(
                              value: _isUrgent,
                              onChanged: (v) => setState(() => _isUrgent = v),
                              activeTrackColor: deepRed,
                              activeThumbColor: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      TextField(
                        controller: _hospitalLocationController,
                        decoration: _decoration(
                          label: 'Hospital location',
                          icon: Icons.location_on_outlined,
                        ),
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _detailsController,
                        maxLines: 4,
                        decoration: _decoration(
                          label: 'Extra details (optional)',
                          icon: Icons.notes_outlined,
                        ),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Create request',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
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
    );
  }
}
