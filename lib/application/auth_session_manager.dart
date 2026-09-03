// Pfad: lib/application/auth_session_manager.dart
//
// Zentrale Firebase-Sitzungsverwaltung.
//
// Verbindliche Regeln:
//
// 1. Nur diese Klasse darf FirebaseAuth.signOut() ausfÃ¼hren.
// 2. App schlieÃŸen, pausieren, minimieren oder neu starten meldet niemals ab.
// 3. Quick Access, GerÃ¤te-Credentials und UI-Komponenten dÃ¼rfen keine
//    Firebase-Sitzung selbststÃ¤ndig beenden.
// 4. Presence-, Push- und Google-AufrÃ¤umfehler blockieren die Abmeldung nicht.
// 5. Jede Abmeldung wird mit einem eindeutigen Grund diagnostiziert.
// 6. WÃ¤hrend einer Abmeldung darf nicht versehentlich ein inzwischen
//    gewechseltes Konto beendet werden.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_session_diagnostics_service.dart';
import 'google_auth_service.dart';
import 'logout_landing_destination_service.dart';

class AuthSessionManager {
  AuthSessionManager({
    FirebaseAuth? firebaseAuth,
    GoogleAuthService? googleAuthService,
    LogoutLandingDestinationService? landingDestinationService,
    AuthSessionDiagnosticsService? diagnosticsService,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleAuthService =
            googleAuthService ?? GoogleAuthService.instance,
        _landingDestinationService =
            landingDestinationService ??
                LogoutLandingDestinationService.instance,
        _diagnostics =
            diagnosticsService ??
                AuthSessionDiagnosticsService.instance;

  static final AuthSessionManager instance =
      AuthSessionManager();

  final FirebaseAuth _firebaseAuth;
  final GoogleAuthService _googleAuthService;
  final LogoutLandingDestinationService
      _landingDestinationService;
  final AuthSessionDiagnosticsService _diagnostics;

  Future<AuthSessionResult>? _activeOperation;
  String? _activeOperationName;

  User? get currentUser => _firebaseAuth.currentUser;

  String? get currentUserId {
    final value = _firebaseAuth.currentUser?.uid.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  bool get hasAuthenticatedUser =>
      currentUserId != null;

  Stream<User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  Future<AuthSessionResult> signOutCurrentUser({
    Future<void> Function(String userId)?
        deletePushToken,
    Future<void> Function()? stopPresence,
  }) {
    final currentUserId =
        _firebaseAuth.currentUser?.uid.trim() ?? '';

    return signOutForReason(
      expectedUserId: currentUserId,
      reason: 'explicit-user-logout',
      signOutGoogleProvider: true,
      markLogoutLanding: true,
      deletePushToken: deletePushToken,
      stopPresence: stopPresence,
    );
  }

  /// Zentraler, kontrollierter Abmeldeweg fÃ¼r fachlich erlaubte SonderfÃ¤lle.
  ///
  /// [expectedUserId] muss dem aktuell angemeldeten Nutzer entsprechen.
  /// Dadurch kann eine verspÃ¤tete Operation kein inzwischen gewechseltes
  /// Konto abmelden.
  Future<AuthSessionResult> signOutForReason({
    required String expectedUserId,
    required String reason,
    bool signOutGoogleProvider = false,
    bool markLogoutLanding = true,
    Future<void> Function(String userId)?
        deletePushToken,
    Future<void> Function()? stopPresence,
  }) {
    final cleanedExpectedUserId =
        expectedUserId.trim();

    final cleanedReason =
        reason.trim().isEmpty
            ? 'unspecified'
            : reason.trim();

    return _runExclusive(
      operationName: 'signOutForReason:$cleanedReason',
      operation: () async {
        final currentUser =
            _firebaseAuth.currentUser;

        final currentUserId =
            currentUser?.uid.trim() ?? '';

        _diagnostics.recordSessionOperation(
          operation: 'SIGN_OUT',
          phase: 'REQUESTED',
          details:
              'reason=$cleanedReason, '
              'expectedUserId=${cleanedExpectedUserId.isEmpty ? 'NONE' : cleanedExpectedUserId}, '
              'currentUserId=${currentUserId.isEmpty ? 'NONE' : currentUserId}, '
              'markLogoutLanding=$markLogoutLanding, '
              'signOutGoogleProvider=$signOutGoogleProvider',
        );

        if (currentUserId.isEmpty) {
          if (markLogoutLanding) {
            _landingDestinationService.markLogoutStarted();
          }

          _diagnostics.recordSessionOperation(
            operation: 'SIGN_OUT',
            phase: 'SKIPPED',
            details:
                'reason=$cleanedReason, noActiveFirebaseUser=true',
          );

          return const AuthSessionResult.success();
        }

        if (cleanedExpectedUserId.isEmpty ||
            currentUserId != cleanedExpectedUserId) {
          _landingDestinationService
              .cancelPendingLogout();

          _diagnostics.recordSessionOperation(
            operation: 'SIGN_OUT',
            phase: 'REJECTED',
            details:
                'reason=$cleanedReason, '
                'expectedUserId=${cleanedExpectedUserId.isEmpty ? 'NONE' : cleanedExpectedUserId}, '
                'currentUserId=$currentUserId',
          );

          return AuthSessionResult.failure(
            code: 'active-user-changed',
            message:
                'Das aktive Konto hat sich wÃ¤hrend der Abmeldung geÃ¤ndert.',
            userId: currentUserId,
          );
        }

        if (markLogoutLanding) {
          _landingDestinationService.markLogoutStarted();
        } else {
          _landingDestinationService.cancelPendingLogout();
        }

        if (deletePushToken != null) {
          await _runCleanupSafely(
            label: 'push-token-delete',
            operation: () =>
                deletePushToken(currentUserId),
          );
        }

        if (stopPresence != null) {
          await _runCleanupSafely(
            label: 'presence-stop',
            operation: stopPresence,
          );
        }

        if (!_matchesStartedUser(currentUserId)) {
          _landingDestinationService
              .cancelPendingLogout();

          return AuthSessionResult.failure(
            code: 'active-user-changed',
            message:
                'Das aktive Konto hat sich wÃ¤hrend der Abmeldung geÃ¤ndert.',
            userId:
                _firebaseAuth.currentUser?.uid.trim(),
          );
        }

        if (signOutGoogleProvider) {
          await _runCleanupSafely(
            label: 'google-provider-sign-out',
            operation: _googleAuthService
                .signOutGoogleProviderSafely,
          );
        }

        if (!_matchesStartedUser(currentUserId)) {
          _landingDestinationService
              .cancelPendingLogout();

          return AuthSessionResult.failure(
            code: 'active-user-changed',
            message:
                'Das aktive Konto hat sich wÃ¤hrend der Abmeldung geÃ¤ndert.',
            userId:
                _firebaseAuth.currentUser?.uid.trim(),
          );
        }

        await _firebaseAuth.signOut();

        final remainingUser =
            _firebaseAuth.currentUser;

        if (remainingUser != null) {
          _landingDestinationService
              .cancelPendingLogout();

          _diagnostics.recordSessionOperation(
            operation: 'SIGN_OUT',
            phase: 'FAILED',
            details:
                'reason=$cleanedReason, remainingUserId=${remainingUser.uid}',
          );

          return AuthSessionResult.failure(
            code: 'firebase-sign-out-incomplete',
            message:
                'Die Sitzung konnte nicht vollstÃ¤ndig beendet werden.',
            userId: remainingUser.uid.trim(),
          );
        }

        _diagnostics.recordSessionOperation(
          operation: 'SIGN_OUT',
          phase: 'COMPLETED',
          details:
              'reason=$cleanedReason, userId=$currentUserId',
        );

        return AuthSessionResult.success(
          userId: currentUserId,
        );
      },
    );
  }

  Future<AuthSessionResult> prepareAccountSwitch({
    required String targetUserId,
    Future<void> Function(String userId)?
        deletePushToken,
    Future<void> Function()? stopPresence,
  }) {
    return _runExclusive(
      operationName: 'prepareAccountSwitch',
      operation: () async {
        final cleanedTargetUserId =
            targetUserId.trim();

        if (cleanedTargetUserId.isEmpty) {
          return const AuthSessionResult.failure(
            code: 'invalid-target-user',
            message:
                'Das ausgewÃ¤hlte Konto ist ungÃ¼ltig.',
          );
        }

        final currentUserId =
            _firebaseAuth.currentUser?.uid.trim() ?? '';

        if (currentUserId.isEmpty ||
            currentUserId == cleanedTargetUserId) {
          return AuthSessionResult.success(
            userId: currentUserId.isEmpty
                ? null
                : currentUserId,
          );
        }

        _diagnostics.recordSessionOperation(
          operation: 'ACCOUNT_SWITCH',
          phase: 'REQUESTED',
          details:
              'from=$currentUserId, to=$cleanedTargetUserId',
        );

        if (deletePushToken != null) {
          await _runCleanupSafely(
            label:
                'push-token-delete-before-switch',
            operation: () =>
                deletePushToken(currentUserId),
          );
        }

        if (stopPresence != null) {
          await _runCleanupSafely(
            label:
                'presence-stop-before-switch',
            operation: stopPresence,
          );
        }

        if (!_matchesStartedUser(currentUserId)) {
          return AuthSessionResult.failure(
            code: 'active-user-changed',
            message:
                'Das aktive Konto hat sich wÃ¤hrend des Kontowechsels geÃ¤ndert.',
            userId:
                _firebaseAuth.currentUser?.uid.trim(),
          );
        }

        await _runCleanupSafely(
          label:
              'google-provider-sign-out-before-switch',
          operation: _googleAuthService
              .signOutGoogleProviderSafely,
        );

        if (!_matchesStartedUser(currentUserId)) {
          return AuthSessionResult.failure(
            code: 'active-user-changed',
            message:
                'Das aktive Konto hat sich wÃ¤hrend des Kontowechsels geÃ¤ndert.',
            userId:
                _firebaseAuth.currentUser?.uid.trim(),
          );
        }

        await _firebaseAuth.signOut();

        if (_firebaseAuth.currentUser != null) {
          return AuthSessionResult.failure(
            code: 'firebase-sign-out-incomplete',
            message:
                'Das bisherige Konto konnte nicht vollstÃ¤ndig geschlossen werden.',
            userId:
                _firebaseAuth.currentUser?.uid.trim(),
          );
        }

        _landingDestinationService
            .cancelPendingLogout();

        _diagnostics.recordSessionOperation(
          operation: 'ACCOUNT_SWITCH',
          phase: 'READY',
          details:
              'from=$currentUserId, to=$cleanedTargetUserId',
        );

        return AuthSessionResult.success(
          userId: currentUserId,
        );
      },
    );
  }

  AuthSessionResult validateAuthenticatedUser({
    required String expectedUserId,
  }) {
    final cleanedExpectedUserId =
        expectedUserId.trim();

    if (cleanedExpectedUserId.isEmpty) {
      return const AuthSessionResult.failure(
        code: 'invalid-expected-user',
        message:
            'Die erwartete User-ID ist ungÃ¼ltig.',
      );
    }

    final actualUserId =
        _firebaseAuth.currentUser?.uid.trim() ?? '';

    if (actualUserId.isEmpty) {
      return const AuthSessionResult.failure(
        code: 'no-authenticated-user',
        message:
            'Es ist keine aktive Sitzung vorhanden.',
      );
    }

    if (actualUserId != cleanedExpectedUserId) {
      return AuthSessionResult.failure(
        code: 'authenticated-user-mismatch',
        message:
            'Es wurde ein anderes Konto angemeldet.',
        userId: actualUserId,
      );
    }

    return AuthSessionResult.success(
      userId: actualUserId,
    );
  }

  Future<AuthSessionResult> _runExclusive({
    required String operationName,
    required Future<AuthSessionResult>
        Function() operation,
  }) {
    final runningOperation =
        _activeOperation;

    if (runningOperation != null) {
      debugPrint(
        'AUTH SESSION OPERATION REJECTED: '
        'requested=$operationName, '
        'active=${_activeOperationName ?? 'UNKNOWN'}',
      );

      return Future<AuthSessionResult>.value(
        AuthSessionResult.failure(
          code: 'session-operation-in-progress',
          message:
              'Eine andere Kontoaktion wird bereits ausgefÃ¼hrt.',
          userId: currentUserId,
        ),
      );
    }

    final createdOperation = _executeOperation(
      operationName: operationName,
      operation: operation,
    );

    _activeOperation = createdOperation;
    _activeOperationName = operationName;

    createdOperation.whenComplete(() {
      if (identical(
        _activeOperation,
        createdOperation,
      )) {
        _activeOperation = null;
        _activeOperationName = null;
      }
    });

    return createdOperation;
  }

  Future<AuthSessionResult> _executeOperation({
    required String operationName,
    required Future<AuthSessionResult>
        Function() operation,
  }) async {
    try {
      return await operation();
    } on FirebaseAuthException catch (error, stackTrace) {
      _landingDestinationService
          .cancelPendingLogout();

      _diagnostics.recordError(
        source: 'AUTH_SESSION',
        event: 'FIREBASE_ERROR',
        error:
            'operation=$operationName, code=${error.code}, message=${error.message}',
        stackTrace: stackTrace,
      );

      return AuthSessionResult.failure(
        code: error.code,
        message:
            error.message ??
                'Die Sitzung konnte nicht vollstÃ¤ndig verarbeitet werden.',
        userId: currentUserId,
      );
    } catch (error, stackTrace) {
      _landingDestinationService
          .cancelPendingLogout();

      _diagnostics.recordError(
        source: 'AUTH_SESSION',
        event: 'UNEXPECTED_ERROR',
        error:
            'operation=$operationName, error=$error',
        stackTrace: stackTrace,
      );

      return AuthSessionResult.failure(
        code: 'unexpected-session-error',
        message:
            'Die Sitzung konnte nicht vollstÃ¤ndig verarbeitet werden.',
        userId: currentUserId,
      );
    }
  }

  bool _matchesStartedUser(
    String userIdAtStart,
  ) {
    final currentUserId =
        _firebaseAuth.currentUser?.uid.trim() ?? '';

    if (userIdAtStart.isEmpty) {
      return currentUserId.isEmpty;
    }

    return currentUserId ==
        userIdAtStart;
  }

  Future<void> _runCleanupSafely({
    required String label,
    required Future<void> Function()
        operation,
  }) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      _diagnostics.recordError(
        source: 'AUTH_SESSION',
        event: 'CLEANUP_SKIPPED',
        error: 'label=$label, error=$error',
        stackTrace: stackTrace,
      );
    }
  }
}

@immutable
class AuthSessionResult {
  const AuthSessionResult._({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.userId,
  });

  const AuthSessionResult.success({
    String? userId,
  }) : this._(
          isSuccess: true,
          code: 'success',
          message: '',
          userId: userId,
        );

  const AuthSessionResult.failure({
    required String code,
    required String message,
    String? userId,
  }) : this._(
          isSuccess: false,
          code: code,
          message: message,
          userId: userId,
        );

  final bool isSuccess;
  final String code;
  final String message;
  final String? userId;
}

