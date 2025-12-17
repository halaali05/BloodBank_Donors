import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'reset_password_screen.dart';

class VerifyResetCodeScreen extends StatefulWidget {
  final String email;
  const VerifyResetCodeScreen({super.key, required this.email});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final _codeController = TextEditingController();

  void _verifyUiOnly() {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        customHeader: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.orange,
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        title: 'Invalid code',
        desc: 'Please enter the 6 digit code we sent to your email.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    // ✅ UI ONLY: go next
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(email: widget.email, code: code),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Enter the code sent to ${widget.email}'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '6-digit code'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verifyUiOnly,
                child: const Text('Verify'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
