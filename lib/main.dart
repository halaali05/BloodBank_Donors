import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const HayatApp());
}

class HayatApp extends StatelessWidget {
  const HayatApp({super.key});

  static const _primaryColor = Color(0xffe60012);
  static const _bgColor = Color(0xfff5f6fb);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hayat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: _bgColor,
        colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}
