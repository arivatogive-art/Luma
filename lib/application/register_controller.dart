// Pfad: lib/application/register_controller.dart

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/legal_consent_repository.dart';
import '../domain/models/remembered_login_account_model.dart';
import 'auth_error_message_mapper.dart';
import 'auth_profile_bootstrap_service.dart';
import 'auth_session_manager.dart';
import 'google_auth_service.dart';
import 'remembered_login_account_storage_service.dart';
import 'remembered_login_device_credential_service.dart';
import 'remembered_login_quick_access_service.dart';
import 'registration_session_guard.dart';
import 'security_event_service.dart';

class RegisterController extends ChangeNotifier {
  RegisterController({
    FirebaseAuth? firebaseAuth,
    SecurityEventService? securityEventService,
    RememberedLoginAccountStorageService?
        rememberedLoginAccountStorageService,
    RememberedLoginQuickAccessService? quickAccessService,
    RememberedLoginDeviceCredentialService?
        deviceCredentialService,
    AuthSessionManager? authSessionManager,
    FirebaseFunctions? firebaseFunctions,
    AuthProfileBootstrapService? authProfileBootstrapService,
    LegalConsentRepository? legalConsentRepository,
  })  : _firebaseAuth =
            firebaseAuth ?? FirebaseAuth.instance,
        _securityEventService =
            securityEventService ??
                const SecurityEventService(),
        _rememberedLoginAccountStorageService =
            rememberedLoginAccountStorageService ??
                const RememberedLoginAccountStorageService(),
        _quickAccessService =
            quickAccessService ??
                RememberedLoginQuickAccessService.instance,
        _deviceCredentialService =
            deviceCredentialService ??
                RememberedLoginDeviceCredentialService(),
        _authSessionManager =
            authSessionManager ??
                AuthSessionManager.instance,
        _firebaseFunctions =
            firebaseFunctions ??
                FirebaseFunctions.instanceFor(
                  region: 'europe-west3',
                ),
        _authProfileBootstrapService =
            authProfileBootstrapService ??
                AuthProfileBootstrapService(),
        _legalConsentRepository =
            legalConsentRepository ??
                LegalConsentRepository();


  final FirebaseAuth _firebaseAuth;
  final SecurityEventService _securityEventService;
  final RememberedLoginAccountStorageService
      _rememberedLoginAccountStorageService;
  final RememberedLoginQuickAccessService
      _quickAccessService;
  final RememberedLoginDeviceCredentialService
      _deviceCredentialService;
  final AuthSessionManager _authSessionManager;
  final FirebaseFunctions _firebaseFunctions;
  final AuthProfileBootstrapService _authProfileBootstrapService;
  final LegalConsentRepository _legalConsentRepository;
  final RegistrationSessionGuard _registrationSessionGuard =
      RegistrationSessionGuard.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isDisposed = false;

  String? _errorMessage;
  String? _infoMessage;

  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirmPassword =>
      _obscureConfirmPassword;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _obscureConfirmPassword =
        !_obscureConfirmPassword;
    notifyListeners();
  }

  void clearMessages() {
    if (_errorMessage == null &&
        _infoMessage == null) {
      return;
    }

    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  String? validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Bitte gib deinen Namen ein.';
    }

    if (name.length < 2) {
      return 'Der Name ist zu kurz.';
    }

    return null;
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Bitte gib deine E-Mail-Adresse ein.';
    }

    final pattern =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!pattern.hasMatch(email)) {
      return 'Bitte gib eine gültige E-Mail-Adresse ein.';
    }

    return null;
  }

  String? validatePassword(String? value) {
    final password = value?.trim() ?? '';

    if (password.isEmpty) {
      return 'Bitte gib ein Passwort ein.';
    }

    if (password.length < 6) {
      return 'Das Passwort muss mindestens 6 Zeichen lang sein.';
    }

    return null;
  }

  String? validateConfirmPassword({
    required String? value,
    required String password,
  }) {
    final confirmation = value?.trim() ?? '';
    final cleanedPassword = password.trim();

    if (confirmation.isEmpty) {
      return 'Bitte bestätige dein Passwort.';
    }

    if (confirmation != cleanedPassword) {
      return 'Die Passwörter stimmen nicht überein.';
    }

    return null;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required bool acceptedTerms,
    required bool acceptedPrivacy,
  }) async {
    if (_isLoading) return false;

    _resetMessages();

    if (!_validateLegalAcceptance(
      acceptedTerms: acceptedTerms,
      acceptedPrivacy: acceptedPrivacy,
    )) {
      return false;
    }

    final cleanedName = name.trim();
    final cleanedEmail = email.trim();
    final cleanedPassword = password.trim();
    final cleanedConfirmation =
        confirmPassword.trim();

    final nameError =
        validateName(cleanedName);
    if (nameError != null) {
      _errorMessage = nameError;
      notifyListeners();
      return false;
    }

    final emailError =
        validateEmail(cleanedEmail);
    if (emailError != null) {
      _errorMessage = emailError;
      notifyListeners();
      return false;
    }

    final passwordError =
        validatePassword(cleanedPassword);
    if (passwordError != null) {
      _errorMessage = passwordError;
      notifyListeners();
      return false;
    }

    final confirmationError =
        validateConfirmPassword(
      value: cleanedConfirmation,
      password: cleanedPassword,
    );

    if (confirmationError != null) {
      _errorMessage = confirmationError;
      notifyListeners();
      return false;
    }

    _setLoading(true);

    try {
      final credential =
          await _firebaseAuth
              .createUserWithEmailAndPassword(
        email: cleanedEmail,
        password: cleanedPassword,
      );

      final user = credential.user;

      if (user == null) {
        _errorMessage =
            'Die Registrierung konnte nicht abgeschlossen werden. Bitte versuche es erneut.';
        return false;
      }

      // Firebase veröffentlicht den neuen User sofort über userChanges().
      // AuthGate darf ihn während Consent + Verifizierungsversand noch nicht
      // als "liegen gebliebenes unbestätigtes Konto" abmelden.
      _registrationSessionGuard.protectUser(user.uid);

      await user.updateDisplayName(cleanedName);
      await user.reload();

      final refreshedUser =
          _firebaseAuth.currentUser ?? user;

      final legalConsentRecorded =
          await _recordEmailRegistrationConsentOrRollback(
        refreshedUser,
      );

      if (!legalConsentRecorded) {
        return false;
      }

      try {
        await _requestLumaEmailVerification();
      } catch (error, stackTrace) {
        debugPrint(
          'REGISTER VERIFICATION MAIL FAILED: $error',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }

      final signOutResult =
          await _authSessionManager.signOutForReason(
        expectedUserId: refreshedUser.uid,
        reason: 'email-registration-awaiting-verification',
        markLogoutLanding: true,
      );

      // Ab hier ist die Registrierungsphase beendet. AuthGate darf wieder
      // seine normale Schutzlogik für unbestätigte Passwortkonten anwenden.
      _registrationSessionGuard.releaseUser(refreshedUser.uid);

      if (!signOutResult.isSuccess) {
        debugPrint(
          'EMAIL REGISTRATION CONTROLLED SIGN-OUT FAILED: '
          '${signOutResult.code} / ${signOutResult.message}',
        );

        _errorMessage =
            'Dein Konto wurde erstellt, aber die Anmeldung konnte '
            'nicht vollständig abgeschlossen werden. Bitte starte Luma '
            'neu und melde dich nach der E-Mail-Bestätigung an.';
        return false;
      }

      _infoMessage =
          'Dein Konto wurde erstellt. Bitte bestätige deine E-Mail-Adresse und melde dich danach an.';

      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage =
          AuthErrorMessageMapper.fromFirebaseAuth(
        error,
      );
      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'EMAIL REGISTRATION FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _errorMessage =
          'Die Registrierung konnte nicht abgeschlossen werden. Bitte versuche es erneut.';
      return false;
    } finally {
      // Falls irgendein Schritt vor dem kontrollierten Sign-out scheitert,
      // darf kein Schutzstatus hängen bleiben.
      _registrationSessionGuard.clear();
      _setLoading(false);
    }
  }


  Future<bool> _recordEmailRegistrationConsentOrRollback(
    User user,
  ) async {
    final userId = user.uid.trim();

    if (userId.isEmpty) {
      _errorMessage =
          'Die Registrierung konnte keinem gültigen Konto zugeordnet werden.';
      return false;
    }

    try {
      await _legalConsentRepository.recordRegistrationConsent(
        userId: userId,
        source: 'email',
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'REGISTER LEGAL CONSENT FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      // Bei E-Mail/Passwort wurde das Firebase-Konto gerade erst erstellt.
      // Wenn der verpflichtende Zustimmungsnachweis nicht gespeichert werden
      // konnte, versuchen wir den frisch erstellten Account zurückzurollen.
      // So bleibt möglichst kein halbfertiges Konto zurück.
      try {
        await user.delete();
      } catch (rollbackError, rollbackStackTrace) {
        debugPrint(
          'REGISTER LEGAL CONSENT ROLLBACK FAILED: $rollbackError',
        );
        debugPrintStack(
          stackTrace: rollbackStackTrace,
        );

        try {
          await _firebaseAuth.signOut();
        } catch (_) {
          // Der ursprüngliche Fehler bleibt maßgeblich.
        }
      }

      _errorMessage =
          'Die rechtliche Bestätigung konnte nicht sicher gespeichert werden. '
          'Bitte versuche die Registrierung erneut.';

      return false;
    }
  }

  Future<void> _requestLumaEmailVerification() async {
    final callable = _firebaseFunctions.httpsCallable(
      'requestLumaEmailVerification',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 35),
      ),
    );

    await callable.call(<String, dynamic>{});
  }

  Future<bool> registerWithGoogle({
    required bool acceptedTerms,
    required bool acceptedPrivacy,
  }) async {
    if (_isLoading) return false;

    _resetMessages();

    if (!_validateLegalAcceptance(
      acceptedTerms: acceptedTerms,
      acceptedPrivacy: acceptedPrivacy,
    )) {
      return false;
    }

    _setLoading(true);

    try {
      final credential =
          await GoogleAuthService.instance.signIn(
        forceAccountSelection: true,
      );

      final user = credential.user;

      if (user == null) {
        _errorMessage =
            'Google konnte dein Konto nicht öffnen. Bitte versuche es erneut.';
        return false;
      }

      await user.reload();

      final refreshedUser =
          _firebaseAuth.currentUser ?? user;

      final userId =
          refreshedUser.uid.trim();

      if (userId.isEmpty) {
        _errorMessage =
            'Die Google-Anmeldung hat kein gültiges Konto zurückgegeben.';
        return false;
      }

      await _quickAccessService.initialize();
      await _quickAccessService.saveDecision(
        userId: userId,
        enabled: true,
      );
      await _quickAccessService.unlockForUser(userId);

      _infoMessage =
          'Google-Anmeldung erfolgreich.';

      await _finishGoogleRegistrationSafely(
        refreshedUser,
      );

      await _legalConsentRepository.recordRegistrationConsent(
        userId: userId,
        source: 'google',
      );

      return true;
    } on GoogleSignInException catch (error) {
      debugPrint(
        'GOOGLE REGISTRATION FAILED: '
        '${error.code} / ${error.description}',
      );

      if (error.code ==
          GoogleSignInExceptionCode.canceled) {
        _infoMessage =
            'Google-Anmeldung wurde abgebrochen.';
      } else {
        _errorMessage =
            AuthErrorMessageMapper
                .fromGoogleSignIn(error);
      }

      return false;
    } on FirebaseAuthException catch (error) {
      _errorMessage =
          AuthErrorMessageMapper.fromFirebaseAuth(
        error,
      );
      return false;
    } on TimeoutException catch (error, stackTrace) {
      debugPrint(
        'GOOGLE REGISTRATION TIMEOUT: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _errorMessage =
          'Google antwortet momentan nicht. Bitte versuche es erneut.';

      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'GOOGLE REGISTRATION FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _errorMessage =
          'Google-Anmeldung fehlgeschlagen. Bitte versuche es erneut.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void>
      _finishGoogleRegistrationSafely(
    User user,
  ) async {
    final profileReady =
        await _authProfileBootstrapService.ensureCurrentUserProfile();

    if (!profileReady) {
      throw StateError(
        'Das Luma-Profil konnte nach der Google-Anmeldung '
        'nicht vollständig vorbereitet werden.',
      );
    }

    await Future.wait<void>([
      _rememberGoogleAccountSafely(user),
      _recordSuccessfulLoginSafely(),
      _registerDeviceCredentialSafely(),
    ]);
  }

  Future<void>
      _recordSuccessfulLoginSafely() async {
    try {
      await _securityEventService
          .recordSuccessfulLogin();
    } catch (error, stackTrace) {
      debugPrint(
        'REGISTER SECURITY EVENT SKIPPED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void>
      _registerDeviceCredentialSafely() async {
    try {
      await _deviceCredentialService
          .registerForCurrentUser();
    } catch (error, stackTrace) {
      debugPrint(
        'REGISTER DEVICE CREDENTIAL SKIPPED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _rememberGoogleAccountSafely(
    User user,
  ) async {
    try {
      final userId = user.uid.trim();
      if (userId.isEmpty) return;

      final displayName =
          user.displayName?.trim();

      final email =
          user.email?.trim();

      final phoneNumber =
          user.phoneNumber?.trim();

      final avatarUrl =
          user.photoURL?.trim();

      final fallbackName =
          displayName != null &&
                  displayName.isNotEmpty
              ? displayName
              : email != null &&
                      email.isNotEmpty
                  ? email.split('@').first
                  : 'Luma Nutzer';

      await _rememberedLoginAccountStorageService
          .upsertAccount(
        RememberedLoginAccountModel(
          userId: userId,
          displayName: fallbackName,
          email:
              email != null && email.isNotEmpty
                  ? email
                  : null,
          phoneNumber:
              phoneNumber != null &&
                      phoneNumber.isNotEmpty
                  ? phoneNumber
                  : null,
          avatarUrl:
              avatarUrl != null &&
                      avatarUrl.isNotEmpty
                  ? avatarUrl
                  : null,
          lastLoginAt: DateTime.now(),
          signInProvider: 'google.com',
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'REGISTER REMEMBERED ACCOUNT SKIPPED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  bool _validateLegalAcceptance({
    required bool acceptedTerms,
    required bool acceptedPrivacy,
  }) {
    if (acceptedTerms && acceptedPrivacy) {
      return true;
    }

    _errorMessage =
        'Bitte bestätige die Nutzungsbedingungen und die Datenschutzerklärung.';
    notifyListeners();
    return false;
  }

  void _resetMessages() {
    _errorMessage = null;
    _infoMessage = null;
  }

  void _setLoading(bool value) {
    if (_isDisposed ||
        _isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
