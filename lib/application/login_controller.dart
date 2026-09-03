// Pfad: lib/application/login_controller.dart

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/models/remembered_login_account_model.dart';
import 'auth_error_message_mapper.dart';
import 'auth_profile_bootstrap_service.dart';
import 'auth_session_manager.dart';
import 'google_auth_service.dart';
import 'remembered_login_account_storage_service.dart';
import 'remembered_login_device_credential_service.dart';
import 'remembered_login_quick_access_service.dart';
import 'security_event_service.dart';

enum RememberedLoginRecoveryType {
  none,
  password,
  google,
  phone,
}

class LoginController extends ChangeNotifier {
  LoginController({
    FirebaseAuth? firebaseAuth,
    SecurityEventService? securityEventService,
    RememberedLoginAccountStorageService?
        rememberedLoginAccountStorageService,
    RememberedLoginQuickAccessService?
        quickAccessService,
    RememberedLoginDeviceCredentialService?
        deviceCredentialService,
    AuthSessionManager? authSessionManager,
    FirebaseFunctions? firebaseFunctions,
    AuthProfileBootstrapService? authProfileBootstrapService,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
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
                AuthProfileBootstrapService();

  final FirebaseAuth _auth;
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

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isDisposed = false;

  String? _errorMessage;
  String? _infoMessage;
  String? _lastLoginEmail;

  bool _awaitingEmailVerification = false;

  RememberedLoginRecoveryType
      _rememberedLoginRecoveryType =
      RememberedLoginRecoveryType.none;

  RememberedLoginAccountModel?
      _rememberedLoginRecoveryAccount;

  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  String? get lastLoginEmail => _lastLoginEmail;
  bool get awaitingEmailVerification =>
      _awaitingEmailVerification;

  RememberedLoginRecoveryType
      get rememberedLoginRecoveryType =>
          _rememberedLoginRecoveryType;

  RememberedLoginAccountModel?
      get rememberedLoginRecoveryAccount =>
          _rememberedLoginRecoveryAccount;

  bool get requiresRememberedLoginRecovery =>
      _rememberedLoginRecoveryType !=
      RememberedLoginRecoveryType.none;

  void togglePasswordVisibility() {
    if (_isDisposed) return;

    _obscurePassword =
        !_obscurePassword;

    _notifySafely();
  }

  void clearMessages() {
    if (_errorMessage == null &&
        _infoMessage == null &&
        !_awaitingEmailVerification &&
        !requiresRememberedLoginRecovery) {
      return;
    }

    _resetMessages();
    _notifySafely();
  }

  String? validateEmail(String? value) {
    final email =
        value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Bitte gib deine E-Mail-Adresse ein.';
    }

    final emailPattern =
        RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Bitte gib eine gÃ¼ltige E-Mail-Adresse ein.';
    }

    return null;
  }

  String? validatePassword(String? value) {
    final password =
        value?.trim() ?? '';

    if (password.isEmpty) {
      return 'Bitte gib dein Passwort ein.';
    }

    if (password.length < 6) {
      return 'Das Passwort ist zu kurz.';
    }

    return null;
  }

  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberAccount = true,
  }) async {
    if (!_beginAction()) {
      return false;
    }

    final trimmedEmail =
        email.trim();

    final trimmedPassword =
        password.trim();

    final emailValidation =
        validateEmail(trimmedEmail);

    if (emailValidation != null) {
      _setError(emailValidation);
      _endAction();
      return false;
    }

    final passwordValidation =
        validatePassword(trimmedPassword);

    if (passwordValidation != null) {
      _setError(passwordValidation);
      _endAction();
      return false;
    }

    _lastLoginEmail =
        trimmedEmail;

    try {
      final credential =
          await _auth
              .signInWithEmailAndPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );

      final user =
          credential.user;

      if (user == null) {
        _setError(
          'Die Anmeldung konnte nicht abgeschlossen werden. '
          'Bitte versuche es erneut.',
        );
        return false;
      }

      await user.reload();

      final refreshedUser =
          _auth.currentUser;

      if (refreshedUser == null ||
          refreshedUser.uid.trim().isEmpty) {
        _setError(
          'Die Anmeldung konnte nicht stabil bestÃ¤tigt werden. '
          'Bitte versuche es erneut.',
        );
        return false;
      }

      if (!refreshedUser.emailVerified) {
        await _sendVerificationAndSignOutSafely(
          refreshedUser,
        );

        _awaitingEmailVerification = true;
        _infoMessage =
            'Deine E-Mail-Adresse ist noch nicht bestÃ¤tigt. '
            'Wir haben dir erneut eine Verifizierungs-Mail gesendet.';

        _notifySafely();
        return false;
      }

      await _finishSuccessfulLogin(
        user: refreshedUser,
        providerId: 'password',
        rememberAccount: rememberAccount,
      );

      return true;
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint(
        'EMAIL SIGN-IN FIREBASE ERROR: '
        '${error.code} / ${error.message}',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        AuthErrorMessageMapper
            .fromFirebaseAuth(error),
      );

      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'EMAIL SIGN-IN FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        'Ein unerwarteter Fehler ist aufgetreten.',
      );

      return false;
    } finally {
      _endAction();
    }
  }

  Future<bool> signInWithGoogle({
    bool rememberAccount = true,
    String? loginHint,
    bool forceAccountSelection = false,
  }) async {
    if (!_beginAction()) {
      return false;
    }

    try {
      return await _performGoogleSignIn(
        rememberAccount: rememberAccount,
        loginHint: loginHint,
        forceAccountSelection:
            forceAccountSelection,
        expectedUserId: null,
      );
    } finally {
      _endAction();
    }
  }

  Future<bool> continueRememberedSession({
    required String userId,
  }) async {
    if (!_beginAction()) {
      return false;
    }

    final cleanedUserId =
        userId.trim();

    if (cleanedUserId.isEmpty) {
      _setError(
        'Die gespeicherte Schnellanmeldung ist ungÃ¼ltig.',
      );
      _endAction();
      return false;
    }

    try {
      await _quickAccessService.initialize();

      final rememberedAccounts =
          await _rememberedLoginAccountStorageService.loadAccounts();

      RememberedLoginAccountModel? rememberedAccount;

      for (final account in rememberedAccounts) {
        if (account.userId.trim() == cleanedUserId) {
          rememberedAccount = account;
          break;
        }
      }

      if (rememberedAccount == null) {
        _setError(
          'Das gespeicherte Konto ist auf diesem GerÃ¤t '
          'nicht mehr vorhanden.',
        );
        return false;
      }

      final currentUser =
          _auth.currentUser;

      if (currentUser != null &&
          currentUser.uid.trim() ==
              cleanedUserId) {
        return await _continueExistingFirebaseSession(
          currentUser: currentUser,
          rememberedAccount:
              rememberedAccount,
        );
      }

      try {
        final credential =
            await _deviceCredentialService
                .signInWithRememberedCredential(
          userId: cleanedUserId,
        );

        final signedInUser =
            credential.user ??
                _auth.currentUser;

        if (signedInUser == null ||
            signedInUser.uid.trim() !=
                cleanedUserId) {
          _setError(
            'Die GerÃ¤teanmeldung hat ein anderes Konto zurÃ¼ckgegeben.',
          );
          return false;
        }

        await _finishSuccessfulLogin(
          user: signedInUser,
          providerId:
              rememberedAccount.signInProvider,
          rememberAccount: true,
          registerDeviceCredential: false,
        );

        _infoMessage =
            'Schnellanmeldung erfolgreich.';

        _notifySafely();
        return true;
      } on RememberedLoginCredentialException catch (error, stackTrace) {
        debugPrint(
          'REMEMBERED CREDENTIAL FAILED: '
          '${error.code} / ${error.message}',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );

        return await _recoverRememberedLogin(
          account: rememberedAccount,
          credentialError: error,
        );
      }
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint(
        'REMEMBERED SESSION FIREBASE ERROR: '
        '${error.code} / ${error.message}',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        AuthErrorMessageMapper
            .fromFirebaseAuth(error),
      );

      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'REMEMBERED SESSION RESTORE FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        'Die Schnellanmeldung konnte nicht abgeschlossen werden.',
      );

      return false;
    } finally {
      _endAction();
    }
  }

  Future<bool> _continueExistingFirebaseSession({
    required User currentUser,
    required RememberedLoginAccountModel
        rememberedAccount,
  }) async {
    final expectedUserId =
        rememberedAccount.userId.trim();

    try {
      await currentUser.reload();
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint(
        'EXISTING SESSION RELOAD FAILED: '
        '${error.code} / ${error.message}',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (error.code !=
              'network-request-failed' &&
          error.code !=
              'too-many-requests') {
        rethrow;
      }
    }

    final refreshedUser =
        _auth.currentUser;

    if (refreshedUser == null ||
        refreshedUser.uid.trim() !=
            expectedUserId) {
      _setError(
        'Die gespeicherte Sitzung konnte nicht bestÃ¤tigt werden.',
      );
      return false;
    }

    await _quickAccessService.unlockForUser(
      expectedUserId,
    );

    _lastLoginEmail =
        refreshedUser.email ??
            rememberedAccount.email;

    await _rememberSuccessfulLoginSafely(
      refreshedUser,
      providerId:
          rememberedAccount.signInProvider,
    );

    await _registerDeviceCredentialSafely(
      expectedUserId:
          expectedUserId,
    );

    unawaited(
      _recordSuccessfulLoginSafely(),
    );

    _infoMessage =
        'Schnellanmeldung erfolgreich.';

    _notifySafely();
    return true;
  }

  Future<bool> _recoverRememberedLogin({
    required RememberedLoginAccountModel
        account,
    required RememberedLoginCredentialException
        credentialError,
  }) async {
    final provider =
        _normalizeProvider(
      account.signInProvider,
    );

    final isCredentialUnavailable =
        credentialError.code ==
                'credential-not-found' ||
            credentialError.code ==
                'not-found' ||
            credentialError.code ==
                'permission-denied' ||
            credentialError.code ==
                'failed-precondition' ||
            credentialError.code ==
                'unauthenticated' ||
            credentialError.code ==
                'revocation-incomplete';

    if (!isCredentialUnavailable) {
      _setError(
        AuthErrorMessageMapper
            .fromRememberedCredential(
          credentialError,
        ),
      );
      return false;
    }

    switch (provider) {
      case 'google.com':
        return _performGoogleSignIn(
          rememberAccount: true,
          loginHint: account.email,
          forceAccountSelection: false,
          expectedUserId:
              account.userId,
        );

      case 'phone':
        _setRememberedRecovery(
          type:
              RememberedLoginRecoveryType.phone,
          account: account,
          message:
              'BestÃ¤tige dieses Konto einmal erneut mit deiner '
              'Telefonnummer. Danach funktioniert die '
              'Schnellanmeldung wieder.',
        );
        return false;

      case 'password':
      default:
        _lastLoginEmail =
            account.email;

        _setRememberedRecovery(
          type:
              RememberedLoginRecoveryType.password,
          account: account,
          message:
              'BestÃ¤tige dieses Konto einmal erneut mit deinem '
              'Passwort. Danach funktioniert die Schnellanmeldung '
              'wieder.',
        );
        return false;
    }
  }

  Future<bool> _performGoogleSignIn({
    required bool rememberAccount,
    required String? loginHint,
    required bool forceAccountSelection,
    required String? expectedUserId,
  }) async {
    _resetMessages();

    try {
      final userCredential =
          await GoogleAuthService.instance.signIn(
        loginHint: loginHint,
        forceAccountSelection:
            forceAccountSelection,
      );

      final user =
          userCredential.user;

      if (user == null) {
        _setError(
          'Die Google-Anmeldung konnte nicht abgeschlossen werden. '
          'Bitte versuche es erneut.',
        );
        return false;
      }

      await user.reload();

      final refreshedUser =
          _auth.currentUser;

      if (refreshedUser == null ||
          refreshedUser.uid.trim().isEmpty) {
        _setError(
          'Die Google-Anmeldung konnte nicht stabil bestÃ¤tigt werden. '
          'Bitte versuche es erneut.',
        );
        return false;
      }

      if (expectedUserId != null &&
          expectedUserId.trim().isNotEmpty &&
          refreshedUser.uid.trim() !=
              expectedUserId.trim()) {
        await _authSessionManager
            .signOutForReason(
          expectedUserId:
              refreshedUser.uid,
          reason:
              'google-remembered-account-mismatch',
          signOutGoogleProvider: true,
          markLogoutLanding: false,
        );

        _setError(
          'Dieses Google-Konto gehÃ¶rt nicht zur ausgewÃ¤hlten '
          'Luma-Kontokarte. Bitte wÃ¤hle das passende Google-Konto.',
        );
        return false;
      }

      _lastLoginEmail =
          refreshedUser.email ??
              user.email;

      await _finishSuccessfulLogin(
        user: refreshedUser,
        providerId: 'google.com',
        rememberAccount: rememberAccount,
      );

      return true;
    } on GoogleSignInException catch (error, stackTrace) {
      debugPrint(
        'GOOGLE SIGN-IN EXCEPTION: '
        '${error.code} / ${error.description}',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (error.code ==
          GoogleSignInExceptionCode.canceled) {
        _setInfo(
          'Google-Anmeldung wurde abgebrochen.',
        );
      } else {
        _setError(
          AuthErrorMessageMapper
              .fromGoogleSignIn(error),
        );
      }

      return false;
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint(
        'FIREBASE GOOGLE SIGN-IN EXCEPTION: '
        '${error.code} / ${error.message}',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        AuthErrorMessageMapper
            .fromFirebaseAuth(error),
      );

      return false;
    } on TimeoutException catch (error, stackTrace) {
      debugPrint(
        'GOOGLE SIGN-IN TIMEOUT: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        'Google antwortet momentan nicht. Bitte versuche es erneut.',
      );

      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'GOOGLE SIGN-IN FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        'Google-Anmeldung fehlgeschlagen. Bitte versuche es erneut.',
      );

      return false;
    }
  }

  Future<void> clearRememberedQuickAccess() async {
    final userId =
        _auth.currentUser?.uid.trim() ?? '';

    if (userId.isEmpty) {
      return;
    }

    try {
      await _quickAccessService.unlockForUser(
        userId,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'QUICK ACCESS COULD NOT BE CLEARED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> sendPasswordReset({
    required String email,
  }) async {
    if (!_beginAction()) {
      return;
    }

    final trimmedEmail =
        email.trim().toLowerCase();

    final emailValidation =
        validateEmail(trimmedEmail);

    if (emailValidation != null) {
      _setError(
        'Bitte gib eine gÃ¼ltige E-Mail-Adresse ein.',
      );
      _endAction();
      return;
    }

    _lastLoginEmail =
        trimmedEmail;

    try {
      final callable =
          _firebaseFunctions.httpsCallable(
        'requestLumaPasswordReset',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 35),
        ),
      );

      await callable.call(
        <String, dynamic>{
          'email': trimmedEmail,
        },
      );

      _setInfo(
        'Falls ein Luma-Konto zu dieser E-Mail-Adresse existiert, '
        'haben wir dir einen sicheren Link gesendet.',
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'LUMA PASSWORD RESET FUNCTION ERROR: '
        '${error.code} / ${error.message}',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      switch (error.code) {
        case 'invalid-argument':
          _setError(
            'Bitte gib eine gÃ¼ltige E-Mail-Adresse ein.',
          );
          break;

        case 'resource-exhausted':
          _setError(
            'Zu viele Anfragen. Bitte warte kurz und versuche es erneut.',
          );
          break;

        case 'deadline-exceeded':
        case 'unavailable':
          _setError(
            'Der E-Mail-Versand ist momentan nicht erreichbar. '
            'Bitte versuche es gleich noch einmal.',
          );
          break;

        default:
          _setError(
            'Die Reset-E-Mail konnte momentan nicht gesendet werden.',
          );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'LUMA PASSWORD RESET FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        'Die Reset-E-Mail konnte momentan nicht gesendet werden.',
      );
    } finally {
      _endAction();
    }
  }

  Future<void> resendVerificationEmail() async {
    if (!_beginAction()) {
      return;
    }

    try {
      final currentUser =
          _auth.currentUser;

      if (currentUser != null &&
          !currentUser.emailVerified) {
        await _requestLumaEmailVerification();

        _awaitingEmailVerification = true;

        _setInfo(
          'Verifizierungs-Mail erneut gesendet.',
        );
        return;
      }

      final email =
          _lastLoginEmail?.trim() ?? '';

      if (email.isEmpty) {
        _setError(
          'Es ist noch keine E-Mail-Adresse vorhanden.',
        );
      } else {
        _awaitingEmailVerification = true;

        _setInfo(
          'Melde dich erneut mit $email an. '
          'Luma prÃ¼ft dann die BestÃ¤tigung und sendet bei Bedarf '
          'eine neue Verifizierungs-Mail.',
        );
      }
    } on FirebaseAuthException catch (error) {
      _setError(
        AuthErrorMessageMapper
            .fromFirebaseAuth(error),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'VERIFICATION RESEND FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _setError(
        'Fehler beim Senden der Verifizierung.',
      );
    } finally {
      _endAction();
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

  Future<void> _finishSuccessfulLogin({
    required User user,
    required String providerId,
    required bool rememberAccount,
    bool registerDeviceCredential = true,
  }) async {
    final userId =
        user.uid.trim();

    if (userId.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-user',
        message:
            'Die angemeldete User-ID ist leer.',
      );
    }

    final profileReady =
        await _authProfileBootstrapService.ensureCurrentUserProfile();

    if (!profileReady) {
      throw StateError(
        'Das Luma-Profil konnte nach der Anmeldung '
        'nicht vollstÃ¤ndig vorbereitet werden.',
      );
    }

    await _quickAccessService.initialize();

    if (rememberAccount) {
      await _rememberSuccessfulLoginSafely(
        user,
        providerId: providerId,
      );

      await _quickAccessService.saveDecision(
        userId: userId,
        enabled: true,
      );

      if (registerDeviceCredential) {
        await _registerDeviceCredentialSafely(
          expectedUserId: userId,
        );
      }
    }

    await _quickAccessService.unlockForUser(
      userId,
    );

    _clearRememberedRecovery();

    unawaited(
      _recordSuccessfulLoginSafely(),
    );
  }

  Future<void> _sendVerificationAndSignOutSafely(
    User user,
  ) async {
    try {
      await _requestLumaEmailVerification();
    } catch (error, stackTrace) {
      debugPrint(
        'EMAIL VERIFICATION SEND FAILED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }

    final currentUser =
        _auth.currentUser;

    if (currentUser != null &&
        currentUser.uid == user.uid) {
      await _authSessionManager
          .signOutForReason(
        expectedUserId: user.uid,
        reason: 'email-not-verified',
        markLogoutLanding: true,
      );
    }
  }

  Future<void> _registerDeviceCredentialSafely({
    required String expectedUserId,
  }) async {
    try {
      final currentUserId =
          _auth.currentUser?.uid.trim();

      if (currentUserId == null ||
          currentUserId.isEmpty ||
          currentUserId !=
              expectedUserId) {
        return;
      }

      await _deviceCredentialService
          .registerForCurrentUser();
    } catch (error, stackTrace) {
      debugPrint(
        'REMEMBERED DEVICE CREDENTIAL REGISTRATION SKIPPED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (_infoMessage == null) {
        _infoMessage =
            'Du bist angemeldet. Die Schnellanmeldung wird beim '
            'nÃ¤chsten passenden Zeitpunkt erneut eingerichtet.';
        _notifySafely();
      }
    }
  }

  Future<void> _recordSuccessfulLoginSafely() async {
    try {
      await _securityEventService
          .recordSuccessfulLogin();
    } catch (error, stackTrace) {
      debugPrint(
        'SECURITY LOGIN EVENT SKIPPED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _rememberSuccessfulLoginSafely(
    User user, {
    required String providerId,
  }) async {
    try {
      final userId =
          user.uid.trim();

      if (userId.isEmpty) {
        return;
      }

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
              email != null &&
                      email.isNotEmpty
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
          signInProvider:
              _normalizeProvider(
            providerId,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'REMEMBERED LOGIN ACCOUNT WRITE SKIPPED: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  String _normalizeProvider(String value) {
    final cleaned =
        value.trim().toLowerCase();

    if (cleaned == 'google' ||
        cleaned == 'google.com') {
      return 'google.com';
    }

    if (cleaned == 'phone' ||
        cleaned == 'phone_number') {
      return 'phone';
    }

    return 'password';
  }

  bool _beginAction() {
    if (_isDisposed ||
        _isLoading) {
      return false;
    }

    _resetMessages();
    _setLoading(true);
    return true;
  }

  void _endAction() {
    _setLoading(false);
  }

  void _resetMessages() {
    _errorMessage = null;
    _infoMessage = null;
    _awaitingEmailVerification = false;
    _clearRememberedRecovery();
  }

  void _setRememberedRecovery({
    required RememberedLoginRecoveryType
        type,
    required RememberedLoginAccountModel
        account,
    required String message,
  }) {
    _rememberedLoginRecoveryType =
        type;

    _rememberedLoginRecoveryAccount =
        account;

    _errorMessage = null;
    _infoMessage = message.trim();

    _notifySafely();
  }

  void _clearRememberedRecovery() {
    _rememberedLoginRecoveryType =
        RememberedLoginRecoveryType.none;

    _rememberedLoginRecoveryAccount =
        null;
  }

  void _setError(String message) {
    final cleaned =
        message.trim();

    _errorMessage =
        cleaned.isEmpty
            ? null
            : cleaned;

    _infoMessage = null;
    _notifySafely();
  }

  void _setInfo(String message) {
    final cleaned =
        message.trim();

    _infoMessage =
        cleaned.isEmpty
            ? null
            : cleaned;

    _errorMessage = null;
    _notifySafely();
  }

  void _setLoading(bool value) {
    if (_isDisposed ||
        _isLoading == value) {
      return;
    }

    _isLoading = value;
    _notifySafely();
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}



