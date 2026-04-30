import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../controllers/donor_profile_controller.dart';
import '../../models/donor_medical_report.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/error_message_helper.dart';
import '../../shared/utils/platform_file_reader.dart';
import '../../shared/utils/snack_bar_helper.dart';
import 'donor_eligibility_screen.dart';
import 'donor_profile_account_page.dart';
import 'donor_profile_donation_history_page.dart';
import 'donor_profile_menu_tile.dart';
import 'donor_profile_reports_page.dart';
import 'donor_profile_donation_restrictions_page.dart';

/// Donor profile hub: account, eligibility, history, reports, restrictions.
///
/// Reads and writes use Cloud Functions. Some tabs poll or reload when you come back.
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
  Future<List<DonorMedicalReport>>? _historyLoadFuture;
  Future<List<DonorMedicalReport>>? _reportsLoadFuture;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  void _scheduleSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }

  Future<User?> _waitForCurrentUser() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;
    try {
      return await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return FirebaseAuth.instance.currentUser;
    }
  }

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
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadUserProfile();
        _loadDonationHistory();
      });
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

    _scheduleSetState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _controller.fetchUserProfile();
      if (!mounted) return;
      _scheduleSetState(() {
        _userData = userData;
        _isLoading = false;
        _initOnce(userData);
      });
    } catch (e) {
      if (!mounted) return;
      _scheduleSetState(() {
        _error = ErrorMessageHelper.humanize(e);
        _isLoading = false;
      });
    }
  }

  Future<List<DonorMedicalReport>> _reloadDonationHistoryList({
    bool includeActiveProgress = true,
  }) {
    if (!mounted) return Future.value(_donationHistory);

    final existingFuture = includeActiveProgress
        ? _historyLoadFuture
        : _reportsLoadFuture;
    if (existingFuture != null) return existingFuture;

    _scheduleSetState(
      () => _historyLoading = includeActiveProgress || _donationHistory.isEmpty,
    );
    final future = _waitForCurrentUser()
        .then((user) {
          if (user == null) throw Exception('Please log in first');
          return user.getIdToken(true);
        })
        .then(
          (_) => _controller.fetchDonationHistory(
            includeActiveProgress: includeActiveProgress,
          ),
        )
        .then((history) {
          if (!mounted) return _donationHistory;
          _scheduleSetState(() {
            if (includeActiveProgress) {
              _donationHistory = history;
            } else {
              final reportRequestIds = {
                for (final report in history)
                  if (report.requestId.trim().isNotEmpty)
                    report.requestId.trim(),
              };
              final activeProgressRows = _donationHistory.where((report) {
                final hasUploadedReport =
                    report.reportFileUrl != null &&
                    report.reportFileUrl!.trim().isNotEmpty;
                if (hasUploadedReport) return false;
                final requestId = report.requestId.trim();
                return requestId.isEmpty ||
                    !reportRequestIds.contains(requestId);
              });
              _donationHistory = [...history, ...activeProgressRows]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            }
            _historyLoading = false;
          });
          return history;
        })
        .catchError((e) {
          debugPrint('loadDonationHistory: $e');
          if (!mounted) return _donationHistory;
          _scheduleSetState(() => _historyLoading = false);
          if (!includeActiveProgress) throw e;
          return _donationHistory;
        })
        .whenComplete(() {
          if (includeActiveProgress) {
            _historyLoadFuture = null;
          } else {
            _reportsLoadFuture = null;
          }
        });

    if (includeActiveProgress) {
      _historyLoadFuture = future;
    } else {
      _reportsLoadFuture = future;
    }
    return future;
  }

  Future<List<DonorMedicalReport>> _reloadReportsList() {
    return _reloadDonationHistoryList(includeActiveProgress: false);
  }

  Future<void> _loadDonationHistory() async {
    await _reloadDonationHistoryList();
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

  String? _locationFromData() {
    final m = _userData;
    if (m == null) return null;
    final location = (m['location'] ?? '').toString().trim();
    return location.isEmpty ? null : location;
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
        SnackBarHelper.failure(
          context,
          'Image is too large. Please choose one under 6 MB.',
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
        SnackBarHelper.failure(context, 'Could not read this image. Try another one.');
        return;
      }

      setState(() => _avatarUploading = true);
      final ext = (picked.extension ?? 'jpg').toLowerCase();

      final url =
          await _controller.uploadProfileAvatarBytes(bytes: bytes, extension: ext);

      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _profileUpdated = true;
      });
      SnackBarHelper.success(context, 'Profile picture updated');
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.failureFrom(context, e);
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

      SnackBarHelper.success(context, 'Profile updated successfully');
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.failureFrom(context, e);
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
                              const SizedBox(height: 4),
                              // Blood type badge (shown once hospital confirms it)
                              Builder(
                                builder: (_) {
                                  final bt = (_userData?['bloodType'] ?? '')
                                      .toString()
                                      .trim();
                                  if (bt.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Blood type: not confirmed',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.78,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        bt,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
                                        SnackBarHelper.success(
                                          context,
                                          'Email copied',
                                          duration:
                                              const Duration(seconds: 1),
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
                              if (_locationFromData() != null) ...[
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
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _locationFromData()!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                            location: _locationFromData(),
                            photoUrl: _photoUrl,
                            avatarUploading: _avatarUploading,
                            initialIsEditing: _isEditing,
                            onPickAvatar: _pickAndUploadAvatar,
                            onNameChanged: () => setState(() {}),
                            onSave: _save,
                            bloodType: () {
                              final bt = (_userData?['bloodType'] ?? '')
                                  .toString()
                                  .trim();
                              return bt.isEmpty ? null : bt;
                            }(),
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
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => DonorProfileDonationHistoryPage(
                                initialReports: _donationHistory,
                                initialLoading: _historyLoading,
                                reloadReports: _reloadDonationHistoryList,
                              ),
                            ),
                          )
                          .then((_) {
                            if (mounted) _loadDonationHistory();
                          });
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
                            initialReports: _donationHistory,
                            initialLoading: _historyLoading,
                            reloadReports: _reloadReportsList,
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
