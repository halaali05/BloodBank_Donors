import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
            child: const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 30,
            ),
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
        await _authService.completeProfileAfterVerification().timeout(
          const Duration(seconds: 2),
        );
      } catch (e) {
        // ممكن يفشل إذا كان البروفايل جاهز أصلاً أو pending مش موجود
        print('completeProfileAfterVerification skipped/failed: $e');
      }

      // 5) fetch user profile with retry (Firestore may lag briefly after write)
      models.User? userData;
      for (int i = 0; i < 3; i++) {
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
            child: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 30,
            ),
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
          MaterialPageRoute(
            builder: (_) => DonorDashboardScreen(donorName: name),
          ),
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
            child: const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 30,
            ),
          ),
          title: 'Account issue',
          desc:
              'Your account type is not set up correctly. Please contact support.',
          btnOkOnPress: () {},
        ).show();
        await _authService.logout();
      }
    } catch (e) {
      if (!mounted) return;

      String errorTitle = 'Login failed';
      String errorMessage =
          'Something went wrong while logging you in. Please try again.';

      if (e is FirebaseAuthException) {
        // Specific, clear error messages for each Firebase Auth error
        switch (e.code) {
          case 'user-not-found':
            errorTitle = 'Account not found';
            errorMessage =
                'No account found with this email address. Please check your email or create a new account.';
            break;
          case 'wrong-password':
            errorTitle = 'Incorrect password';
            errorMessage =
                'The password you entered is incorrect. Please check your password and try again.';
            break;
          case 'invalid-email':
            errorTitle = 'Invalid email address';
            errorMessage =
                'The email address you entered is not valid. Please check and enter a correct email address (e.g., example@email.com).';
            break;
          case 'user-disabled':
            errorTitle = 'Account disabled';
            errorMessage =
                'This account has been disabled. Please contact support for assistance.';
            break;
          case 'too-many-requests':
            errorTitle = 'Too many attempts';
            errorMessage =
                'Too many failed login attempts. Please wait a few minutes before trying again.';
            break;
          case 'network-request-failed':
            errorTitle = 'Network error';
            errorMessage =
                'Unable to connect to the server. Please check your internet connection and try again.';
            break;
          case 'operation-not-allowed':
            errorTitle = 'Login disabled';
            errorMessage =
                'Email/password login is currently not available. Please contact support.';
            break;
          case 'invalid-credential':
            errorTitle = 'Invalid credentials';
            errorMessage =
                'The email or password you entered is incorrect. Please check your credentials and try again.';
            break;
          default:
            errorTitle = 'Login failed';
            errorMessage =
                'Unable to log in. Please check your email and password and try again.';
        }
      } else {
        // For Cloud Function errors or other exceptions
        print('❌ Login error caught:');
        print('  Error: $e');
        print('  Error type: ${e.runtimeType}');

        String errorStr = e.toString();

        if (errorStr.contains('Exception: ')) {
          errorMessage = errorStr.replaceFirst('Exception: ', '').trim();

          // Map common errors to specific titles
          if (errorMessage.toLowerCase().contains('network') ||
              errorMessage.toLowerCase().contains('connection')) {
            errorTitle = 'Connection error';
            errorMessage =
                'Unable to connect to the server. Please check your internet connection and try again.';
          } else if (errorMessage.toLowerCase().contains('not found') ||
              errorMessage.toLowerCase().contains('profile')) {
            errorTitle = 'Profile not found';
          } else if (errorMessage.toLowerCase().contains('permission')) {
            errorTitle = 'Permission denied';
          } else {
            errorTitle = 'Login error';
          }
        } else {
          errorTitle = 'Connection error';
          errorMessage =
              'Unable to connect to the server. Please check your internet connection and try again.';
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

  void _goToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
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
    const Color deepRed = Color(0xFF7A0009); // أحمر غامق جداً
    const Color lineColor = Color(0xFFBFC7D2);

    InputDecoration underlineDeco({
      required String hint,
      required IconData icon,
      Widget? suffix,
    }) {
      return InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[700]),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: deepRed.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 48,
                    color: deepRed,
                  ),
                ),

                const SizedBox(height: 22),

                // Username
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: underlineDeco(
                    hint: 'Username',
                    icon: Icons.person_outline,
                  ),
                ),

                const SizedBox(height: 14),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: underlineDeco(
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey[700],
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Log In
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepRed,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Log In',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 8),

                // Resend verification
                TextButton(
                  onPressed: _isLoading ? null : _resendVerification,
                  child: const Text(
                    'Resend verification email',
                    style: TextStyle(color: deepRed),
                  ),
                ),

                // Forgot password
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
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: deepRed),
                  ),
                ),

                const SizedBox(height: 10),

                // Create one
                GestureDetector(
                  onTap: _goToRegister,
                  child: Text.rich(
                    TextSpan(
                      text: "Don't have an account? ",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Create one',
                          style: TextStyle(
                            color: deepRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
