import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../auth/login_screen.dart';

/// Shared layout for mobile and web welcome screens (background, branding, primary CTA).
class WelcomeScreenLayout extends StatelessWidget {
  const WelcomeScreenLayout({
    super.key,
    required this.isWeb,
    required this.onGetStarted,
  });

  final bool isWeb;
  final VoidCallback onGetStarted;

  static const Color _subtitleColor = Color.fromARGB(255, 62, 61, 61);

  static void openLogin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;

    Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 16),
          child: Image.asset(
            'assets/docs/images/logoBLOOD.png',
            height: h * 0.26,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 0),
        const Text(
          'HAYAH',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.deepRed,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: 5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Donate blood, save a Hayah',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _subtitleColor,
            fontSize: 17,
            height: 1.45,
          ),
        ),
      ],
    );

    column = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: isWeb
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: column,
            )
          : column,
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/docs/images/logoBLOOD.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.white.withValues(alpha: 0.78)),
          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: column,
                ),
                Positioned(
                  left: 32,
                  right: 32,
                  top: h * 0.72,
                  child: _GetStartedSection(
                    isWeb: isWeb,
                    onPressed: onGetStarted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GetStartedSection extends StatelessWidget {
  const _GetStartedSection({
    required this.isWeb,
    required this.onPressed,
  });

  final bool isWeb;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.deepRed,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const StadiumBorder(),
        padding:
            isWeb ? const EdgeInsets.symmetric(horizontal: 28) : null,
      ),
      onPressed: onPressed,
      child: Text(
        'Get Started',
        style: TextStyle(
          fontSize: isWeb ? 18 : 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );

    if (isWeb) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: button,
          ),
        ),
      );
    }
    return SizedBox(height: 52, child: button);
  }
}
