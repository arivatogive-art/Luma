// Pfad: lib/application/auth_session_diagnostics_service.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionDiagnosticsService with WidgetsBindingObserver {
  AuthSessionDiagnosticsService._();

  static final AuthSessionDiagnosticsService instance =
      AuthSessionDiagnosticsService._();

  static const String _persistedTraceKey =
      'luma.auth.sessionDiagnostics.trace.v1';

  static const int _maxPersistedEvents = 120;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<User?>? _idTokenSubscription;
  StreamSubscription<User?>? _userChangesSubscription;

  bool _isInitialized = false;
  int _eventCounter = 0;

  Future<void> _persistQueue = Future<void>.value();

  Future<void> initialize() async {
    if (_isInitialized) {
      record(
        source: 'DIAGNOSTICS',
        event: 'INITIALIZE_SKIPPED',
        details: 'serviceAlreadyInitialized=true',
      );
      return;
    }

    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);

    record(
      source: 'DIAGNOSTICS',
      event: 'INITIALIZED',
      details: _currentUserDetails(),
    );

    _authStateSubscription = _auth.authStateChanges().listen(
      (user) {
        record(
          source: 'FIREBASE_AUTH',
          event: 'AUTH_STATE_CHANGED',
          details: _userDetails(user),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        recordError(
          source: 'FIREBASE_AUTH',
          event: 'AUTH_STATE_STREAM_ERROR',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    _idTokenSubscription = _auth.idTokenChanges().listen(
      (user) {
        record(
          source: 'FIREBASE_AUTH',
          event: 'ID_TOKEN_CHANGED',
          details: _userDetails(user),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        recordError(
          source: 'FIREBASE_AUTH',
          event: 'ID_TOKEN_STREAM_ERROR',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    _userChangesSubscription = _auth.userChanges().listen(
      (user) {
        record(
          source: 'FIREBASE_AUTH',
          event: 'USER_CHANGED',
          details: _userDetails(user),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        recordError(
          source: 'FIREBASE_AUTH',
          event: 'USER_CHANGES_STREAM_ERROR',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  void record({
    required String source,
    required String event,
    String? details,
  }) {
    final eventNumber = ++_eventCounter;
    final timestamp = DateTime.now().toIso8601String();
    final cleanedDetails = details?.trim();

    final line =
        'LUMA AUTH TRACE '
        '#$eventNumber | '
        '$timestamp | '
        '$source | '
        '$event'
        '${cleanedDetails == null || cleanedDetails.isEmpty ? '' : ' | $cleanedDetails'}';

    debugPrint(line);
    unawaited(_persistTraceLine(line));
  }

  void recordError({
    required String source,
    required String event,
    required Object error,
    StackTrace? stackTrace,
  }) {
    record(
      source: source,
      event: event,
      details: 'error=$error',
    );

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void recordAuthGateDecision({
    required String decision,
    String? details,
  }) {
    record(
      source: 'AUTH_GATE',
      event: decision,
      details: details,
    );
  }

  void recordSessionOperation({
    required String operation,
    required String phase,
    String? details,
  }) {
    record(
      source: 'AUTH_SESSION',
      event: '${operation.toUpperCase()}_${phase.toUpperCase()}',
      details: details,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    record(
      source: 'APP_LIFECYCLE',
      event: state.name.toUpperCase(),
      details: _currentUserDetails(),
    );
  }

  Future<String> loadPersistedReport() async {
    await _persistQueue;

    final preferences =
        await SharedPreferences.getInstance();

    final lines =
        preferences.getStringList(_persistedTraceKey) ??
            const <String>[];

    if (lines.isEmpty) {
      return 'Keine gespeicherten Sitzungsereignisse vorhanden.';
    }

    return lines.join('\n');
  }

  Future<void> clearPersistedReport() async {
    await _persistQueue;

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(_persistedTraceKey);

    record(
      source: 'DIAGNOSTICS',
      event: 'PERSISTED_REPORT_CLEARED',
    );
  }

  Future<void> _persistTraceLine(String line) {
    final operation = _persistQueue.then((_) async {
      try {
        final preferences =
            await SharedPreferences.getInstance();

        final existing =
            preferences.getStringList(_persistedTraceKey) ??
                <String>[];

        final next = <String>[
          ...existing,
          line,
        ];

        if (next.length > _maxPersistedEvents) {
          next.removeRange(
            0,
            next.length - _maxPersistedEvents,
          );
        }

        await preferences.setStringList(
          _persistedTraceKey,
          next,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'LUMA AUTH TRACE PERSIST FAILED: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    });

    _persistQueue = operation;
    return operation;
  }

  String _currentUserDetails() {
    return _userDetails(_auth.currentUser);
  }

  String _userDetails(User? user) {
    if (user == null) {
      return 'firebaseUser=NONE';
    }

    final providers = user.providerData
        .map((provider) => provider.providerId)
        .where((providerId) => providerId.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return 'firebaseUser=${user.uid}, '
        'email=${user.email ?? 'NONE'}, '
        'anonymous=${user.isAnonymous}, '
        'emailVerified=${user.emailVerified}, '
        'providers=$providers';
  }

  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    WidgetsBinding.instance.removeObserver(this);

    await Future.wait<void>([
      _authStateSubscription?.cancel() ?? Future<void>.value(),
      _idTokenSubscription?.cancel() ?? Future<void>.value(),
      _userChangesSubscription?.cancel() ?? Future<void>.value(),
    ]);

    await _persistQueue;

    _authStateSubscription = null;
    _idTokenSubscription = null;
    _userChangesSubscription = null;
    _isInitialized = false;

    record(
      source: 'DIAGNOSTICS',
      event: 'DISPOSED',
    );
  }
}

