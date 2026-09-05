// Pfad: lib/app/app.dart

import 'package:flutter/material.dart';

import '../application/app_appearance_controller.dart';
import '../presentation/screens/auth_gate.dart';
import 'theme.dart';

class LumaApp extends StatefulWidget {
  const LumaApp({super.key});

  @override
  State<LumaApp> createState() => _LumaAppState();
}

class _LumaAppState extends State<LumaApp> {
  final AppAppearanceController _appearanceController =
      AppAppearanceController.instance;

  @override
  void initState() {
    super.initState();
    _appearanceController.addListener(_handleAppearanceChanged);
    _appearanceController.initialize();
  }

  @override
  void dispose() {
    _appearanceController.removeListener(_handleAppearanceChanged);
    super.dispose();
  }

  void _handleAppearanceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luma',
      debugShowCheckedModeBanner: false,
      theme: LumaTheme.lightTheme,
      darkTheme: LumaTheme.darkTheme,
      themeMode: _appearanceController.themeMode,
      home: const AuthGate(),
    );
  }
}
