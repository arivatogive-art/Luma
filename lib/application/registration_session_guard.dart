// Pfad: lib/application/registration_session_guard.dart
//
// Koordiniert ausschließlich den kurzen Zeitraum, in dem Firebase nach
// createUserWithEmailAndPassword bereits einen unbestätigten User meldet,
// der Registrierungs-Controller aber noch Consent + Verifizierungs-Mail
// abschließen muss.
//
// Dadurch darf AuthGate den frisch erzeugten User nicht vorzeitig abmelden.
// Außerhalb dieses kurzen Fensters greift die normale AuthGate-Sicherung
// gegen unbestätigte Passwort-Konten unverändert weiter.

import 'package:flutter/foundation.dart';

class RegistrationSessionGuard {
  RegistrationSessionGuard._();

  static final RegistrationSessionGuard instance =
      RegistrationSessionGuard._();

  final ValueNotifier<String?> _activeEmailRegistrationUserId =
      ValueNotifier<String?>(null);

  ValueListenable<String?> get activeEmailRegistrationUserId =>
      _activeEmailRegistrationUserId;

  bool get isEmailRegistrationInProgress =>
      (_activeEmailRegistrationUserId.value ?? '').trim().isNotEmpty;

  bool isProtectedUser(String userId) {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return false;

    return _activeEmailRegistrationUserId.value == cleanedUserId;
  }

  void protectUser(String userId) {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    if (_activeEmailRegistrationUserId.value == cleanedUserId) {
      return;
    }

    _activeEmailRegistrationUserId.value = cleanedUserId;
  }

  void releaseUser(String userId) {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty ||
        _activeEmailRegistrationUserId.value != cleanedUserId) {
      return;
    }

    _activeEmailRegistrationUserId.value = null;
  }

  void clear() {
    if (_activeEmailRegistrationUserId.value == null) {
      return;
    }

    _activeEmailRegistrationUserId.value = null;
  }
}
