import 'package:flutter/material.dart';

import 'settings_state.dart';

class AppAppearanceController extends ChangeNotifier {
  AppAppearanceController._();

  static final AppAppearanceController instance =
      AppAppearanceController._();

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void applyAppearanceMode(AppAppearanceMode mode) {
    final nextThemeMode = switch (mode) {
      AppAppearanceMode.system => ThemeMode.system,
      AppAppearanceMode.dark => ThemeMode.dark,
      AppAppearanceMode.light => ThemeMode.light,
    };

    if (_themeMode == nextThemeMode) {
      return;
    }

    _themeMode = nextThemeMode;
    notifyListeners();
  }
}
