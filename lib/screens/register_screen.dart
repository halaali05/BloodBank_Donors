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
  static const _primaryColor = Color(0xffe60012);
  static const _fieldFill = Color(0xfff8f9ff);
  static const _cardShadow = BoxShadow(
    color: Color(0x11000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  final _authService = AuthService();
  UserType _type = UserType.donor;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hospitalNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();

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
    _bloodTypeController.dispose();
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

        // بما إننا شلنا blood type و location من واجهة المتبرع
        // منبعت قيم افتراضية بسيطة
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

      // Check if email is already verified
      final emailVerified = result['emailVerified'] ?? false;

      if (emailVerified) {
        // Email already verified, profile created immediately
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
        // Email not verified, profile data saved in pending_profiles
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
              'We sent you a verification email. Please check your inbox and click the link to verify your email. Your account will be activated after verification.',
          btnOkOnPress: () async {
            await _authService.logout();
            if (!mounted) return;
            Navigator.of(context).pop();
          },
        ).show();
      }
    } catch (e) {
      if (!mounted) return;

      // Get user-friendly error message
      String errorMessage =
          'Something went wrong while creating your account. Please try again.';
      String errorTitle = 'Sign up failed';

      if (e is FirebaseAuthException) {
        // Specific, clear error messages for each Firebase Auth error
        switch (e.code) {
          case 'email-already-in-use':
            errorTitle = 'Email already in use';
            errorMessage =
                'This email address is already registered. Please use a different email or try logging in instead.';
            break;
          case 'weak-password':
            errorTitle = 'Password too weak';
            errorMessage =
                'Your password is too weak. Please use at least 6 characters with a mix of letters and numbers.';
            break;
          case 'invalid-email':
            errorTitle = 'Invalid email address';
            errorMessage =
                'The email address you entered is not valid. Please check and enter a correct email address (e.g., example@email.com).';
            break;
          case 'operation-not-allowed':
            errorTitle = 'Registration disabled';
            errorMessage =
                'Registration is currently not available. Please contact support for assistance.';
            break;
          case 'network-request-failed':
            errorTitle = 'Network error';
            errorMessage =
                'Unable to connect to the server. Please check your internet connection and try again.';
            break;
          case 'too-many-requests':
            errorTitle = 'Too many attempts';
            errorMessage =
                'Too many registration attempts. Please wait a few minutes before trying again.';
            break;
          default:
            errorTitle = 'Registration failed';
            errorMessage =
                'Unable to create your account. Please check your information and try again.';
        }
      } else {
        // For Cloud Function errors or other exceptions
        print('❌ Registration error caught:');
        print('  Error: $e');
        print('  Error type: ${e.runtimeType}');

        String errorStr = e.toString();

        // Extract specific error messages from Cloud Functions
        if (errorStr.contains('Exception: ')) {
          errorMessage = errorStr.replaceFirst('Exception: ', '').trim();

          // Map common Cloud Function errors to specific titles
          if (errorMessage.toLowerCase().contains('email')) {
            errorTitle = 'Email error';
          } else if (errorMessage.toLowerCase().contains('password')) {
            errorTitle = 'Password error';
          } else if (errorMessage.toLowerCase().contains('network') ||
              errorMessage.toLowerCase().contains('connection')) {
            errorTitle = 'Connection error';
            errorMessage =
                'Unable to connect to the server. Please check your internet connection and try again.';
          } else if (errorMessage.toLowerCase().contains('required') ||
              errorMessage.toLowerCase().contains('missing')) {
            errorTitle = 'Missing information';
          } else if (errorMessage.toLowerCase().contains('invalid')) {
            errorTitle = 'Invalid information';
          } else if (errorMessage.toLowerCase().contains('permission') ||
              errorMessage.toLowerCase().contains('not allowed')) {
            errorTitle = 'Permission denied';
          } else {
            errorTitle = 'Registration failed';
          }
        } else if (errorStr.contains('Please') ||
            errorStr.contains('check') ||
            errorStr.contains('verify')) {
          // If error already contains helpful message, use it
          errorMessage = errorStr;
        } else {
          // Generic fallback
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

  InputDecoration _decoration({
    required String label,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: _fieldFill,
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xffffe3e6),
          child: Icon(Icons.favorite, color: _primaryColor, size: 32),
        ),
        SizedBox(height: 12),
        Text(
          'Hayat',
          style: TextStyle(
            color: _primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Create a new account',
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff4f5fb),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _type = UserType.donor),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _type == UserType.donor
                      ? _primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _type = UserType.bloodBank),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _type == UserType.bloodBank
                      ? _primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
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
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: _decoration(label: label, icon: icon, suffixIcon: suffixIcon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Container(
                width: 520,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [_cardShadow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToggle(),
                    const SizedBox(height: 20),

                    // --------- Donor fields ---------
                    if (_type == UserType.donor) ...[
                      _textField(
                        label: 'Full name',
                        controller: _nameController,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // --------- Blood bank fields ---------
                    if (_type == UserType.bloodBank) ...[
                      _textField(
                        label: 'Blood bank name',
                        controller: _hospitalNameController,
                        icon: Icons.local_hospital_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // --------- Common fields ---------
                    _textField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.mail_outline,
                    ),
                    const SizedBox(height: 12),

                    _textField(
                      label: 'Password',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      obscure: _obscurePassword,
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
                    const SizedBox(height: 12),

                    _textField(
                      label: 'Confirm password',
                      controller: _confirmPasswordController,
                      icon: Icons.lock_outline,
                      obscure: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location فقط للبنك
                    if (_type == UserType.bloodBank) ...[
                      _textField(
                        label: 'Location',
                        controller: _locationController,
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Create account',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text.rich(
                  TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Login',
                        style: TextStyle(
                          color: _primaryColor,
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
    );
  }
}
