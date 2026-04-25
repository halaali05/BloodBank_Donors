import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// User type toggle (Donor / Blood bank) — pill segment control
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lineColor.withValues(alpha: 0.65)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'Donor',
              icon: Icons.volunteer_activism_outlined,
              selected: isDonor,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _Segment(
              label: 'Blood bank',
              icon: Icons.local_hospital_outlined,
              selected: !isDonor,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.deepRed : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Colors.black54,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

/// Confirm password field with visibility toggle
class ConfirmPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final bool useOutlinedInput;

  const ConfirmPasswordField({
    super.key,
    required this.controller,
    required this.obscureText,
    required this.onToggleVisibility,
    this.useOutlinedInput = false,
  });

  @override
  Widget build(BuildContext context) {
    if (useOutlinedInput) {
      return TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: AppTheme.outlinedInputDecoration(
          label: 'Confirm password',
          icon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[700],
            ),
            onPressed: onToggleVisibility,
          ),
        ),
      );
    }
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
  final bool useOutlinedInput;

  static final List<DropdownMenuItem<String>> _governorateItems = AppTheme
      .jordanianGovernorates
      .map((location) {
        return DropdownMenuItem<String>(value: location, child: Text(location));
      })
      .toList(growable: false);

  const LocationDropdown({
    super.key,
    this.selectedLocation,
    required this.onChanged,
    this.useOutlinedInput = false,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = useOutlinedInput
        ? AppTheme.outlinedInputDecoration(
            label: 'Governorate',
            icon: Icons.location_on_outlined,
          )
        : AppTheme.underlineInputDecoration(
            hint: 'Location',
            icon: Icons.location_on_outlined,
          );

    return DropdownButtonFormField<String>(
      key: ValueKey<String?>(selectedLocation),
      initialValue: selectedLocation,
      decoration: decoration,
      items: _governorateItems,
      onChanged: onChanged,
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
