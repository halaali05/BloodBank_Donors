import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
