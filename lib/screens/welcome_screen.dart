import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color deepRed = Color(0xFF7A0009);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ الخلفية مثل ما هي
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/logoBLOOD.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ✅ الطبقة البيضاء مثل ما هي
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
                        // ✅ اللوغو الغامق: أقرب أكثر
                        Transform.translate(
                          offset: const Offset(0, 16), // ✅ نزّل اللوغو لتحت
                          child: Image.asset(
                            'images/logoBLOOD.png',
                            height: h * 0.26, // ✅ كان 0.30 (صغرناه)
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 0), // ✅ صار صفر (لاصق تقريبًا)

                        const Text(
                          'HAYAH',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: deepRed,
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
                            color: Colors.grey,
                            fontSize: 17,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ زر Get Started
                Positioned(
                  left: 32,
                  right: 32,
                  top: h * 0.72,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: deepRed,
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
