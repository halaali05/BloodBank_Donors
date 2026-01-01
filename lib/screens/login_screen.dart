import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as models;
import 'register_screen.dart';
import 'donor_dashboard_screen.dart';
import 'blood_bank_dashboard_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _primaryColor = Color(0xffe60012);
  static const Color _fieldFill = Color(0xfff8f9ff);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ------------------ resend verification ------------------

  Future<void> _resendVerification() async {
    try {
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
          desc: 'Please enter your email and password first.',
          btnOkOnPress: () {},
        ).show();
        return;
      }

      await _authService.login(email: email, password: password);
      await _authService.resendEmailVerification();

      if (!mounted) return;
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.bottomSlide,
        customHeader: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.green,
          child: const Icon(Icons.check_circle, color: Colors.white, size: 30),
        ),
        title: 'Verification email sent',
        desc: 'We sent you a new verification email. Please check your inbox.',
        btnOkOnPress: () {},
      ).show();

      await _authService.logout();
    } catch (e) {
      if (!mounted) return;
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        customHeader: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.red,
          child: const Icon(Icons.error_outline, color: Colors.white, size: 30),
        ),
        title: 'Error',
        desc:
            'Something went wrong while sending the verification email. Please try again.',
        btnOkOnPress: () {},
      ).show();
    }
  }

  // ------------------ login ------------------

  Future<void> _login() async {
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

    setState(() => _isLoading = true);

    try {
      // 1) login
      await _authService.login(email: email, password: password);

      // 2) check verification
      final isVerified = await _authService.isEmailVerified();
      if (!isVerified) {
        if (!mounted) return;

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
          title: 'Email not verified',
          desc: 'Please verify your email before logging in.',
          btnOkOnPress: () {},
        ).show();

        await _authService.logout();
        return;
      }

      // 3) current user
      final user = _authService.currentUser;
      print('LOGIN UID = ${user?.uid}');

      if (user == null) {
        if (!mounted) return;

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.bottomSlide,
          customHeader: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.red,
            child: const Icon(Icons.error_outline, color: Colors.white, size: 30),
          ),
          title: 'Error',
          desc: 'We could not load your account information. Please try again.',
          btnOkOnPress: () {},
        ).show();

        await _authService.logout();
        return;
      }

      // 4) try complete profile after verification (won't block login)
      try {
        await _authService.completeProfileAfterVerification();
      } catch (e) {
        // ممكن يفشل إذا كان البروفايل جاهز أصلاً أو pending مش موجود
        print('completeProfileAfterVerification skipped/failed: $e');
      }

      // 5) fetch user profile with retry (Firestore may lag briefly after write)
      models.User? userData;
      for (int i = 0; i < 5; i++) {
        userData = await _authService.getUserData(user.uid);
        if (userData != null) break;
        await Future.delayed(const Duration(milliseconds: 600));
      }

      if (userData == null) {
        if (!mounted) return;

        AwesomeDialog(
          context: context,
          dialogType: DialogType.info,
          animType: AnimType.bottomSlide,
          customHeader: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.info_outline, color: Colors.white, size: 30),
          ),
          title: 'Profile not ready',
          desc:
              'Your email is verified, but your profile is still being prepared. '
              'Please wait a few seconds and try logging in again.',
          btnOkOnPress: () {},
        ).show();

        await _authService.logout();
        return;
      }

      if (!mounted) return;

      // 6) route by role
      if (userData.role == models.UserRole.donor) {
        final name = userData.fullName ?? 'Donor';
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => DonorDashboardScreen(donorName: name)),
          (route) => false,
        );
      } else if (userData.role == models.UserRole.hospital) {
        final bloodBankName = userData.bloodBankName ?? 'Blood Bank';
        final location = userData.location ?? 'Unknown';
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BloodBankDashboardScreen(
              bloodBankName: bloodBankName,
              location: location,
            ),
          ),
          (route) => false,
        );
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.bottomSlide,
          customHeader: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.red,
            child: const Icon(Icons.error_outline, color: Colors.white, size: 30),
          ),
          title: 'Account issue',
          desc: 'Your account type is not set up correctly. Please contact support.',
          btnOkOnPress: () {},
        ).show();
        await _authService.logout();
      }
    } catch (e) {
      if (!mounted) return;

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        customHeader: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.red,
          child: const Icon(Icons.error_outline, color: Colors.white, size: 30),
        ),
        title: 'Login failed',
        desc: 'Something went wrong while logging you in. Please try again.',
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: _fieldFill,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xffffe3e6),
                      child: Icon(
                        Icons.favorite,
                        color: Color(0xffe60012),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hayat',
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Donate blood, save a Hayat',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ],
                ),
              ),

              Container(
                width: 420,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration(
                        label: 'Email',
                        prefixIcon: Icons.mail_outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _decoration(
                        label: 'Password',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading ? null : _resendVerification,
                      child: const Text('Resend verification email'),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                      child: const Text('Forgot password?'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: _goToRegister,
                        child: Text.rich(
                          TextSpan(
                            text: "Don't have an account? ",
                            style: const TextStyle(fontSize: 13),
                            children: [
                              TextSpan(
                                text: 'Create one',
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
