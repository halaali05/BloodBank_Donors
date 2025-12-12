import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const HayatApp());
}

class HayatApp extends StatelessWidget {
  const HayatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hayat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xffe60012),
        scaffoldBackgroundColor: const Color(0xfff5f6fb),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffe60012)),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}
