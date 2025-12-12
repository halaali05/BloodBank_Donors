import 'package:flutter/material.dart';
import 'blood_bank_dashboard_screen.dart';
import 'donor_dashboard_screen.dart';

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

  void _submit() {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_type == UserType.donor) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BloodBankDashboardScreen(
          bloodBankName: _hospitalNameController.text.isEmpty
              ? 'Blood bank'
              : _hospitalNameController.text,
          location: _locationController.text.isEmpty
              ? 'Unknown'
              : _locationController.text,
        ),
      ),
    );
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

                    if (_type == UserType.donor) ...[
                      _textField(
                        label: 'Full name',
                        controller: _nameController,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_type == UserType.bloodBank) ...[
                      _textField(
                        label: 'Blood bank name',
                        controller: _hospitalNameController,
                        icon: Icons.local_hospital_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],

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

                    if (_type == UserType.bloodBank) ...[
                      _textField(
                        label: 'Location',
                        controller: _locationController,
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_type == UserType.donor) ...[
                      const Text(
                        'Medical report (optional)',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xfffdfdfd),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffd7d9e0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Attach medical report',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.upload_file_outlined),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      const SizedBox(height: 20),
                    ],

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
                        onPressed: _submit,
                        child: const Text(
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
