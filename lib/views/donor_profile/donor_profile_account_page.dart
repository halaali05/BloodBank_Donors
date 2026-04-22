import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class DonorProfileAccountPage extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final String email;
  final String? genderLabel;
  final String? phoneDisplay;
  final String? photoUrl;
  final bool avatarUploading;
  final VoidCallback onPickAvatar;
  final bool initialIsEditing;
  final VoidCallback onNameChanged;
  final Future<void> Function() onSave;

  /// The donor's confirmed blood type (e.g. 'A+', 'O-'). Null if not yet set.
  final String? bloodType;

  const DonorProfileAccountPage({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.email,
    this.genderLabel,
    this.phoneDisplay,
    required this.photoUrl,
    required this.avatarUploading,
    required this.initialIsEditing,
    required this.onPickAvatar,
    required this.onNameChanged,
    required this.onSave,
    this.bloodType,
  });

  @override
  State<DonorProfileAccountPage> createState() =>
      _DonorProfileAccountPageState();
}

class _DonorProfileAccountPageState extends State<DonorProfileAccountPage> {
  late bool _isEditing;
  bool _localSaving = false;
  final FocusNode _nameFocusNode = FocusNode();

  Future<void> _handleNameEditAction() async {
    if (_localSaving) return;
    setState(() => _isEditing = true);
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _nameFocusNode.requestFocus();
    });
  }

  Future<void> _handleNameSaveAction() async {
    if (_localSaving) return;
    setState(() => _localSaving = true);
    try {
      await widget.onSave();
      if (!mounted) return;
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _localSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialIsEditing;
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: widget.formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onPickAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppTheme.deepRed.withValues(
                              alpha: 0.12,
                            ),
                            child: ClipOval(
                              child:
                                  (widget.photoUrl != null &&
                                      widget.photoUrl!.isNotEmpty)
                                  ? Image.network(
                                      widget.photoUrl!,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person_rounded,
                                        color: AppTheme.deepRed,
                                        size: 28,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: AppTheme.deepRed,
                                      size: 28,
                                    ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppTheme.deepRed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (widget.avatarUploading)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + blood type badge on same row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.nameController.text.isEmpty
                                      ? 'Donor'
                                      : widget.nameController.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (widget.bloodType != null &&
                                  widget.bloodType!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    '🩸 ${widget.bloodType}',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: widget.email),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Email copied'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                tooltip: 'Copy email',
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: widget.nameController,
                focusNode: _nameFocusNode,
                readOnly: !_isEditing || _localSaving,
                onChanged: (_) => widget.onNameChanged(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter full name',
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFD0D4F0)),
                  ),
                  disabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFD0D4F0)),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit name',
                        onPressed: _handleNameEditAction,
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: AppTheme.deepRed,
                        ),
                      ),
                      if (_isEditing)
                        IconButton(
                          tooltip: 'Save name',
                          onPressed: _localSaving
                              ? null
                              : _handleNameSaveAction,
                          icon: _localSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_rounded,
                                  color: Colors.green,
                                ),
                        ),
                    ],
                  ),
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Name is too short' : null,
              ),
              if (widget.bloodType != null && widget.bloodType!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ReadOnlyAccountField(
                  icon: Icons.bloodtype_rounded,
                  label: 'Blood Type',
                  value: widget.bloodType!,
                ),
              ],
              if (widget.genderLabel != null &&
                  widget.genderLabel!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ReadOnlyAccountField(
                  icon: Icons.wc_outlined,
                  label: 'Gender',
                  value: widget.genderLabel!,
                ),
              ],
              if (widget.phoneDisplay != null &&
                  widget.phoneDisplay!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ReadOnlyAccountField(
                  icon: Icons.phone_android_outlined,
                  label: 'Mobile',
                  value: widget.phoneDisplay!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyAccountField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyAccountField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0D4F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.deepRed, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
