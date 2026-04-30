import 'package:flutter/material.dart';

import '../controllers/new_request_controller.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/common/async_button.dart';
import '../shared/utils/snack_bar_helper.dart';

/// Blood banks publish a live request (`bloodBankName` + optional `initialHospitalLocation` pre-fill).

class NewRequestScreen extends StatefulWidget {
  /// Logged-in bank label stored on the request.
  final String bloodBankName;

  /// Preferred governorate pulled from profile when it matches the fixed list.
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
  final NewRequestController _controller = NewRequestController();

  String _bloodType = 'A+';
  int _units = 1;
  bool _isUrgent = false;
  bool _isLoading = false;

  final TextEditingController _detailsController = TextEditingController();

  /// Governorate dropdown; optional free text replaced by predefined list + map pin upstream.
  String? _selectedHospitalLocation;

  @override
  void initState() {
    super.initState();
    // If the saved profile hospital matches our governorate list, select it automatically.
    final initialLocation = widget.initialHospitalLocation.trim();
    if (initialLocation.isNotEmpty &&
        AppTheme.jordanianGovernorates.contains(initialLocation)) {
      _selectedHospitalLocation = initialLocation;
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      // Delegate creation + validation errors to controller → Cloud Functions.
      final result = await _controller.createRequest(
        bloodBankName: widget.bloodBankName,
        bloodType: _bloodType,
        units: _units,
        isUrgent: _isUrgent,
        hospitalLocation: _selectedHospitalLocation ?? '',
        details: _detailsController.text.trim(),
        hospitalLatitude: AppTheme.getLatitude(_selectedHospitalLocation ?? ''),
        hospitalLongitude: AppTheme.getLongitude(
          _selectedHospitalLocation ?? '',
        ),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        SnackBarHelper.success(context, 'Request created successfully');

        // Pop `true` so the caller screen can refresh lists.
        Navigator.of(context).pop(true);
      } else {
        SnackBarHelper.failure(
          context,
          result['errorMessage']?.toString() ?? 'Failed to create request',
        );
      }
    } catch (e) {
      if (!mounted) return;

      SnackBarHelper.failure(
        context,
        'An unexpected error occurred: '
        '${SnackBarHelper.stripExceptionPrefix(e.toString())}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration({required String label, IconData? icon}) {
    return AppTheme.outlinedInputDecoration(label: label, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.softBg,
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
                'assets/docs/images/logoBLOOD.png',
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
              AppTheme.padding,
              AppTheme.padding,
              AppTheme.padding,
              AppTheme.padding + bottomInset,
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
                              color: AppTheme.deepRed.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.bloodtype,
                              color: AppTheme.deepRed,
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
                          color: AppTheme.fieldFill,
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusSmall,
                          ),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusSmall,
                          ),
                          border: Border.all(
                            color: _isUrgent
                                ? AppTheme.deepRed
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
                              activeTrackColor: AppTheme.deepRed,
                              activeThumbColor: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Hospital location dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedHospitalLocation,
                        decoration: _decoration(
                          label: 'Hospital location',
                          icon: Icons.location_on_outlined,
                        ),
                        items: AppTheme.jordanianGovernorates.map((location) {
                          return DropdownMenuItem<String>(
                            value: location,
                            child: Text(location),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedHospitalLocation = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a location';
                          }
                          return null;
                        },
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
                        child: AsyncElevatedButton(
                          label: 'Create request',
                          isBusy: _isLoading,
                          onPressed: _submit,
                          style: AppTheme.primaryButtonStyle(),
                          minimumSize: const Size.fromHeight(48),
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
