import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

enum UserType { donor, bloodBank }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // نفس لون صفحة الـ Login (أحمر غامق جداً)
  static const Color deepRed = Color(0xFF7A0009);
  static const Color lineColor = Color(0xFFBFC7D2);

  final _authService = AuthService();
  UserType _type = UserType.donor;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hospitalNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hospitalNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email.trim());
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
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
        title: 'Missing information',
        desc: 'Please enter both email and password.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    if (!_isValidEmail(email)) {
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
        title: 'Invalid email',
        desc: 'Please enter a valid email address.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    if (password.length < 6) {
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
        title: 'Weak password',
        desc: 'Password must be at least 6 characters.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
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
        title: 'Password mismatch',
        desc: 'The passwords do not match. Please try again.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    if (_type == UserType.donor && _nameController.text.trim().isEmpty) {
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
        title: 'Missing name',
        desc: 'Please enter your full name.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    if (_type == UserType.bloodBank &&
        _hospitalNameController.text.trim().isEmpty) {
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
        title: 'Missing blood bank name',
        desc: 'Please enter blood bank name.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    if (_type == UserType.bloodBank &&
        _locationController.text.trim().isEmpty) {
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
        title: 'Missing location',
        desc: 'Please enter location.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> result;

      if (_type == UserType.donor) {
        final name = _nameController.text.trim();
        const String bloodType = 'A+';
        const String location = 'Unknown';

        result = await _authService.signUpDonor(
          fullName: name,
          email: email,
          password: password,
          bloodType: bloodType,
          location: location,
        );
      } else {
        final bloodBankName = _hospitalNameController.text.trim();
        final location = _locationController.text.trim();

        result = await _authService.signUpBloodBank(
          bloodBankName: bloodBankName,
          email: email,
          password: password,
          location: location,
        );
      }

      if (!mounted) return;

      final emailVerified = result['emailVerified'] ?? false;

      if (emailVerified) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.bottomSlide,
          customHeader: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green,
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 30,
            ),
          ),
          title: 'Account created',
          desc:
              'Your account has been created successfully. You can now log in.',
          btnOkOnPress: () async {
            await _authService.logout();
            if (!mounted) return;
            Navigator.of(context).pop();
          },
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.info,
          animType: AnimType.bottomSlide,
          customHeader: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.email, color: Colors.white, size: 30),
          ),
          title: 'Verification email sent',
          desc:
              'We sent you a verification email. Please check your inbox and click the link to verify your email.',
          btnOkOnPress: () async {
            await _authService.logout();
            if (!mounted) return;
            Navigator.of(context).pop();
          },
        ).show();
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage =
          'Something went wrong while creating your account. Please try again.';
      String errorTitle = 'Sign up failed';

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorTitle = 'Email already in use';
            errorMessage =
                'This email address is already registered. Try logging in.';
            break;
          case 'weak-password':
            errorTitle = 'Password too weak';
            errorMessage = 'Use at least 6 characters.';
            break;
          case 'invalid-email':
            errorTitle = 'Invalid email address';
            errorMessage = 'Please enter a correct email.';
            break;
          case 'network-request-failed':
            errorTitle = 'Network error';
            errorMessage = 'Check your internet and try again.';
            break;
          default:
            errorTitle = 'Registration failed';
        }
      }

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        customHeader: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.red,
          child: const Icon(Icons.error_outline, color: Colors.white, size: 30),
        ),
        title: errorTitle,
        desc: errorMessage,
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _underlineDeco({
    required String hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey[700]) : null,
      suffixIcon: suffix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: lineColor, width: 1),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: deepRed, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: 360,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE6EAF2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SIGN UP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: deepRed,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Toggle (بسيط) - إذا بدك أشيله احكيلي
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xfff4f5fb),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _type = UserType.donor),
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _type == UserType.donor
                                    ? deepRed
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Donor',
                                style: TextStyle(
                                  color: _type == UserType.donor
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _type = UserType.bloodBank),
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _type == UserType.bloodBank
                                    ? deepRed
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Blood bank',
                                style: TextStyle(
                                  color: _type == UserType.bloodBank
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Username / Full name (حسب النوع)
                  if (_type == UserType.donor)
                    TextField(
                      controller: _nameController,
                      decoration: _underlineDeco(
                        hint: 'Username',
                        icon: Icons.person_outline,
                      ),
                    ),

                  if (_type == UserType.bloodBank)
                    TextField(
                      controller: _hospitalNameController,
                      decoration: _underlineDeco(
                        hint: 'Blood bank name',
                        icon: Icons.local_hospital_outlined,
                      ),
                    ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _underlineDeco(
                      hint: 'E-Mail',
                      icon: Icons.mail_outline,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _underlineDeco(
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey[700],
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: _underlineDeco(
                      hint: 'Confirm Password',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey[700],
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                  ),

                  if (_type == UserType.bloodBank) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: _underlineDeco(
                        hint: 'Location',
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // زر مثل الصورة (أبيض وحدود)
                  SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: deepRed,
                        side: const BorderSide(color: deepRed, width: 1.5),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Already have an account? Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: deepRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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
