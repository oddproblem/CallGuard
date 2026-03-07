import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';

/// Root application widget.
class CallGuardApp extends StatelessWidget {
  const CallGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CallGuard',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
