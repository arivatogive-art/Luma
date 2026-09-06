// Pfad: lib/application/account_security_service.dart

import 'package:firebase_auth/firebase_auth.dart';

class AccountSecurityService {
  AccountSecurityService({
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  bool get isPasswordAccount {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  bool get isGoogleAccount {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  bool get isPhoneAccount {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any(
      (provider) => provider.providerId == 'phone',
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountSecurityException(
        'Deine Anmeldung ist nicht mehr aktiv. Bitte melde dich erneut an.',
      );
    }

    if (!isPasswordAccount) {
      if (isGoogleAccount) {
        throw const AccountSecurityException(
          'Dieses Konto verwendet Google zur Anmeldung. '
          'Ein separates Luma-Passwort wird für dieses Konto nicht verwaltet.',
        );
      }

      if (isPhoneAccount) {
        throw const AccountSecurityException(
          'Dieses Konto verwendet die Telefonnummer zur Anmeldung. '
          'Ein Passwort kann für diesen Kontotyp hier nicht geändert werden.',
        );
      }

      throw const AccountSecurityException(
        'Für dieses Konto ist derzeit keine Passwortänderung verfügbar.',
      );
    }

    final email = user.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      throw const AccountSecurityException(
        'Für dieses Konto ist keine Anmelde-E-Mail-Adresse hinterlegt.',
      );
    }

    if (currentPassword.isEmpty) {
      throw const AccountSecurityException(
        'Bitte gib dein aktuelles Passwort ein.',
      );
    }

    if (newPassword.length < 8) {
      throw const AccountSecurityException(
        'Das neue Passwort muss mindestens 8 Zeichen lang sein.',
      );
    }

    if (newPassword == currentPassword) {
      throw const AccountSecurityException(
        'Das neue Passwort muss sich vom aktuellen Passwort unterscheiden.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AccountSecurityException(_messageForFirebaseError(error));
    }
  }

  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountSecurityException(
        'Deine Anmeldung ist nicht mehr aktiv. Bitte melde dich erneut an.',
      );
    }

    final currentEmail = user.email?.trim().toLowerCase() ?? '';
    final cleanedNewEmail = newEmail.trim().toLowerCase();
    final cleanedPassword = currentPassword;

    if (!isPasswordAccount) {
      if (isGoogleAccount) {
        throw const AccountSecurityException(
          'Dieses Konto verwendet Google zur Anmeldung. '
          'Die Anmelde-E-Mail wird deshalb über dein Google-Konto verwaltet.',
        );
      }

      if (isPhoneAccount) {
        throw const AccountSecurityException(
          'Dieses Konto verwendet die Telefonnummer zur Anmeldung. '
          'Eine Passwort-Bestätigung für die E-Mail-Änderung ist hier nicht verfügbar.',
        );
      }

      throw const AccountSecurityException(
        'Für dieses Konto ist derzeit keine sichere E-Mail-Änderung verfügbar.',
      );
    }

    if (currentEmail.isEmpty) {
      throw const AccountSecurityException(
        'Für dieses Konto ist keine aktuelle E-Mail-Adresse hinterlegt.',
      );
    }

    if (!_looksLikeEmail(cleanedNewEmail)) {
      throw const AccountSecurityException(
        'Bitte gib eine gültige neue E-Mail-Adresse ein.',
      );
    }

    if (cleanedNewEmail == currentEmail) {
      throw const AccountSecurityException(
        'Die neue E-Mail-Adresse entspricht deiner aktuellen Adresse.',
      );
    }

    if (cleanedPassword.isEmpty) {
      throw const AccountSecurityException(
        'Bitte gib dein aktuelles Passwort ein.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: cleanedPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.verifyBeforeUpdateEmail(cleanedNewEmail);
    } on FirebaseAuthException catch (error) {
      throw AccountSecurityException(_messageForFirebaseError(error));
    }
  }

  static bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    final dot = value.lastIndexOf('.');
    return at > 0 && dot > at + 1 && dot < value.length - 1;
  }

  static String _messageForFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Das aktuelle Passwort ist nicht korrekt.';
      case 'invalid-email':
        return 'Bitte gib eine gültige E-Mail-Adresse ein.';
      case 'email-already-in-use':
        return 'Diese E-Mail-Adresse wird bereits von einem anderen Konto verwendet.';
      case 'requires-recent-login':
        return 'Bitte bestätige deine Anmeldung erneut und versuche es noch einmal.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte warte kurz und versuche es später erneut.';
      case 'network-request-failed':
        return 'Keine stabile Internetverbindung. Bitte versuche es erneut.';
      case 'operation-not-allowed':
        return 'Die E-Mail-Änderung ist für dieses Konto derzeit nicht verfügbar.';
      case 'user-disabled':
        return 'Dieses Konto ist derzeit deaktiviert.';
      case 'user-not-found':
        return 'Das angemeldete Konto wurde nicht gefunden.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Die E-Mail-Änderung konnte nicht gestartet werden.';
    }
  }
}

class AccountSecurityException implements Exception {
  const AccountSecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}
