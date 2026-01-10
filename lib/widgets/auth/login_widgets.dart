import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable login form card container
class LoginFormCard extends StatelessWidget {
  final Widget child;

  const LoginFormCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

/// Avatar icon for login screen
class LoginAvatar extends StatelessWidget {
  const LoginAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppTheme.deepRed.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_outline,
        size: 48,
        color: AppTheme.deepRed,
      ),
    );
  }
}

/// Password field with visibility toggle
class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  const PasswordField({
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
        hint: 'Password',
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

/// Primary action button with loading state
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        style: AppTheme.primaryButtonStyle(),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
    );
  }
}

/// Link button for secondary actions
class LinkButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const LinkButton({super.key, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(text, style: const TextStyle(color: AppTheme.deepRed)),
    );
  }
}

/// Register link text
class RegisterLink extends StatelessWidget {
  final VoidCallback onTap;

  const RegisterLink({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text.rich(
        TextSpan(
          text: "Don't have an account? ",
          style: const TextStyle(fontSize: 13, color: Colors.black54),
          children: const [
            TextSpan(
              text: 'Create one',
              style: TextStyle(
                color: AppTheme.deepRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
