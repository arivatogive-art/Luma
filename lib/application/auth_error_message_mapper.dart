// Pfad: lib/application/auth_error_message_mapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'remembered_login_device_credential_service.dart';

class AuthErrorMessageMapper {
  const AuthErrorMessageMapper._();

  static String fromFirebaseAuth(FirebaseAuthException error) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'Für diese E-Mail-Adresse gibt es bereits eine andere Anmeldemethode.';
      case 'credential-already-in-use':
        return 'Diese Anmeldung ist bereits mit einem anderen Konto verbunden.';
      case 'invalid-credential':
        return 'E-Mail-Adresse oder Passwort ist nicht korrekt.';
      case 'user-not-found':
        return 'Konto nicht gefunden.';
      case 'wrong-password':
        return 'Passwort falsch.';
      case 'invalid-email':
        return 'Bitte prüfe deine E-Mail-Adresse.';
      case 'user-disabled':
        return 'Dieses Konto wurde deaktiviert.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte warte kurz und versuche es erneut.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Verbindung.';
      case 'popup-blocked':
        return 'Das Google-Fenster wurde blockiert. Bitte erlaube Pop-ups für Luma.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Google-Anmeldung wurde abgebrochen.';
      case 'operation-not-allowed':
      case 'operation-not-supported':
      case 'unauthorized-domain':
      case 'missing-google-id-token':
        return 'Diese Anmeldung ist momentan nicht verfügbar.';
      case 'remembered-device-registration-failed':
        return 'Die Anmeldung war erfolgreich, aber die Schnellanmeldung konnte nicht gespeichert werden.';
      default:
        debugPrint(
          'UNMAPPED FIREBASE AUTH ERROR: ${error.code} / ${error.message}',
        );
        return 'Anmeldung momentan nicht möglich. Bitte versuche es erneut.';
    }
  }

  static String fromGoogleSignIn(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google-Anmeldung wurde abgebrochen.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google-Anmeldung wurde unterbrochen. Bitte versuche es erneut.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Die Google-Anmeldung kann gerade nicht geöffnet werden.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Das ausgewählte Google-Konto passt nicht zu dieser Anmeldung.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google-Anmeldung ist momentan nicht verfügbar.';
      default:
        debugPrint(
          'UNMAPPED GOOGLE SIGN-IN ERROR: ${error.code} / ${error.description}',
        );
        return 'Google-Anmeldung ist momentan nicht möglich.';
    }
  }

  static String fromRememberedCredential(
    RememberedLoginCredentialException error,
  ) {
    switch (error.code) {
      case 'credential-not-found':
        return 'Die Schnellanmeldung ist auf diesem Gerät nicht mehr verfügbar.';
      case 'not-found':
      case 'permission-denied':
      case 'failed-precondition':
      case 'unauthenticated':
        return 'Die gespeicherte Anmeldung ist abgelaufen. Bitte melde dich erneut an.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Netzwerkfehler. Bitte prüfe deine Verbindung.';
      default:
        debugPrint(
          'UNMAPPED REMEMBERED LOGIN ERROR: ${error.code} / ${error.message}',
        );
        return 'Die Schnellanmeldung konnte nicht abgeschlossen werden.';
    }
  }
}
