// Pfad: lib/application/remembered_login_device_credential_service.dart

import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session_manager.dart';

class RememberedLoginDeviceCredentialService {
  RememberedLoginDeviceCredentialService({
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? firebaseFunctions,
    FlutterSecureStorage? secureStorage,
    AuthSessionManager? authSessionManager,
  })  : _firebaseAuth =
            firebaseAuth ?? FirebaseAuth.instance,
        _firebaseFunctions =
            firebaseFunctions ??
                FirebaseFunctions.instanceFor(
                  region: 'europe-west3',
                ),
        _secureStorage =
            secureStorage ??
                const FlutterSecureStorage(),
        _authSessionManager =
            authSessionManager ??
                AuthSessionManager.instance;

  static const String _credentialKeyPrefix =
      'luma.auth.rememberedDeviceCredential.v1.';

  static const String _installationIdKey =
      'luma.auth.installationId.v1';

  final FirebaseAuth _firebaseAuth;
  final FirebaseFunctions _firebaseFunctions;
  final FlutterSecureStorage _secureStorage;
  final AuthSessionManager _authSessionManager;

  Future<bool> hasCredentialForUser(
    String userId,
  ) async {
    final cleanedUserId =
        _requiredUserId(userId);

    return await _loadCredential(
          cleanedUserId,
        ) !=
        null;
  }

  Future<void> registerForCurrentUser() async {
    final user =
        _firebaseAuth.currentUser;

    final userId =
        user?.uid.trim();

    if (userId == null ||
        userId.isEmpty) {
      throw StateError(
        'GerÃ¤teanmeldung kann nur fÃ¼r einen angemeldeten Nutzer registriert werden.',
      );
    }

    final installationId =
        await _loadOrCreateInstallationId();

    final existing =
        await _loadCredential(userId);

    final credential =
        existing ??
            _RememberedDeviceCredential(
              userId: userId,
              credentialId:
                  _randomToken(24),
              secret:
                  _randomToken(48),
              installationId:
                  installationId,
            );

    final callable =
        _firebaseFunctions.httpsCallable(
      'registerRememberedLoginCredential',
    );

    try {
      final result =
          await callable.call(
        <String, dynamic>{
          'credentialId':
              credential.credentialId,
          'secret': credential.secret,
          'installationId':
              credential.installationId,
          'platform': _platformLabel(),
        },
      );

      final data =
          _resultMap(result.data);

      if (data['success'] != true) {
        throw const RememberedLoginCredentialException(
          code: 'invalid-server-response',
          message:
              'Die GerÃ¤teanmeldung konnte serverseitig nicht registriert werden.',
        );
      }

      final currentUserId =
          _firebaseAuth.currentUser?.uid.trim();

      if (currentUserId != userId) {
        throw const RememberedLoginCredentialException(
          code: 'user-changed',
          message:
              'Das aktive Konto hat sich wÃ¤hrend der GerÃ¤teanmeldung geÃ¤ndert.',
        );
      }

      await _saveCredential(
        credential,
      );
    } on FirebaseFunctionsException catch (error) {
      throw RememberedLoginCredentialException(
        code: error.code,
        message:
            error.message ??
                'Die GerÃ¤teanmeldung konnte nicht registriert werden.',
      );
    }
  }

  Future<UserCredential>
      signInWithRememberedCredential({
    required String userId,
  }) async {
    final cleanedUserId =
        _requiredUserId(userId);

    final credential =
        await _loadCredential(
      cleanedUserId,
    );

    if (credential == null) {
      throw const RememberedLoginCredentialException(
        code: 'credential-not-found',
        message:
            'FÃ¼r dieses Konto ist auf diesem GerÃ¤t keine Schnellanmeldung registriert.',
      );
    }

    final currentUser =
        _firebaseAuth.currentUser;

    if (currentUser != null &&
        currentUser.uid.trim() !=
            cleanedUserId) {
      final switchResult =
          await _authSessionManager
              .prepareAccountSwitch(
        targetUserId: cleanedUserId,
      );

      if (!switchResult.isSuccess) {
        throw RememberedLoginCredentialException(
          code: switchResult.code,
          message: switchResult.message,
        );
      }
    }

    final callable =
        _firebaseFunctions.httpsCallable(
      'exchangeRememberedLoginCredential',
    );

    try {
      final result =
          await callable.call(
        <String, dynamic>{
          'userId': cleanedUserId,
          'credentialId':
              credential.credentialId,
          'secret': credential.secret,
          'installationId':
              credential.installationId,
        },
      );

      final data =
          _resultMap(result.data);

      final customToken =
          (data['customToken'] as String?)
              ?.trim();

      if (data['success'] != true ||
          customToken == null ||
          customToken.isEmpty) {
        throw const RememberedLoginCredentialException(
          code: 'invalid-server-response',
          message:
              'Die Schnellanmeldung hat kein gÃ¼ltiges Anmelde-Token erhalten.',
        );
      }

      final signedIn =
          await _firebaseAuth
              .signInWithCustomToken(
        customToken,
      );

      final signedInUserId =
          signedIn.user?.uid.trim() ?? '';

      if (signedInUserId !=
          cleanedUserId) {
        if (signedInUserId.isNotEmpty) {
          await _authSessionManager
              .signOutForReason(
            expectedUserId:
                signedInUserId,
            reason:
                'remembered-credential-user-mismatch',
            markLogoutLanding: false,
          );
        }

        throw const RememberedLoginCredentialException(
          code: 'user-mismatch',
          message:
              'Die Schnellanmeldung hat ein anderes Konto zurÃ¼ckgegeben.',
        );
      }

      return signedIn;
    } on FirebaseFunctionsException catch (error) {
      if (_isCredentialInvalid(
        error.code,
      )) {
        await deleteLocalCredential(
          cleanedUserId,
        );
      }

      throw RememberedLoginCredentialException(
        code: error.code,
        message:
            error.message ??
                'Die Schnellanmeldung konnte nicht bestÃ¤tigt werden.',
      );
    }
  }

  Future<RememberedLoginRevocationResult>
      revokeForUser(
    String userId,
  ) async {
    final cleanedUserId =
        _requiredUserId(userId);

    final credential =
        await _loadCredential(
      cleanedUserId,
    );

    if (credential == null) {
      await deleteLocalCredential(
        cleanedUserId,
      );

      return const RememberedLoginRevocationResult(
        remoteRevoked: false,
        localRemoved: true,
        credentialWasMissing: true,
      );
    }

    try {
      final callable =
          _firebaseFunctions.httpsCallable(
        'revokeRememberedLoginCredential',
      );

      final result =
          await callable.call(
        <String, dynamic>{
          'userId': cleanedUserId,
          'credentialId':
              credential.credentialId,
          'secret': credential.secret,
          'installationId':
              credential.installationId,
        },
      );

      final data =
          _resultMap(result.data);

      if (data['success'] != true) {
        throw const RememberedLoginCredentialException(
          code: 'invalid-server-response',
          message:
              'Die GerÃ¤teanmeldung konnte serverseitig nicht entfernt werden.',
        );
      }

      await deleteLocalCredential(
        cleanedUserId,
      );

      return RememberedLoginRevocationResult(
        remoteRevoked: true,
        localRemoved: true,
        credentialWasMissing:
            data['alreadyRemoved'] == true,
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'REMEMBERED LOGIN CREDENTIAL REMOTE REVOKE FAILED: '
        '${error.code} / ${error.message}',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (_isCredentialInvalid(
        error.code,
      )) {
        await deleteLocalCredential(
          cleanedUserId,
        );

        return const RememberedLoginRevocationResult(
          remoteRevoked: false,
          localRemoved: true,
          credentialWasInvalid: true,
        );
      }

      throw RememberedLoginCredentialException(
        code: error.code,
        message:
            error.message ??
                'Die GerÃ¤teanmeldung konnte nicht entfernt werden.',
      );
    }
  }

  Future<void> deleteLocalCredential(
    String userId,
  ) async {
    final cleanedUserId =
        _requiredUserId(userId);

    await _secureStorage.delete(
      key: _credentialStorageKey(
        cleanedUserId,
      ),
    );
  }

  Future<_RememberedDeviceCredential?>
      _loadCredential(
    String userId,
  ) async {
    final raw =
        await _secureStorage.read(
      key: _credentialStorageKey(
        userId,
      ),
    );

    if (raw == null ||
        raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded =
          jsonDecode(raw);

      if (decoded is! Map) {
        await deleteLocalCredential(
          userId,
        );
        return null;
      }

      final credential =
          _RememberedDeviceCredential.fromMap(
        Map<String, dynamic>.from(
          decoded,
        ),
      );

      if (credential.userId != userId ||
          credential.credentialId.isEmpty ||
          credential.secret.isEmpty ||
          credential.installationId.isEmpty) {
        await deleteLocalCredential(
          userId,
        );
        return null;
      }

      return credential;
    } catch (error, stackTrace) {
      debugPrint(
        'REMEMBERED LOGIN CREDENTIAL READ FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      await deleteLocalCredential(
        userId,
      );
      return null;
    }
  }

  Future<void> _saveCredential(
    _RememberedDeviceCredential credential,
  ) async {
    await _secureStorage.write(
      key: _credentialStorageKey(
        credential.userId,
      ),
      value: jsonEncode(
        credential.toMap(),
      ),
    );
  }

  Future<String>
      _loadOrCreateInstallationId() async {
    final existing =
        (await _secureStorage.read(
      key: _installationIdKey,
    ))
            ?.trim();

    if (existing != null &&
        existing.isNotEmpty) {
      return existing;
    }

    final created =
        _randomToken(24);

    await _secureStorage.write(
      key: _installationIdKey,
      value: created,
    );

    return created;
  }

  Map<String, dynamic> _resultMap(
    Object? data,
  ) {
    if (data is! Map) {
      throw const RememberedLoginCredentialException(
        code: 'invalid-server-response',
        message:
            'Der Server hat eine ungÃ¼ltige Antwort zurÃ¼ckgegeben.',
      );
    }

    return Map<String, dynamic>.from(
      data,
    );
  }

  String _credentialStorageKey(
    String userId,
  ) {
    return '$_credentialKeyPrefix$userId';
  }

  String _randomToken(
    int byteLength,
  ) {
    final random =
        Random.secure();

    final bytes =
        List<int>.generate(
      byteLength,
      (_) => random.nextInt(256),
      growable: false,
    );

    return base64UrlEncode(
      bytes,
    ).replaceAll('=', '');
  }

  String _requiredUserId(
    String userId,
  ) {
    final cleaned =
        userId.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User-ID darf nicht leer sein.',
      );
    }

    return cleaned;
  }

  bool _isCredentialInvalid(
    String code,
  ) {
    return code == 'not-found' ||
        code == 'permission-denied' ||
        code == 'failed-precondition' ||
        code == 'unauthenticated';
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }

    return switch (
        defaultTargetPlatform) {
      TargetPlatform.android =>
        'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS =>
        'macos',
      TargetPlatform.windows =>
        'windows',
      TargetPlatform.linux =>
        'linux',
      TargetPlatform.fuchsia =>
        'fuchsia',
    };
  }
}

@immutable
class RememberedLoginRevocationResult {
  const RememberedLoginRevocationResult({
    required this.remoteRevoked,
    required this.localRemoved,
    this.credentialWasMissing = false,
    this.credentialWasInvalid = false,
  });

  final bool remoteRevoked;
  final bool localRemoved;
  final bool credentialWasMissing;
  final bool credentialWasInvalid;

  bool get completed => localRemoved;
}

class RememberedLoginCredentialException
    implements Exception {
  const RememberedLoginCredentialException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() {
    return 'RememberedLoginCredentialException($code): $message';
  }
}

@immutable
class _RememberedDeviceCredential {
  const _RememberedDeviceCredential({
    required this.userId,
    required this.credentialId,
    required this.secret,
    required this.installationId,
  });

  final String userId;
  final String credentialId;
  final String secret;
  final String installationId;

  factory _RememberedDeviceCredential.fromMap(
    Map<String, dynamic> map,
  ) {
    return _RememberedDeviceCredential(
      userId:
          (map['userId'] as String? ?? '')
              .trim(),
      credentialId:
          (map['credentialId'] as String? ?? '')
              .trim(),
      secret:
          (map['secret'] as String? ?? '')
              .trim(),
      installationId:
          (map['installationId'] as String? ?? '')
              .trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': 1,
      'userId': userId,
      'credentialId': credentialId,
      'secret': secret,
      'installationId':
          installationId,
    };
  }
}

