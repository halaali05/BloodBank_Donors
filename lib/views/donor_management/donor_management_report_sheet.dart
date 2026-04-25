import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_file_reader.dart';
import 'donor_management_models.dart';

/// Sub-type when outcome is rejected.
enum RejectionSubType { permanentBlock, otherReasons }

/// Bottom sheet: upload medical report and mark donated vs rejected.
class DonorManagementReportSheet extends StatefulWidget {
  final DonorPipelineRow donor;
  final void Function(
    DonorProcessStatus status,
    String? reason,
    String? notes,
    String reportFileUrl,
    String confirmedBloodType,
    RejectionSubType? rejectionSubType,
  )
  onSubmit;

  const DonorManagementReportSheet({
    super.key,
    required this.donor,
    required this.onSubmit,
  });

  @override
  State<DonorManagementReportSheet> createState() =>
      _DonorManagementReportSheetState();
}

class _DonorManagementReportSheetState
    extends State<DonorManagementReportSheet> {
  static const List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  DonorProcessStatus _outcome = DonorProcessStatus.donated;
  RejectionSubType? _rejectionSubType;
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _showValidationErrors = false;

  /// Prefilled from donor information when a previous confirmed blood type exists.
  String? _selectedBloodType;

  String? _pickedFileName;
  String? _uploadedFileUrl;
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _selectedBloodType = _knownDonorBloodType();
  }

  String? _knownDonorBloodType() {
    final profileBloodType = _normalizeBloodType(widget.donor.bloodType);
    if (profileBloodType != null) {
      return profileBloodType;
    }

    final reportBloodType = _normalizeBloodType(
      widget.donor.latestMedicalReport?.bloodType,
    );
    if (reportBloodType != null) {
      return reportBloodType;
    }

    return null;
  }

  String? _normalizeBloodType(String? value) {
    final normalized = value?.trim().toUpperCase().replaceAll(' ', '');
    if (normalized == null || !_bloodTypes.contains(normalized)) return null;
    return normalized;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: kIsWeb,
        withReadStream: !kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final bytes = await readPlatformFileBytes(picked);

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read this file. Try another PDF/image or pick from Downloads.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _pickedFileName = picked.name;
        _isUploading = true;
        _uploadProgress = 0;
        _uploadedFileUrl = null;
      });

      final ext = (picked.extension ?? '').toLowerCase();

      var contentType = 'application/octet-stream';
      if (ext == 'pdf') {
        contentType = 'application/pdf';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == 'png') {
        contentType = 'image/png';
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';

      final ref = FirebaseStorage.instance
          .ref()
          .child('medical_reports')
          .child(widget.donor.donorId)
          .child(fileName);

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;

        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;

        if (total > 0) {
          setState(() {
            _uploadProgress = transferred / total;
          });
        }

        debugPrint('UPLOAD STATE: ${snapshot.state} | $transferred / $total');
      });

      final snap = await uploadTask;
      final downloadUrl = await snap.ref.getDownloadURL();

      if (!mounted) return;

      setState(() {
        _uploadedFileUrl = downloadUrl;
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      debugPrint('UPLOAD SUCCESS URL: $downloadUrl');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, st) {
      debugPrint('UPLOAD ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _pickedFileName = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitReport() {
    final isRejected = _outcome == DonorProcessStatus.restricted;
    final isOtherReasons =
        isRejected && _rejectionSubType == RejectionSubType.otherReasons;
    final knownBloodType = _knownDonorBloodType();
    final effectiveBloodType = knownBloodType ?? _selectedBloodType;
    final reason = _reasonCtrl.text.trim();
    final hasReasonError = isRejected && reason.isEmpty;
    final hasSubTypeError = isRejected && _rejectionSubType == null;
    // نوع الدم والتقرير إجباريين فقط للـ Donated والـ Permanent Block
    final hasFileError = !isOtherReasons && _uploadedFileUrl == null;
    final hasBloodError =
        !isOtherReasons &&
        (effectiveBloodType == null ||
            !_bloodTypes.contains(effectiveBloodType));

    if (hasReasonError || hasSubTypeError || hasFileError || hasBloodError) {
      setState(() => _showValidationErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasBloodError
                ? 'Select the confirmed blood type from the list.'
                : hasSubTypeError
                ? 'Please select a rejection type.'
                : 'Please fill all required fields marked with *',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // للـ Other Reasons: نمرر null للـ fileUrl والـ blood لو ما اتحددوا
    final fileUrl = isOtherReasons
        ? (_uploadedFileUrl ?? '')
        : _uploadedFileUrl!;
    final blood = isOtherReasons
        ? (effectiveBloodType ?? '')
        : effectiveBloodType!;

    widget.onSubmit(
      _outcome,
      isRejected ? reason : null,
      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      fileUrl,
      blood,
      isRejected ? _rejectionSubType : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = _outcome == DonorProcessStatus.restricted;
    final isOtherReasons =
        isRejected && _rejectionSubType == RejectionSubType.otherReasons;
    final hasSubTypeError =
        isRejected && _showValidationErrors && _rejectionSubType == null;
    final hasReasonError =
        isRejected && _showValidationErrors && _reasonCtrl.text.trim().isEmpty;
    final hasFileError =
        !isOtherReasons && _showValidationErrors && _uploadedFileUrl == null;
    final knownBloodType = _knownDonorBloodType();
    final effectiveBloodType = knownBloodType ?? _selectedBloodType;
    final hasBloodError =
        !isOtherReasons &&
        _showValidationErrors &&
        (effectiveBloodType == null ||
            !_bloodTypes.contains(effectiveBloodType));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Upload Report — ${widget.donor.fullName}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              widget.donor.email,
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.bloodtype_rounded,
                  size: 15,
                  color: AppTheme.deepRed.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  (widget.donor.bloodType?.trim().isNotEmpty ?? false)
                      ? widget.donor.bloodType!.trim()
                      : 'Blood type not on file',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: (widget.donor.bloodType?.trim().isNotEmpty ?? false)
                        ? Colors.black87
                        : Colors.black45,
                  ),
                ),
              ],
            ),
            if (widget.donor.phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.donor.phoneNumber,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Donation Outcome',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DonorReportOutcomeChip(
                    label: '✅  Donated',
                    selected: _outcome == DonorProcessStatus.donated,
                    color: Colors.green,
                    onTap: () => setState(() {
                      _outcome = DonorProcessStatus.donated;
                      _rejectionSubType = null;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DonorReportOutcomeChip(
                    label: '🚫  Rejected',
                    selected: _outcome == DonorProcessStatus.restricted,
                    color: Colors.red,
                    onTap: () => setState(
                      () => _outcome = DonorProcessStatus.restricted,
                    ),
                  ),
                ),
              ],
            ),
            // Sub-type selection shown only when Rejected is selected
            if (isRejected) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasSubTypeError
                      ? Colors.red.shade50
                      : Colors.red.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasSubTypeError
                        ? Colors.red.shade400
                        : Colors.red.shade200,
                    width: hasSubTypeError ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSubTypeError
                          ? 'Select rejection type *'
                          : 'Rejection Type *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasSubTypeError
                            ? Colors.red.shade700
                            : Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _RejectionSubTypeChip(
                            label: '🚫  Permanent Block',
                            sublabel: 'Cannot donate ever',
                            selected:
                                _rejectionSubType ==
                                RejectionSubType.permanentBlock,
                            onTap: () => setState(
                              () => _rejectionSubType =
                                  RejectionSubType.permanentBlock,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RejectionSubTypeChip(
                            label: '⚠️  Other Reasons',
                            sublabel: 'Temporary / other',
                            selected:
                                _rejectionSubType ==
                                RejectionSubType.otherReasons,
                            onTap: () => setState(
                              () => _rejectionSubType =
                                  RejectionSubType.otherReasons,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // ✅ FIX: removed `const` — isOtherReasons is a runtime variable
            Text(
              isOtherReasons
                  ? 'Confirmed Blood Type (optional)'
                  : 'Confirmed Blood Type *',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              // Controlled selection so known donor blood type is submitted automatically.
              // ignore: deprecated_member_use
              value: effectiveBloodType,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.softBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: hasBloodError ? Colors.red : Colors.black12,
                    width: hasBloodError ? 1.4 : 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: hasBloodError ? Colors.red : Colors.black12,
                    width: hasBloodError ? 1.4 : 1,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.bloodtype_rounded,
                  color: AppTheme.deepRed,
                  size: 20,
                ),
              ),
              hint: Text(
                knownBloodType != null
                    ? 'Blood type from donor information'
                    : 'Select blood type *',
              ),
              items: [
                if (knownBloodType == null)
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      '— Select blood type —',
                      style: TextStyle(
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ..._bloodTypes.map(
                  (t) => DropdownMenuItem<String?>(
                    value: t,
                    child: Text(
                      t,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              onChanged: knownBloodType == null
                  ? (v) => setState(() => _selectedBloodType = v)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              hasBloodError
                  ? 'Choose the lab-confirmed blood type'
                  : knownBloodType != null
                  ? 'Locked from donor information'
                  : 'Must match the medical report',
              style: TextStyle(
                color: hasBloodError
                    ? Colors.red
                    : knownBloodType != null
                    ? Colors.green.shade700
                    : Colors.black45,
                fontSize: 11,
                fontWeight: hasBloodError || knownBloodType != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 16),
            // ✅ FIX: removed `const` — isOtherReasons is a runtime variable
            Text(
              isOtherReasons
                  ? 'Medical Report File (optional)'
                  : 'Medical Report File *',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isUploading ? null : _pickAndUploadFile,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _uploadedFileUrl != null
                      ? Colors.green.withValues(alpha: 0.06)
                      : AppTheme.softBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _uploadedFileUrl != null
                        ? Colors.green.withValues(alpha: 0.4)
                        : hasFileError
                        ? Colors.red
                        : Colors.black12,
                    width: hasFileError ? 1.4 : 1,
                  ),
                ),
                child: _isUploading
                    ? Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_upload_rounded,
                                color: AppTheme.deepRed,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Uploading ${_pickedFileName ?? 'file'}...',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                '${(_uploadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: AppTheme.deepRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              minHeight: 4,
                              backgroundColor: Colors.black12,
                              color: AppTheme.deepRed,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            _uploadedFileUrl != null
                                ? Icons.check_circle_rounded
                                : Icons.upload_file_rounded,
                            color: _uploadedFileUrl != null
                                ? Colors.green
                                : AppTheme.deepRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _uploadedFileUrl != null
                                  ? _pickedFileName ?? 'File uploaded ✓'
                                  : 'Attach Medical Report (PDF / Image)',
                              style: TextStyle(
                                color: _uploadedFileUrl != null
                                    ? Colors.green[700]
                                    : Colors.black54,
                                fontSize: 13,
                                fontWeight: _uploadedFileUrl != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_uploadedFileUrl != null)
                            GestureDetector(
                              onTap: () => setState(() {
                                _uploadedFileUrl = null;
                                _pickedFileName = null;
                              }),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.black38,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFileError ? 'Attach PDF, JPG, or PNG' : 'PDF, JPG, or PNG',
              style: TextStyle(
                color: hasFileError ? Colors.red : Colors.black45,
                fontSize: 11,
                fontWeight: hasFileError ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 14),
            if (isRejected) ...[
              TextField(
                controller: _reasonCtrl,
                onChanged: (_) {
                  if (_showValidationErrors) setState(() {});
                },
                decoration:
                    AppTheme.outlinedInputDecoration(
                      label: 'Rejection Reason *',
                      icon: Icons.warning_amber_rounded,
                    ).copyWith(
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: hasReasonError ? Colors.red : Colors.black54,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusSmall,
                        ),
                        borderSide: BorderSide(
                          color: hasReasonError
                              ? Colors.red
                              : const Color(0xffd0d4f0),
                          width: hasReasonError ? 1.4 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusSmall,
                        ),
                        borderSide: BorderSide(
                          color: hasReasonError ? Colors.red : AppTheme.deepRed,
                          width: 1.6,
                        ),
                      ),
                    ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _notesCtrl,
              decoration: AppTheme.outlinedInputDecoration(
                label: 'Additional Notes (optional)',
                icon: Icons.notes_rounded,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRejected
                      ? (_rejectionSubType == RejectionSubType.permanentBlock
                            ? Colors.red[800]
                            : Colors.red[600])
                      : Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                  isRejected ? Icons.block_rounded : Icons.check_circle_rounded,
                ),
                label: Text(
                  isRejected
                      ? (_rejectionSubType == RejectionSubType.permanentBlock
                            ? 'Submit & Permanently Block'
                            : 'Submit & Reject Donor')
                      : 'Confirm Donation',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: _isUploading ? null : _submitReport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonorReportOutcomeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const DonorReportOutcomeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.black26,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.black54,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _RejectionSubTypeChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _RejectionSubTypeChip({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.red.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.red.shade600 : Colors.red.shade200,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.red.shade800 : Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.red.shade700 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
