// Pfad: lib/app/app.dart

import 'package:flutter/material.dart';

import '../presentation/screens/auth_gate.dart';
import 'theme.dart';

class LumaApp extends StatelessWidget {
  const LumaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luma',
      debugShowCheckedModeBanner: false,
      theme: LumaTheme.lightTheme,
      darkTheme: LumaTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}