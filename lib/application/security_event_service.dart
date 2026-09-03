// Pfad: lib/application/security_event_service.dart

import 'package:firebase_auth/firebase_auth.dart';

import '../data/settings_repository.dart';
import 'settings_state.dart';

// ignore_for_file: prefer_initializing_formals

class SecurityEventService {
  const SecurityEventService({
    FirebaseAuth? firebaseAuth,
    SettingsRepository? settingsRepository,
  })  : _firebaseAuth = firebaseAuth,
        _settingsRepository = settingsRepository;

  final FirebaseAuth? _firebaseAuth;
  final SettingsRepository? _settingsRepository;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  SettingsRepository get _repository =>
      _settingsRepository ?? SettingsRepository();

  Future<void> recordSuccessfulLogin() async {
    final user = _auth.currentUser;
    final userId = user?.uid.trim();

    if (userId == null || userId.isEmpty) {
      return;
    }

    final now = DateTime.now();

    await _saveTimelineUpdate(
      userId: userId,
      timelineSummary: SecurityTimelineSummary(
        lastSuccessfulLoginAt: now,
        lastPasswordChangedAt: null,
        lastSecurityEventAt: now,
        unreadSecurityEventCount: 0,
      ),
      deviceSummary: SecurityDeviceSummary(
        trustedDeviceCount: 0,
        activeSessionCount: 1,
        lastDeviceActivityAt: now,
      ),
    );
  }

  Future<void> recordSecurityEvent({
    required DateTime eventAt,
    bool increaseUnreadCount = false,
  }) async {
    final user = _auth.currentUser;
    final userId = user?.uid.trim();

    if (userId == null || userId.isEmpty) {
      return;
    }

    final snapshot = await _repository.loadSettings(userId);
    final currentState = snapshot?.state ?? const SettingsState.initial();
    final currentTimeline = currentState.securityTimelineSummary;

    final nextTimeline = currentTimeline.copyWith(
      lastSecurityEventAt: eventAt,
      unreadSecurityEventCount: increaseUnreadCount
          ? currentTimeline.unreadSecurityEventCount + 1
          : currentTimeline.unreadSecurityEventCount,
    );

    await _repository.saveSettings(
      userId: userId,
      state: currentState.copyWith(
        securityTimelineSummary: nextTimeline,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _saveTimelineUpdate({
    required String userId,
    required SecurityTimelineSummary timelineSummary,
    required SecurityDeviceSummary deviceSummary,
  }) async {
    final snapshot = await _repository.loadSettings(userId);
    final currentState = snapshot?.state ?? const SettingsState.initial();

    final currentTimeline = currentState.securityTimelineSummary;

    final nextTimeline = currentTimeline.copyWith(
      lastSuccessfulLoginAt: timelineSummary.lastSuccessfulLoginAt,
      lastSecurityEventAt: timelineSummary.lastSecurityEventAt,
      unreadSecurityEventCount: timelineSummary.unreadSecurityEventCount,
    );

    final nextDeviceSummary = currentState.securityDeviceSummary.copyWith(
      activeSessionCount: deviceSummary.activeSessionCount,
      lastDeviceActivityAt: deviceSummary.lastDeviceActivityAt,
    );

    await _repository.saveSettings(
      userId: userId,
      state: currentState.copyWith(
        securityTimelineSummary: nextTimeline,
        securityDeviceSummary: nextDeviceSummary,
        clearErrorMessage: true,
      ),
    );
  }
}

