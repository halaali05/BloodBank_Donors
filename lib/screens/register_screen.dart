import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/register_controller.dart';
import '../models/register_models.dart';
import '../utils/dialog_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/login_widgets.dart';
import '../widgets/auth/register_widgets.dart';
import '../services/auth_service.dart';
import 'map_location_picker_screen.dart';

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

  // Map location (for blood bank registration)
  LatLng? _pickedLatLng;
  String? _pickedAddressLabel;

  @override
  void dispose() {
    _nameController.dispose();
    _hospitalNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ------------------ Map Location Picker ------------------
  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) =>
            MapLocationPickerScreen(initialGovernorate: _selectedLocation),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _pickedLatLng = result.coordinates;
        _pickedAddressLabel = result.displayAddress;
        // Derive governorate name from the address label for the location field
        final match = AppTheme.governorateCoordinates.keys.firstWhere(
          (g) => result.displayAddress.contains(g),
          orElse: () => '',
        );
        if (match.isNotEmpty) _selectedLocation = match;
      });
    }
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
      bloodBankHasMapPin: _pickedLatLng != null,
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
        // Pass exact map coordinates for blood bank if picked
        exactLatitude: _type == UserType.bloodBank
            ? _pickedLatLng?.latitude
            : null,
        exactLongitude: _type == UserType.bloodBank
            ? _pickedLatLng?.longitude
            : null,
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
                  // Location: map picker for blood bank, dropdown for donor
                  if (_type == UserType.donor)
                    LocationDropdown(
                      selectedLocation: _selectedLocation,
                      onChanged: (value) {
                        setState(() => _selectedLocation = value);
                      },
                    )
                  else
                    _BloodBankLocationButton(
                      addressLabel: _pickedAddressLabel,
                      onTap: _openMapPicker,
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

/// Button that shows the picked address or a prompt to open the map picker.
/// Used for blood bank registration only.
class _BloodBankLocationButton extends StatelessWidget {
  final String? addressLabel;
  final VoidCallback onTap;

  const _BloodBankLocationButton({
    required this.addressLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPick = addressLabel != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: hasPick ? const Color(0xFFFFEBEE) : AppTheme.fieldFill,
          border: Border(
            bottom: BorderSide(
              color: hasPick ? AppTheme.deepRed : AppTheme.lineColor,
              width: hasPick ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasPick ? Icons.location_on : Icons.location_on_outlined,
              color: hasPick ? AppTheme.deepRed : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasPick ? addressLabel! : 'Tap to pin hospital on map',
                style: TextStyle(
                  fontSize: 14,
                  color: hasPick ? AppTheme.deepRed : Colors.grey[600],
                  fontWeight: hasPick ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.map_outlined,
              color: AppTheme.deepRed.withOpacity(0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
