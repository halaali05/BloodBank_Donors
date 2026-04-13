import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';

/// First screen users see when opening the app
/// Shows app branding and "Get Started" button to navigate to login
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Background image (logo)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/logoBLOOD.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Semi-transparent white overlay for better text readability
          Container(color: Colors.white.withOpacity(0.78)),

          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, 16),
                          child: Image.asset(
                            'images/logoBLOOD.png',
                            height: h * 0.26,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 0),

                        // App name/title
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

                        // App tagline
                        const Text(
                          'Donate blood, save a Hayah',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color.fromARGB(255, 62, 61, 61),
                            fontSize: 17,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // "Get Started" button - navigates to login screen
                Positioned(
                  left: 32,
                  right: 32,
                  top: h * 0.72,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepRed,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
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
