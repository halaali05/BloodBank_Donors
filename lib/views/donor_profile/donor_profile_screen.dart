import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../controllers/donor_profile_controller.dart';
import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_file_reader.dart';
import 'donor_eligibility_screen.dart';
import 'donor_profile_account_page.dart';
import 'donor_profile_donation_history_page.dart';
import 'donor_profile_menu_tile.dart';
import 'donor_profile_reports_page.dart';
import 'donor_profile_donation_restrictions_page.dart';

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
      debugPrint('loadDonationHistory: $e');
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
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
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
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
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
                  DonorProfileMenuTile(
                    index: '| 01 |',
                    title: 'Account',
                    icon: Icons.manage_accounts_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DonorProfileAccountPage(
                            formKey: _formKey,
                            nameController: _name,
                            email: user.email ?? '',
                            genderLabel: _genderLabelFromData(),
                            phoneDisplay: _phoneFromData(),
                            photoUrl: _photoUrl,
                            avatarUploading: _avatarUploading,
                            initialIsEditing: _isEditing,
                            onPickAvatar: _pickAndUploadAvatar,
                            onNameChanged: () => setState(() {}),
                            onSave: _save,
                          ),
                        ),
                      );
                    },
                  ),
                  DonorProfileMenuTile(
                    index: '| 02 |',
                    title: 'Donation History',
                    icon: Icons.history_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DonorProfileDonationHistoryPage(
                            reports: _donationHistory,
                            isLoading: _historyLoading,
                          ),
                        ),
                      );
                    },
                  ),
                  DonorProfileMenuTile(
                    index: '| 03 |',
                    title: 'When can I donate?',
                    icon: Icons.event_available_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DonorEligibilityScreen(),
                        ),
                      );
                    },
                  ),
                  DonorProfileMenuTile(
                    index: '| 04 |',
                    title: 'Reports',
                    icon: Icons.description_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DonorProfileReportsPage(
                            reports: _donationHistory,
                            isLoading: _historyLoading,
                          ),
                        ),
                      );
                    },
                  ),
                  DonorProfileMenuTile(
                    index: '| 05 |',
                    title: 'Donation restrictions',
                    icon: Icons.photo_library_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const DonorProfileDonationRestrictionsPage(),
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
