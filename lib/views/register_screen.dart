import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/register_controller.dart';
import '../models/register_models.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/dialog_helper.dart';
import '../widgets/auth/login_widgets.dart';
import '../widgets/auth/register_widgets.dart';
import 'map_location_picker_screen.dart';

enum DonorGenderSelection { male, female }

/// Registration for donors and blood banks.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const double _fieldGap = 14;
  static const double _blockGap = 22;

  final RegisterController _registerController = RegisterController();
  final AuthService _authService = AuthService();

  UserType _type = UserType.donor;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hospitalNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  DonorGenderSelection? _donorGender;

  String? get _genderForApi {
    if (_donorGender == DonorGenderSelection.male) return 'male';
    if (_donorGender == DonorGenderSelection.female) return 'female';
    return null;
  }

  String? _selectedLocation;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  LatLng? _pickedLatLng;
  String? _pickedAddressLabel;

  @override
  void dispose() {
    _nameController.dispose();
    _hospitalNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    if (_isLoading) return;
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) =>
            MapLocationPickerScreen(initialGovernorate: _selectedLocation),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pickedLatLng = result.coordinates;
      _pickedAddressLabel = result.displayAddress;
      final match = AppTheme.governorateCoordinates.keys.firstWhere(
        (g) => result.displayAddress.contains(g),
        orElse: () => '',
      );
      if (match.isNotEmpty) _selectedLocation = match;
    });
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();
    final bloodBankName = _hospitalNameController.text.trim();

    final validationError = _registerController.validateForm(
      userType: _type,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      name: _type == UserType.donor ? name : null,
      donorGender: _type == UserType.donor ? _genderForApi : null,
      donorPhoneRaw: _type == UserType.donor ? _phoneController.text : null,
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
        donorGender: _type == UserType.donor ? _genderForApi : null,
        donorPhoneRaw: _type == UserType.donor ? _phoneController.text : null,
        bloodBankName: _type == UserType.bloodBank ? bloodBankName : null,
        location: _selectedLocation ?? '',
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
          await DialogHelper.showSuccess(
            context: context,
            title: 'Account created',
            message: result.message ?? '',
          );
        } else {
          await DialogHelper.showInfo(
            context: context,
            title: 'Verification email sent',
            message: result.message ?? '',
          );
        }
        if (!mounted) return;
        await _authService.logout();
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        DialogHelper.showError(
          context: context,
          title: result.errorTitle ?? 'Sign up failed',
          message: result.errorMessage ?? 'Something went wrong.',
        );
      }
    } catch (_) {
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

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: LoginFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your details, then choose your role and location below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_type == UserType.donor) ...[
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: AppTheme.outlinedInputDecoration(
                        label: 'Full name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: _fieldGap),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: AppTheme.outlinedInputDecoration(
                        label: 'Mobile number',
                        icon: Icons.phone_android_outlined,
                      ),
                    ),
                    const SizedBox(height: _fieldGap),
                  ],
                  if (_type == UserType.bloodBank) ...[
                    TextField(
                      controller: _hospitalNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: AppTheme.outlinedInputDecoration(
                        label: 'Blood bank name',
                        icon: Icons.local_hospital_outlined,
                      ),
                    ),
                    const SizedBox(height: _fieldGap),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: AppTheme.outlinedInputDecoration(
                      label: 'Email',
                      icon: Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(height: _fieldGap),
                  PasswordField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    useOutlinedInput: true,
                    onToggleVisibility: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: _fieldGap),
                  ConfirmPasswordField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    useOutlinedInput: true,
                    onToggleVisibility: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                  const SizedBox(height: _blockGap),
                  _RegisterChoicesPanel(
                    userType: _type,
                    onUserTypeChanged: (isDonor) {
                      final nextType = isDonor
                          ? UserType.donor
                          : UserType.bloodBank;
                      if (nextType == _type) return;
                      setState(() {
                        _type = nextType;
                      });
                    },
                    donorGender: _donorGender,
                    onDonorGenderChanged: (g) {
                      if (_donorGender == g) return;
                      setState(() => _donorGender = g);
                    },
                    selectedLocation: _selectedLocation,
                    onLocationChanged: (v) {
                      if (_selectedLocation == v) return;
                      setState(() => _selectedLocation = v);
                    },
                    bloodBankAddressLabel: _pickedAddressLabel,
                    onBloodBankMapTap: _openMapPicker,
                  ),
                  const SizedBox(height: _blockGap),
                  PrimaryButton(
                    text: 'Create account',
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: _fieldGap),
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

class _RegisterFormStyles {
  _RegisterFormStyles._();

  static TextStyle get sectionLabel => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Colors.grey[700],
    letterSpacing: 0.2,
  );
}

/// Role, gender (donors), and location at the bottom of the form.
class _RegisterChoicesPanel extends StatelessWidget {
  final UserType userType;
  final ValueChanged<bool> onUserTypeChanged;
  final DonorGenderSelection? donorGender;
  final ValueChanged<DonorGenderSelection?> onDonorGenderChanged;
  final String? selectedLocation;
  final ValueChanged<String?> onLocationChanged;
  final String? bloodBankAddressLabel;
  final VoidCallback onBloodBankMapTap;

  const _RegisterChoicesPanel({
    required this.userType,
    required this.onUserTypeChanged,
    required this.donorGender,
    required this.onDonorGenderChanged,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.bloodBankAddressLabel,
    required this.onBloodBankMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDonor = userType == UserType.donor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('I am signing up as', style: _RegisterFormStyles.sectionLabel),
          const SizedBox(height: 8),
          UserTypeToggle(
            isDonor: userType == UserType.donor,
            onChanged: onUserTypeChanged,
          ),
          if (isDonor) ...[
            const SizedBox(height: 18),
            Text('Gender', style: _RegisterFormStyles.sectionLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _GenderPill(
                    label: 'Male',
                    selected: donorGender == DonorGenderSelection.male,
                    onTap: () =>
                        onDonorGenderChanged(DonorGenderSelection.male),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GenderPill(
                    label: 'Female',
                    selected: donorGender == DonorGenderSelection.female,
                    onTap: () =>
                        onDonorGenderChanged(DonorGenderSelection.female),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Governorate', style: _RegisterFormStyles.sectionLabel),
            const SizedBox(height: 8),
            LocationDropdown(
              selectedLocation: selectedLocation,
              useOutlinedInput: true,
              onChanged: onLocationChanged,
            ),
          ] else ...[
            const SizedBox(height: 18),
            Text('Pin on map', style: _RegisterFormStyles.sectionLabel),
            const SizedBox(height: 8),
            _BloodBankLocationButton(
              addressLabel: bloodBankAddressLabel,
              onTap: onBloodBankMapTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _GenderPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.deepRed : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.deepRed : const Color(0xFFD5DCE8),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: hasPick ? const Color(0xFFFFF5F5) : AppTheme.fieldFill,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            border: Border.all(
              color: hasPick ? AppTheme.deepRed : const Color(0xffd0d4f0),
              width: hasPick ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasPick ? Icons.location_on : Icons.add_location_alt_outlined,
                color: hasPick ? AppTheme.deepRed : Colors.grey[600],
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasPick ? addressLabel! : 'Open map to drop a pin',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasPick ? AppTheme.deepRed : Colors.grey[700],
                    fontWeight: hasPick ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              Icon(
                Icons.map_outlined,
                color: AppTheme.deepRed.withValues(alpha: 0.75),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
