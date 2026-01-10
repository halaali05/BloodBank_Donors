import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../controllers/donor_profile_controller.dart';
import '../theme/app_theme.dart';

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

  // Form and state
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  bool _isEditing = false; // Whether profile is in edit mode
  bool _saving = false; // Show loading while saving
  bool _didInit = false; // Track if form has been initialized
  Timer? _refreshTimer;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  /// Get current user's UID
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    // Set up periodic refresh (every 30 seconds) for real-time updates
    // Increased interval to improve performance
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadUserProfile();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _name.dispose();
    super.dispose();
  }

  /// Loads user profile data via Cloud Functions
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

  /// Initializes form fields once with data from Cloud Functions
  /// Prevents overwriting user input if data updates
  void _initOnce(Map<String, dynamic> data) {
    if (_didInit) return;
    _didInit = true;
    _name.text = (data['name'] ?? data['fullName'] ?? '').toString();
  }

  /// Saves profile changes via Cloud Functions
  ///
  /// Flow:
  /// 1. Validates form
  /// 2. Calls Cloud Function to update profile (server-side)
  /// 3. Shows success/error message
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final newName = _name.text.trim();

      // Update profile via Cloud Function (server-side)
      await _controller.updateProfileName(name: newName);

      // Refresh profile data after update
      await _loadUserProfile();

      if (!mounted) return;
      setState(() => _isEditing = false);

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
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit,
              color: AppTheme.deepRed,
            ),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
          const SizedBox(width: 6),
        ],
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
              onRefresh: _loadUserProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.deepRed.withOpacity(
                                  0.12,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.deepRed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name.text.isEmpty ? 'Donor' : _name.text,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email ?? '',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _name,
                          enabled: _isEditing && !_saving,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v ?? '').trim().length < 2
                              ? 'Name is too short'
                              : null,
                        ),

                        const SizedBox(height: 14),

                        if (_isEditing)
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              style: AppTheme.primaryButtonStyle(
                                borderRadius: 999,
                              ),
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save changes'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
