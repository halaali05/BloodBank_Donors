import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// User type toggle (Donor/Blood Bank)
class UserTypeToggle extends StatelessWidget {
  final bool isDonor;
  final ValueChanged<bool> onChanged;

  const UserTypeToggle({
    super.key,
    required this.isDonor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff4f5fb),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDonor ? AppTheme.deepRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Donor',
                  style: TextStyle(
                    color: isDonor ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isDonor ? AppTheme.deepRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Blood bank',
                  style: TextStyle(
                    color: !isDonor ? Colors.white : Colors.black87,
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
}

/// Confirm password field with visibility toggle
class ConfirmPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  const ConfirmPasswordField({
    super.key,
    required this.controller,
    required this.obscureText,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: AppTheme.underlineInputDecoration(
        hint: 'Confirm Password',
        icon: Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[700],
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }
}

/// Location dropdown field
class LocationDropdown extends StatelessWidget {
  final String? selectedLocation;
  final ValueChanged<String?> onChanged;

  const LocationDropdown({
    super.key,
    this.selectedLocation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedLocation,
      decoration: AppTheme.underlineInputDecoration(
        hint: 'Location',
        icon: Icons.location_on_outlined,
      ),
      items: AppTheme.jordanianGovernorates.map((location) {
        return DropdownMenuItem<String>(value: location, child: Text(location));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// Screen title widget
class ScreenTitle extends StatelessWidget {
  final String text;

  const ScreenTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppTheme.deepRed,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Login link text (for register screen)
class LoginLink extends StatelessWidget {
  final VoidCallback onTap;

  const LoginLink({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Text(
        'Already have an account? Login',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.deepRed,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
