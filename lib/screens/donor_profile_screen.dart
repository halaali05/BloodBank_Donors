import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/donor_profile_controller.dart';
import '../models/donor_medical_report.dart';
import '../theme/app_theme.dart';
import '../utils/platform_file_reader.dart';
import '../widgets/donation_history_section.dart';

/// Screen where donors can view and edit their profile information
///
/// SECURITY ARCHITECTURE:
/// - Read operations: All go through Cloud Functions (server-side)
///   - Profile data: Read via getUserData Cloud Function
/// - Write operations: All go through Cloud Functions (server-side)
///   - Profile updates: Uses updateUserProfile Cloud Function
///
/// NOTE: Real-time updates are achieved through periodic polling (every 10 seconds)
/// since Cloud Functions cannot return real-time streams.
class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  final DonorProfileController _controller = DonorProfileController();

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  bool _isEditing = false;
  bool _saving = false;
  bool _didInit = false;
  bool _profileUpdated = false;
  Timer? _refreshTimer;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;
  String? _photoUrl;
  bool _avatarUploading = false;

  List<DonorMedicalReport> _donationHistory = [];
  bool _historyLoading = true;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    FirebaseAuth.instance.authStateChanges().first.then((user) {
      if (user != null && mounted) {
        _loadDonationHistory();
      }
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadUserProfile();
        _loadDonationHistory();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _controller.fetchUserProfile();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
          _initOnce(userData);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDonationHistory() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await user.getIdToken();

    setState(() => _historyLoading = true);
    try {
      final history = await _controller.fetchDonationHistory();
      if (mounted) {
        setState(() {
          _donationHistory = history;
          _historyLoading = false;
        });
      }
    } catch (e) {
      print('loadDonationHistory: $e');
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  String? _genderLabelFromData() {
    final m = _userData;
    if (m == null) return null;
    final g = (m['gender'] ?? '').toString().toLowerCase();
    if (g == 'male') return 'Male';
    if (g == 'female') return 'Female';
    return null;
  }

  String? _phoneFromData() {
    final m = _userData;
    if (m == null) return null;
    final p = (m['phoneNumber'] ?? m['phone'] ?? '').toString().trim();
    return p.isEmpty ? null : p;
  }

  void _initOnce(Map<String, dynamic> data) {
    if (_didInit) return;
    _didInit = true;
    _name.text = (data['name'] ?? data['fullName'] ?? '').toString();
    _photoUrl =
        (data['photoURL'] ??
                data['photoUrl'] ??
                data['avatarUrl'] ??
                FirebaseAuth.instance.currentUser?.photoURL)
            ?.toString();
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_avatarUploading) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: kIsWeb,
        withReadStream: !kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      if (picked.size > 6 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image is too large. Please choose one under 6 MB.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Uint8List? bytes;
      if (!kIsWeb && picked.path != null) {
        try {
          bytes = await File(picked.path!).readAsBytes();
        } catch (_) {
          bytes = await readPlatformFileBytes(picked);
        }
      } else {
        bytes = await readPlatformFileBytes(picked);
      }

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read this image. Try another one.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _avatarUploading = true);
      final ext = (picked.extension ?? 'jpg').toLowerCase();
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';

      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        throw Exception('You are not authenticated. Please login again.');
      }
      final uid = currentUser.uid;

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(uid)
          .child('avatar_${DateTime.now().millisecondsSinceEpoch}.$ext');

      final snap = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await snap.ref.getDownloadURL();

      await currentUser.updatePhotoURL(url);

      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _profileUpdated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Authentication error while uploading image: ${e.message ?? e.code}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final isAuthError =
          e.code.toLowerCase().contains('unauth') ||
          e.code.toLowerCase().contains('permission') ||
          e.message?.toLowerCase().contains('unauth') == true ||
          e.message?.toLowerCase().contains('permission') == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAuthError
                ? 'Upload failed: image permission is blocked by storage rules. Please contact support.'
                : 'Upload failed: ${e.message ?? e.code}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final newName = _name.text.trim();
      await _controller.updateProfileName(name: newName);
      await _loadUserProfile();

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _profileUpdated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _profileUpdated),
        ),
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _isLoading && _userData == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(
                      'Error: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadUserProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserProfile();
                await _loadDonationHistory();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7A0009), Color(0xFFB71C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                          child: ClipOval(
                            child: _photoUrl != null && _photoUrl!.isNotEmpty
                                ? Image.network(
                                    _photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                _name.text.isEmpty ? 'Donor' : _name.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        user.email ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: user.email ?? ''),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Email copied'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 16,
                                      color: Colors.white,
                                      icon: const Icon(Icons.copy_rounded),
                                      tooltip: 'Copy email',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProfileMenuTile(
                    index: '| 01 |',
                    title: 'Account',
                    icon: Icons.manage_accounts_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _AccountPage(
                            formKey: _formKey,
                            nameController: _name,
                            email: user.email ?? '',
                            genderLabel: _genderLabelFromData(),
                            phoneDisplay: _phoneFromData(),
                            photoUrl: _photoUrl,
                            avatarUploading: _avatarUploading,
                            initialIsEditing: _isEditing,
                            saving: _saving,
                            onPickAvatar: _pickAndUploadAvatar,
                            onNameChanged: () => setState(() {}),
                            onSave: _save,
                          ),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuTile(
                    index: '| 02 |',
                    title: 'Donation History',
                    icon: Icons.history_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _DonationHistoryPage(
                            reports: _donationHistory,
                            isLoading: _historyLoading,
                          ),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuTile(
                    index: '| 03 |',
                    title: 'Reports',
                    icon: Icons.description_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ReportsPage(
                            reports: _donationHistory,
                            isLoading: _historyLoading,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final String index;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.index,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.deepRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            index,
            style: const TextStyle(
              color: AppTheme.deepRed,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: Icon(icon, color: Colors.black54),
      ),
    );
  }
}

class _AccountPage extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final String email;
  final String? genderLabel;
  final String? phoneDisplay;
  final String? photoUrl;
  final bool avatarUploading;
  final bool saving;
  final VoidCallback onPickAvatar;
  final bool initialIsEditing;
  final VoidCallback onNameChanged;
  final Future<void> Function() onSave;

  const _AccountPage({
    required this.formKey,
    required this.nameController,
    required this.email,
    this.genderLabel,
    this.phoneDisplay,
    required this.photoUrl,
    required this.avatarUploading,
    required this.initialIsEditing,
    required this.saving,
    required this.onPickAvatar,
    required this.onNameChanged,
    required this.onSave,
  });

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
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
                            backgroundColor: AppTheme.deepRed.withOpacity(0.12),
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
                          Text(
                            widget.nameController.text.isEmpty
                                ? 'Donor'
                                : widget.nameController.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
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

class _DonationHistoryPage extends StatelessWidget {
  final List<DonorMedicalReport> reports;
  final bool isLoading;

  const _DonationHistoryPage({required this.reports, required this.isLoading});

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
          'Donation History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DonationHistorySection(reports: reports, isLoading: isLoading),
        ],
      ),
    );
  }
}

class _ReportsPage extends StatelessWidget {
  final List<DonorMedicalReport> reports;
  final bool isLoading;

  const _ReportsPage({required this.reports, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final uploadedReports = reports
        .where((r) => r.reportFileUrl != null && r.reportFileUrl!.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRed),
            )
          : uploadedReports.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 34,
                      color: Colors.black38,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No reports uploaded yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: uploadedReports.length,
              itemBuilder: (_, i) {
                final report = uploadedReports[i];
                final status = donorProcessStatusToString(report.status);
                final hasNotes =
                    report.notes != null && report.notes!.trim().isNotEmpty;

                final isRestricted =
                    status.toLowerCase().contains('restricted') ||
                    status.toLowerCase().contains('not eligible');

                final statusColor = isRestricted ? Colors.orange : Colors.green;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${report.bloodType} Report',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  report.bloodBankName,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: isRestricted
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (hasNotes) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            report.notes!.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final url = Uri.parse(report.reportFileUrl!);
                              await launchUrl(
                                url,
                                mode: LaunchMode.inAppBrowserView,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.deepRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text(
                            'View Report',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
