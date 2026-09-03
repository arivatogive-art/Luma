// Pfad: lib/application/google_auth_service.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Zentrale Google-Anmeldung für Login und Registrierung.
///
/// Diese Klasse meldet Firebase niemals selbstständig ab.
/// Firebase-Abmeldungen laufen ausschließlich über AuthSessionManager.
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance =
      GoogleAuthService._();

  static const String serverClientId =
      '498819383401-7vgn39k7dlaqid8f2np6c1hdhp3js3tu.apps.googleusercontent.com';

  static const Duration _operationTimeout =
      Duration(minutes: 2);

  final FirebaseAuth _firebaseAuth =
      FirebaseAuth.instance;

  bool _isInitialized = false;
  Future<void>? _initializationFuture;
  Future<UserCredential>? _activeSignInFuture;

  Future<UserCredential> signIn({
    String? loginHint,
    bool forceAccountSelection = false,
  }) {
    final runningOperation =
        _activeSignInFuture;

    if (runningOperation != null) {
      debugPrint(
        'GOOGLE AUTH: existing sign-in operation reused',
      );
      return runningOperation;
    }

    final operation = _signInInternal(
      loginHint: loginHint,
      forceAccountSelection:
          forceAccountSelection,
    ).timeout(
      _operationTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Google Sign-In did not complete within '
          '${_operationTimeout.inSeconds} seconds.',
        );
      },
    );

    _activeSignInFuture = operation;

    operation.whenComplete(() {
      if (identical(
        _activeSignInFuture,
        operation,
      )) {
        _activeSignInFuture = null;
      }
    });

    return operation;
  }

  Future<UserCredential> _signInInternal({
    required String? loginHint,
    required bool forceAccountSelection,
  }) async {
    final cleanedLoginHint =
        loginHint?.trim();

    debugPrint(
      'GOOGLE AUTH START: '
      'web=$kIsWeb, '
      'loginHint=${cleanedLoginHint?.isNotEmpty == true ? cleanedLoginHint : 'NONE'}, '
      'forceAccountSelection=$forceAccountSelection',
    );

    if (kIsWeb) {
      return _signInOnWeb(
        loginHint: cleanedLoginHint,
        forceAccountSelection:
            forceAccountSelection,
      );
    }

    return _signInOnNative(
      forceAccountSelection:
          forceAccountSelection,
    );
  }

  Future<UserCredential> _signInOnWeb({
    required String? loginHint,
    required bool forceAccountSelection,
  }) {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');

    final parameters = <String, String>{};

    if (forceAccountSelection) {
      parameters['prompt'] = 'select_account';
    }

    if (loginHint != null &&
        loginHint.isNotEmpty) {
      parameters['login_hint'] = loginHint;
    }

    if (parameters.isNotEmpty) {
      provider.setCustomParameters(parameters);
    }

    return _firebaseAuth
        .signInWithPopup(provider);
  }

  Future<UserCredential> _signInOnNative({
    required bool forceAccountSelection,
  }) async {
    final googleSignIn =
        GoogleSignIn.instance;

    await _initializeIfNeeded();

    if (!googleSignIn.supportsAuthenticate()) {
      throw FirebaseAuthException(
        code: 'operation-not-supported',
        message:
            'Google Sign-In wird auf dieser Plattform nicht unterstützt.',
      );
    }

    if (forceAccountSelection) {
      try {
        await googleSignIn.signOut();
      } catch (error, stackTrace) {
        debugPrint(
          'GOOGLE AUTH PRE-SELECTION SIGN-OUT SKIPPED: $error',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }
    }

    final googleUser =
        await googleSignIn.authenticate();

    final authentication =
        googleUser.authentication;

    final idToken =
        authentication.idToken;

    if (idToken == null ||
        idToken.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message:
            'Google konnte kein gültiges ID-Token bereitstellen.',
      );
    }

    final credential =
        GoogleAuthProvider.credential(
      idToken: idToken,
    );

    return _firebaseAuth
        .signInWithCredential(credential);
  }

  Future<void> _initializeIfNeeded() {
    if (_isInitialized) {
      return Future<void>.value();
    }

    final runningInitialization =
        _initializationFuture;

    if (runningInitialization != null) {
      return runningInitialization;
    }

    final initialization =
        _initializeInternal();

    _initializationFuture =
        initialization;

    initialization.whenComplete(() {
      if (identical(
        _initializationFuture,
        initialization,
      )) {
        _initializationFuture = null;
      }
    });

    return initialization;
  }

  Future<void> _initializeInternal() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );

    _isInitialized = true;

    debugPrint(
      'GOOGLE AUTH INITIALIZED: '
      'serverClientId=$serverClientId',
    );
  }

  Future<void>
      signOutGoogleProviderSafely() async {
    if (kIsWeb) {
      return;
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (error, stackTrace) {
      debugPrint(
        'GOOGLE AUTH PROVIDER SIGN-OUT SKIPPED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }
}
