// Pfad: lib/features/security/application/security_remote_logout_service.dart
//
// Luma Core Rebuild 2.0
// Sicherheit & Anmeldung - Phase B2
//
// Verantwortlich ausschließlich für:
// - aktuelles Security-Gerät eindeutig prüfen
// - sensible Aktion reauthentifizieren
// - bestehende Cloud Function revokeOtherSessions aufrufen
// - aktuelles Gerät nach Token-Widerruf erneut authentifizieren
// - aktuelles Gerät in Firestore weiterhin als aktiv markieren
//
// Dieser Service führt niemals FirebaseAuth.signOut() aus.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../application/google_auth_service.dart';

enum SecurityReauthenticationMethod { password, google, unsupported }

class SecurityRemoteLogoutResult {
  const SecurityRemoteLogoutResult({
    required this.currentDeviceId,
    required this.currentDeviceWasFound,
    required this.deactivatedDeviceCount,
    required this.tokensValidAfterTime,
  });

  final String currentDeviceId;
  final bool currentDeviceWasFound;
  final int deactivatedDeviceCount;
  final String? tokensValidAfterTime;

  bool get hasDeactivatedOtherDevices => deactivatedDeviceCount > 0;
}

class SecurityRemoteLogoutException implements Exception {
  const SecurityRemoteLogoutException(
    this.message, {
    this.code = 'security-remote-logout-failed',
  });

  final String code;
  final String message;

  @override
  String toString() {
    return 'SecurityRemoteLogoutException($code): $message';
  }
}

class SecurityRemoteLogoutService {
  SecurityRemoteLogoutService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    GoogleAuthService? googleAuthService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3'),
       _googleAuthService = googleAuthService ?? GoogleAuthService.instance;

  static const String _deviceIdStorageKey = 'luma.security.deviceId';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final GoogleAuthService _googleAuthService;

  User? get currentUser => _auth.currentUser;

  SecurityReauthenticationMethod get reauthenticationMethod {
    final user = _auth.currentUser;

    if (user == null) {
      return SecurityReauthenticationMethod.unsupported;
    }

    final providerIds = user.providerData
        .map((provider) => provider.providerId.trim())
        .where((providerId) => providerId.isNotEmpty)
        .toSet();

    if (providerIds.contains('password')) {
      return SecurityReauthenticationMethod.password;
    }

    if (providerIds.contains('google.com')) {
      return SecurityReauthenticationMethod.google;
    }

    return SecurityReauthenticationMethod.unsupported;
  }

  Future<String?> loadCurrentDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final deviceId = preferences.getString(_deviceIdStorageKey)?.trim();

    if (deviceId == null || deviceId.isEmpty) {
      return null;
    }

    return deviceId;
  }

  Future<String> requireVerifiedCurrentDeviceId() async {
    final user = _requireCurrentUser();
    final deviceId = await loadCurrentDeviceId();

    if (deviceId == null || deviceId.isEmpty) {
      throw const SecurityRemoteLogoutException(
        'Dieses Gerät besitzt noch keine gültige Luma-Gerätekennung.',
        code: 'current-device-id-missing',
      );
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(deviceId)
        .get();

    if (!snapshot.exists) {
      throw const SecurityRemoteLogoutException(
        'Dieses Gerät ist nicht in der Sicherheitsverwaltung registriert.',
        code: 'current-device-not-registered',
      );
    }

    final data = snapshot.data();

    if (data == null) {
      throw const SecurityRemoteLogoutException(
        'Die Sicherheitsdaten dieses Geräts sind unvollständig.',
        code: 'current-device-data-missing',
      );
    }

    final storedDeviceId = _readString(data['id']);

    if (storedDeviceId.isNotEmpty && storedDeviceId != deviceId) {
      throw const SecurityRemoteLogoutException(
        'Die gespeicherte Gerätekennung stimmt nicht mit diesem Gerät überein.',
        code: 'current-device-id-mismatch',
      );
    }

    if (data['active'] != true) {
      throw const SecurityRemoteLogoutException(
        'Dieses Gerät ist in der Sicherheitsverwaltung nicht mehr aktiv.',
        code: 'current-device-inactive',
      );
    }

    return deviceId;
  }

  Future<SecurityRemoteLogoutResult> revokeOtherSessions({
    String? currentPassword,
  }) async {
    final userBeforeOperation = _requireCurrentUser();
    final expectedUserId = userBeforeOperation.uid.trim();

    if (expectedUserId.isEmpty) {
      throw const SecurityRemoteLogoutException(
        'Die aktuelle Anmeldung ist ungültig.',
        code: 'invalid-current-user',
      );
    }

    final currentDeviceId = await requireVerifiedCurrentDeviceId();

    await _reauthenticate(
      expectedUserId: expectedUserId,
      password: currentPassword,
      afterTokenRevocation: false,
    );

    _ensureSameUser(expectedUserId);

    final callable = _functions.httpsCallable(
      'revokeOtherSessions',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
    );

    final HttpsCallableResult<dynamic> response;

    try {
      response = await callable.call<dynamic>(<String, dynamic>{
        'currentDeviceId': currentDeviceId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw SecurityRemoteLogoutException(
        _mapFunctionsError(error),
        code: error.code,
      );
    }

    final data = _asMap(response.data);

    if (data['success'] != true) {
      throw const SecurityRemoteLogoutException(
        'Die anderen Sitzungen konnten nicht vollständig beendet werden.',
        code: 'backend-rejected-operation',
      );
    }

    final backendDeviceId = _readString(data['currentDeviceId']);

    final currentDeviceWasFound = data['currentDeviceWasFound'] == true;

    final deactivatedDeviceCount = _readInt(data['deactivatedDeviceCount']);

    final tokensValidAfterTime = _readNullableString(
      data['tokensValidAfterTime'],
    );

    if (backendDeviceId.isNotEmpty && backendDeviceId != currentDeviceId) {
      throw const SecurityRemoteLogoutException(
        'Der Server hat eine andere aktuelle Gerätekennung zurückgegeben.',
        code: 'backend-device-id-mismatch',
      );
    }

    if (!currentDeviceWasFound) {
      await _recoverCurrentDeviceDocument(
        userId: expectedUserId,
        deviceId: currentDeviceId,
      );

      throw const SecurityRemoteLogoutException(
        'Der Server konnte dieses Gerät nicht eindeutig als aktuelle Sitzung '
        'bestätigen. Die Aktion wurde aus Sicherheitsgründen nicht als '
        'erfolgreich übernommen.',
        code: 'current-device-not-found-by-backend',
      );
    }

    // revokeRefreshTokens() betrifft auch den bisherigen Refresh-Token
    // dieses Geräts. Deshalb wird unmittelbar danach erneut authentifiziert.
    await _reauthenticate(
      expectedUserId: expectedUserId,
      password: currentPassword,
      afterTokenRevocation: true,
    );

    final refreshedUser = _auth.currentUser;

    if (refreshedUser == null || refreshedUser.uid.trim() != expectedUserId) {
      throw const SecurityRemoteLogoutException(
        'Die aktuelle Sitzung konnte nach dem Sicherheitsvorgang nicht '
        'erneuert werden. Bitte melde dich erneut an.',
        code: 'current-session-not-restored',
      );
    }

    try {
      await refreshedUser.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw SecurityRemoteLogoutException(
        _mapAuthError(error),
        code: error.code,
      );
    }

    await _recoverCurrentDeviceDocument(
      userId: expectedUserId,
      deviceId: currentDeviceId,
    );

    return SecurityRemoteLogoutResult(
      currentDeviceId: currentDeviceId,
      currentDeviceWasFound: true,
      deactivatedDeviceCount: deactivatedDeviceCount,
      tokensValidAfterTime: tokensValidAfterTime,
    );
  }

  Future<void> _reauthenticate({
    required String expectedUserId,
    required String? password,
    required bool afterTokenRevocation,
  }) async {
    final user = _requireCurrentUser();

    if (user.uid.trim() != expectedUserId) {
      throw const SecurityRemoteLogoutException(
        'Das angemeldete Konto hat sich während der Sicherheitsprüfung geändert.',
        code: 'user-changed-during-operation',
      );
    }

    switch (reauthenticationMethod) {
      case SecurityReauthenticationMethod.password:
        await _reauthenticatePassword(user: user, password: password);
        break;

      case SecurityReauthenticationMethod.google:
        try {
          await _googleAuthService.reauthenticateCurrentUser(
            forceAccountSelection: !afterTokenRevocation,
          );
        } on FirebaseAuthException catch (error) {
          throw SecurityRemoteLogoutException(
            _mapAuthError(error),
            code: error.code,
          );
        } catch (_) {
          throw const SecurityRemoteLogoutException(
            'Die Google-Bestätigung konnte nicht abgeschlossen werden.',
            code: 'google-reauthentication-failed',
          );
        }
        break;

      case SecurityReauthenticationMethod.unsupported:
        throw const SecurityRemoteLogoutException(
          'Für diese Anmeldemethode kann Luma diese Sicherheitsaktion derzeit '
          'noch nicht sicher bestätigen.',
          code: 'unsupported-auth-provider',
        );
    }

    _ensureSameUser(expectedUserId);
  }

  Future<void> _reauthenticatePassword({
    required User user,
    required String? password,
  }) async {
    final cleanedPassword = password?.trim() ?? '';
    final email = user.email?.trim() ?? '';

    if (email.isEmpty) {
      throw const SecurityRemoteLogoutException(
        'Für dieses Konto ist keine E-Mail-Adresse verfügbar.',
        code: 'password-account-email-missing',
      );
    }

    if (cleanedPassword.isEmpty) {
      throw const SecurityRemoteLogoutException(
        'Bitte gib dein aktuelles Passwort ein.',
        code: 'password-required',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: cleanedPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw SecurityRemoteLogoutException(
        _mapAuthError(error),
        code: error.code,
      );
    }
  }

  Future<void> _recoverCurrentDeviceDocument({
    required String userId,
    required String deviceId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .set(<String, dynamic>{
            'id': deviceId,
            'userId': userId,
            'active': true,
            'disabledAt': null,
            'lastSeenAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      // Der Auth-Sicherheitsvorgang darf nicht rückwirkend als fehlgeschlagen
      // gelten, nur weil die Geräte-Metadaten anschließend nicht aktualisiert
      // werden konnten.
    }
  }

  User _requireCurrentUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw const SecurityRemoteLogoutException(
        'Deine Anmeldung ist nicht mehr aktiv. Bitte melde dich erneut an.',
        code: 'unauthenticated',
      );
    }

    return user;
  }

  void _ensureSameUser(String expectedUserId) {
    final currentUserId = _auth.currentUser?.uid.trim() ?? '';

    if (currentUserId != expectedUserId) {
      throw const SecurityRemoteLogoutException(
        'Das angemeldete Konto hat sich während der Sicherheitsaktion geändert.',
        code: 'user-changed-during-operation',
      );
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const <String, dynamic>{};
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }

    return 0;
  }

  static String _readString(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }

  static String? _readNullableString(Object? value) {
    final cleaned = _readString(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _mapFunctionsError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Deine Anmeldung muss erneut bestätigt werden.';

      case 'permission-denied':
        return 'Diese Sicherheitsaktion wurde vom Server nicht erlaubt.';

      case 'failed-precondition':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Die Sicherheitsaktion kann im aktuellen Zustand nicht ausgeführt werden.';

      case 'deadline-exceeded':
        return 'Der Sicherheitsserver hat zu lange gebraucht. Bitte versuche es erneut.';

      case 'unavailable':
        return 'Der Sicherheitsserver ist gerade nicht erreichbar.';

      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }

        return 'Die anderen Sitzungen konnten gerade nicht beendet werden.';
    }
  }

  static String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Das eingegebene Passwort ist nicht korrekt.';

      case 'user-mismatch':
        return 'Das bestätigte Konto stimmt nicht mit deinem angemeldeten Konto überein.';

      case 'user-not-found':
        return 'Dieses Konto konnte nicht mehr gefunden werden.';

      case 'user-disabled':
        return 'Dieses Konto ist derzeit deaktiviert.';

      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte warte einen Moment und versuche es später erneut.';

      case 'network-request-failed':
        return 'Die Sicherheitsprüfung benötigt eine Internetverbindung.';

      case 'requires-recent-login':
        return 'Bitte bestätige deine Anmeldung erneut.';

      default:
        return 'Die Anmeldung konnte für diese Sicherheitsaktion nicht bestätigt werden.';
    }
  }
}
