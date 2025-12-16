import 'package:flutter/material.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String code;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  bool _loading = false;

  /// Handles password reset (UI only - not connected to backend)
  ///
  /// Validates that both password fields are filled and that they match.
  /// Currently this is a UI-only implementation that simulates the reset process.
  ///
  /// Shows error messages via SnackBar if validation fails.
  /// On success, navigates back to the first screen in the navigation stack.
  ///
  /// Note: This is a placeholder implementation and should be connected
  /// to Firebase Auth's password reset functionality in production.
  Future<void> _resetUiOnly() async {
    final p1 = _pass1.text;
    final p2 = _pass2.text;

    if (p1.isEmpty || p2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter both fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (p1 != p2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    // ✅ UI ONLY
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password updated (UI only).'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Reset password for ${widget.email}'),
            const SizedBox(height: 12),
            TextField(
              controller: _pass1,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _resetUiOnly,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Update password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
