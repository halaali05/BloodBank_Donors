import 'package:flutter/material.dart';
import '../controllers/register_controller.dart';
import '../models/register_models.dart';
import '../utils/dialog_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/login_widgets.dart';
import '../widgets/auth/register_widgets.dart';
import '../services/auth_service.dart';

/// Registration screen where new users create accounts
/// Supports both donor and blood bank registration
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final RegisterController _registerController = RegisterController();
  final AuthService _authService = AuthService();

  UserType _type = UserType.donor;

  // Text field controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hospitalNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedLocation;
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
    super.dispose();
  }

  // ------------------ Registration Handler ------------------
  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();
    final bloodBankName = _hospitalNameController.text.trim();

    // Validate form
    final validationError = _registerController.validateForm(
      userType: _type,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      name: _type == UserType.donor ? name : null,
      bloodBankName: _type == UserType.bloodBank ? bloodBankName : null,
      location: _selectedLocation,
    );

    if (validationError != null) {
      DialogHelper.showWarning(
        context: context,
        title: 'Missing information',
        message: validationError,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _registerController.register(
        userType: _type,
        email: email,
        password: password,
        name: _type == UserType.donor ? name : null,
        bloodBankName: _type == UserType.bloodBank ? bloodBankName : null,
        location: _selectedLocation ?? '',
      );

      if (!mounted) return;

      if (result.success) {
        if (result.emailVerified) {
          // Wait for dialog to be dismissed before navigating
          await DialogHelper.showSuccess(
            context: context,
            title: 'Account created',
            message: result.message ?? '',
          );
        } else {
          // Wait for dialog to be dismissed before navigating
          await DialogHelper.showInfo(
            context: context,
            title: 'Verification email sent',
            message: result.message ?? '',
          );
        }

        // Logout and go back to login (only after dialog is dismissed)
        await _authService.logout();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        DialogHelper.showError(
          context: context,
          title: result.errorTitle ?? 'Sign up failed',
          message: result.errorMessage ?? 'Something went wrong.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      DialogHelper.showError(
        context: context,
        title: 'Error',
        message: 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------ UI Build ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: LoginFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenTitle(text: 'SIGN UP'),
                  const SizedBox(height: 18),
                  UserTypeToggle(
                    isDonor: _type == UserType.donor,
                    onChanged: (isDonor) {
                      setState(() {
                        _type = isDonor ? UserType.donor : UserType.bloodBank;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_type == UserType.donor)
                    TextField(
                      controller: _nameController,
                      decoration: AppTheme.underlineInputDecoration(
                        hint: 'Username',
                        icon: Icons.person_outline,
                      ),
                    ),
                  if (_type == UserType.bloodBank)
                    TextField(
                      controller: _hospitalNameController,
                      decoration: AppTheme.underlineInputDecoration(
                        hint: 'Blood bank name',
                        icon: Icons.local_hospital_outlined,
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: AppTheme.underlineInputDecoration(
                      hint: 'E-Mail',
                      icon: Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onToggleVisibility: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: 12),
                  ConfirmPasswordField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    onToggleVisibility: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LocationDropdown(
                    selectedLocation: _selectedLocation,
                    onChanged: (value) {
                      setState(() => _selectedLocation = value);
                    },
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    text: 'CREATE ACCOUNT',
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 14),
                  LoginLink(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
