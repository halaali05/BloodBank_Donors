import 'package:flutter/material.dart';

import 'welcome_screen_layout.dart';

/// Web variant of [WelcomeScreen]: same layout; wider max width and larger CTA via [WelcomeScreenLayout].
class WelcomeScreenWeb extends StatelessWidget {
  const WelcomeScreenWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return WelcomeScreenLayout(
      isWeb: true,
      onGetStarted: () => WelcomeScreenLayout.openLogin(context),
    );
  }
}
