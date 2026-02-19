import 'package:flutter/material.dart';

import 'auth_screen.dart';

// Kept for backward compat – immediately forwards to AuthScreen.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen();
  }
}
