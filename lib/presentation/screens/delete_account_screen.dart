// Pfad: lib/presentation/screens/delete_account_screen.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/account_deletion_service.dart';
import '../../application/account_security_service.dart';
import '../../application/auth_session_manager.dart';
import '../../application/google_auth_service.dart';
import '../../application/remembered_login_account_storage_service.dart';
import '../../application/remembered_login_device_credential_service.dart';
import '../../application/remembered_login_quick_access_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final AccountSecurityService _security = AccountSecurityService();
  final AccountDeletionService _deletion = AccountDeletionService();

  final RememberedLoginAccountStorageService _accountStorage =
      const RememberedLoginAccountStorageService();

  final RememberedLoginQuickAccessService _quickAccess =
      RememberedLoginQuickAccessService.instance;

  final RememberedLoginDeviceCredentialService _deviceCredentialService =
      RememberedLoginDeviceCredentialService();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmationController = TextEditingController();

  static const String _confirmationWord = 'LÖSCHEN';

  bool _obscurePassword = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid.trim() ?? '';

    if (user == null || userId.isEmpty) {
      _setError(
        'Deine Anmeldung ist nicht mehr aktiv. Bitte melde dich erneut an.',
      );
      return;
    }

    if (_confirmationController.text.trim().toUpperCase() !=
        _confirmationWord) {
      _setError('Gib zur Bestätigung $_confirmationWord ein.');
      return;
    }

    final isPasswordAccount = _security.isPasswordAccount;
    final isGoogleAccount = _security.isGoogleAccount;

    if (!isPasswordAccount && !isGoogleAccount) {
      _setError(
        _security.isPhoneAccount
            ? 'Konten mit Telefonnummer können hier noch nicht sicher erneut bestätigt werden.'
            : 'Für diese Anmeldeart ist die sichere Kontolöschung derzeit nicht verfügbar.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konto endgültig löschen?'),
          content: const Text(
            'Dieser Vorgang kann nicht rückgängig gemacht werden. '
            'Dein Luma-Konto und die dazugehörigen Kontodaten '
            'werden dauerhaft entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Endgültig löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      if (isPasswordAccount) {
        await _confirmPasswordAccount();
      } else {
        await _confirmGoogleAccount();
      }

      final deletionResult = await _deletion.deleteCurrentAccount();

      await _cleanupDeletedAccountLocally(deletionResult.userId);
    } on AccountSecurityException catch (error) {
      _setError(error.message);
    } on FirebaseAuthException catch (error) {
      _setError(_messageForAuthError(error));
    } on TimeoutException {
      _setError(
        'Die Sicherheitsbestätigung hat zu lange gedauert. Bitte versuche es erneut.',
      );
    } on AccountDeletionException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(
        'Die Kontolöschung konnte nicht abgeschlossen werden. '
        'Bitte versuche es erneut.',
      );
      debugPrint('ACCOUNT DELETE UI FAILED: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _confirmPasswordAccount() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      throw const AccountSecurityException(
        'Bitte gib dein aktuelles Passwort ein.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase() ?? '';

    if (user == null || email.isEmpty) {
      throw const AccountSecurityException(
        'Für dieses Konto ist keine Anmelde-E-Mail-Adresse hinterlegt.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _confirmGoogleAccount() async {
    await GoogleAuthService.instance.reauthenticateCurrentUser(
      forceAccountSelection: true,
    );
  }

  Future<void> _cleanupDeletedAccountLocally(String userId) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      throw const AccountDeletionException(
        code: 'invalid-deleted-user',
        message: 'Das gelöschte Konto konnte lokal nicht eindeutig zugeordnet werden.',
      );
    }

    // Lokale Geräteinformationen werden nach der serverseitig bestätigten
    // Kontolöschung ausschließlich für diese UID entfernt.
    try {
      await _deviceCredentialService.deleteLocalCredential(cleanedUserId);
    } catch (error) {
      debugPrint(
        'ACCOUNT DELETE LOCAL DEVICE CREDENTIAL CLEANUP SKIPPED: $error',
      );
    }

    await _accountStorage.removeAccountByUserId(cleanedUserId);

    await _quickAccess.resetForUser(cleanedUserId);

    final sessionResult = await AuthSessionManager.instance.signOutForReason(
      expectedUserId: cleanedUserId,
      reason: 'account-deleted',
      signOutGoogleProvider: true,
      markLogoutLanding: true,
    );

    if (!sessionResult.isSuccess) {
      throw AccountDeletionException(
        code: sessionResult.code,
        message: sessionResult.message.isNotEmpty ? sessionResult.message : 'Das Konto wurde gelöscht, die lokale Sitzung konnte aber nicht vollständig beendet werden.',
      );
    }
  }

  String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Das aktuelle Passwort ist nicht korrekt.';
      case 'user-mismatch':
        return 'Das bestätigte Google-Konto gehört nicht zum aktuell angemeldeten Luma-Konto.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Die Sicherheitsbestätigung wurde abgebrochen.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte warte kurz und versuche es später erneut.';
      case 'network-request-failed':
        return 'Keine stabile Internetverbindung. Bitte prüfe deine Verbindung.';
      case 'requires-recent-login':
        return 'Bitte bestätige deine Anmeldung erneut und versuche es noch einmal.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Die Sicherheitsbestätigung ist fehlgeschlagen.';
    }
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isPasswordAccount = _security.isPasswordAccount;
    final isGoogleAccount = _security.isGoogleAccount;

    final isSupported = isPasswordAccount || isGoogleAccount;

    final confirmationMatches =
        _confirmationController.text.trim().toUpperCase() == _confirmationWord;

    return PopScope(
      canPop: !_isDeleting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Konto löschen'),
          automaticallyImplyLeading: !_isDeleting,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.onErrorContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dauerhafte Kontolöschung',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Diese Aktion kann nicht rückgängig gemacht werden.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Was entfernt wird',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const _DeletionPoint(
                icon: Icons.person_remove_outlined,
                text: 'Dein Luma-Konto und dein Profil',
              ),
              const _DeletionPoint(
                icon: Icons.photo_library_outlined,
                text:
                    'Deine eindeutig dem Konto zugeordneten Medien und Inhalte',
              ),
              const _DeletionPoint(
                icon: Icons.chat_bubble_outline_rounded,
                text: 'Deine Identität und Medien in bestehenden Messenger-Unterhaltungen',
              ),
              const SizedBox(height: 20),
              Text(
                'Sicherheitsbestätigung',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPasswordAccount
                    ? 'Bestätige zuerst dein aktuelles Passwort.'
                    : isGoogleAccount
                    ? 'Vor der Löschung musst du dein Google-Konto erneut bestätigen.'
                    : 'Diese Anmeldeart wird für die Kontolöschung derzeit noch nicht unterstützt.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isPasswordAccount) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isDeleting,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Aktuelles Passwort',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: _isDeleting
                          ? null
                          : () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: _confirmationController,
                enabled: !_isDeleting && isSupported,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Zur Bestätigung LÖSCHEN eingeben',
                  prefixIcon: Icon(Icons.delete_forever_outlined),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _isDeleting || !isSupported || !confirmationMatches
                    ? null
                    : _deleteAccount,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(
                  _isDeleting ? 'Konto wird gelöscht …' : 'Konto löschen',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Nach erfolgreicher Löschung wird dieses Konto auch aus dem '
                'gespeicherten Schnellzugriff auf diesem Gerät entfernt.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeletionPoint extends StatelessWidget {
  const _DeletionPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
