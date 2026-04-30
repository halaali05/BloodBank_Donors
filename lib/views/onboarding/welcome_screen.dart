import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'welcome_screen_layout.dart';
import 'welcome_screen_web.dart';

/// First screen users see when opening the app.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WelcomeScreenWeb();
    }
    return WelcomeScreenLayout(
      isWeb: false,
      onGetStarted: () => WelcomeScreenLayout.openLogin(context),
    );
  }
}
