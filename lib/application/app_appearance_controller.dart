// Pfad: lib/application/app_appearance_controller.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/settings_repository.dart';
import 'settings_state.dart';

class AppAppearanceController extends ChangeNotifier {
  AppAppearanceController._();

  static final AppAppearanceController instance = AppAppearanceController._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SettingsRepository _settingsRepository = SettingsRepository();

  ThemeMode _themeMode = ThemeMode.system;
  AppAppearanceMode _appearanceMode = AppAppearanceMode.system;
  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  AppAppearanceMode get appearanceMode => _appearanceMode;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _authSubscription = _auth.authStateChanges().listen((user) {
      unawaited(_loadForUser(user));
    });

    await _loadForUser(_auth.currentUser);
  }

  Future<void> setAppearanceMode(AppAppearanceMode mode) async {
    _applyAppearanceMode(mode);

    final userId = _auth.currentUser?.uid.trim();
    if (userId == null || userId.isEmpty) return;

    await _settingsRepository.saveAppearanceMode(
      userId: userId,
      mode: mode,
    );
  }

  void applyAppearanceMode(AppAppearanceMode mode) {
    _applyAppearanceMode(mode);
  }

  Future<void> _loadForUser(User? user) async {
    final userId = user?.uid.trim();

    if (userId == null || userId.isEmpty) {
      _applyAppearanceMode(AppAppearanceMode.system);
      return;
    }

    try {
      final snapshot = await _settingsRepository.loadSettings(userId);
      _applyAppearanceMode(
        snapshot?.state.appAppearanceMode ?? AppAppearanceMode.system,
      );
    } catch (_) {
      // A remote read failure must not prevent Luma from starting.
      // Keep the currently active appearance until a later auth change/retry.
    }
  }

  void _applyAppearanceMode(AppAppearanceMode mode) {
    final nextThemeMode = switch (mode) {
      AppAppearanceMode.system => ThemeMode.system,
      AppAppearanceMode.dark => ThemeMode.dark,
      AppAppearanceMode.light => ThemeMode.light,
    };

    if (_appearanceMode == mode && _themeMode == nextThemeMode) {
      return;
    }

    _appearanceMode = mode;
    _themeMode = nextThemeMode;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
