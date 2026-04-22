import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_file_reader.dart';
import 'donor_management_models.dart';

/// Bottom sheet: upload medical report and mark donated vs restricted.
class DonorManagementReportSheet extends StatefulWidget {
  final DonorPipelineRow donor;
  final void Function(
    DonorProcessStatus status,
    String? reason,
    String? notes,
    String? reportFileUrl,
    String? confirmedBloodType,
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
  DonorProcessStatus _outcome = DonorProcessStatus.donated;
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _showValidationErrors = false;
  String? _confirmedBloodType;

  String? _pickedFileName;
  String? _uploadedFileUrl;
  bool _isUploading = false;
  double _uploadProgress = 0;

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
    final isRestricted = _outcome == DonorProcessStatus.restricted;
    final reason = _reasonCtrl.text.trim();
    final hasReasonError = isRestricted && reason.isEmpty;
    final hasFileError = _uploadedFileUrl == null;

    if (hasReasonError || hasFileError) {
      setState(() => _showValidationErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields marked with *'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onSubmit(
      _outcome,
      isRestricted ? reason : null,
      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      _uploadedFileUrl,
      _confirmedBloodType ?? widget.donor.bloodType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRestricted = _outcome == DonorProcessStatus.restricted;
    final hasReasonError =
        isRestricted &&
        _showValidationErrors &&
        _reasonCtrl.text.trim().isEmpty;
    final hasFileError = _showValidationErrors && _uploadedFileUrl == null;

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
                    onTap: () =>
                        setState(() => _outcome = DonorProcessStatus.donated),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DonorReportOutcomeChip(
                    label: '⚠️  Restricted',
                    selected: _outcome == DonorProcessStatus.restricted,
                    color: Colors.orange,
                    onTap: () => setState(
                      () => _outcome = DonorProcessStatus.restricted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirmed Blood Type *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _confirmedBloodType ?? widget.donor.bloodType,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.softBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                prefixIcon: const Icon(
                  Icons.bloodtype_rounded,
                  color: AppTheme.deepRed,
                  size: 20,
                ),
              ),
              hint: const Text('Select blood type'),
              items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        t,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _confirmedBloodType = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Medical Report File *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
              hasFileError
                  ? 'Required — attach PDF, JPG, or PNG'
                  : 'Required — PDF, JPG, or PNG',
              style: TextStyle(
                color: hasFileError ? Colors.red : Colors.black45,
                fontSize: 11,
                fontWeight: hasFileError ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 14),
            if (isRestricted) ...[
              TextField(
                controller: _reasonCtrl,
                onChanged: (_) {
                  if (_showValidationErrors) setState(() {});
                },
                decoration:
                    AppTheme.outlinedInputDecoration(
                      label: 'Restriction Reason *',
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
                  backgroundColor: isRestricted
                      ? Colors.orange[700]
                      : Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                  isRestricted
                      ? Icons.block_rounded
                      : Icons.check_circle_rounded,
                ),
                label: Text(
                  isRestricted ? 'Submit & Restrict Donor' : 'Confirm Donation',
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
