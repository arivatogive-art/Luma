// Pfad: lib/presentation/screens/change_email_screen.dart

import 'package:flutter/material.dart';

import '../../application/account_security_service.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final AccountSecurityService _security = AccountSecurityService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      await _security.requestEmailChange(
        currentPassword: _passwordController.text,
        newEmail: _emailController.text,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('E-Mail bestätigen'),
            content: Text(
              'Wir haben eine Bestätigung an '
              '${_emailController.text.trim().toLowerCase()} gesendet. '
              'Deine bisherige E-Mail-Adresse bleibt aktiv, bis du die neue Adresse bestätigt hast.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Verstanden'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AccountSecurityException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Die E-Mail-Änderung konnte momentan nicht gestartet werden.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _security.currentUser;
    final currentEmail = user?.email?.trim() ?? '';
    final isPasswordAccount = _security.isPasswordAccount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Mail-Adresse ändern'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'Anmelde-E-Mail',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aktuell: ${currentEmail.isEmpty ? 'Keine E-Mail hinterlegt' : currentEmail}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (!isPasswordAccount)
              _ProviderNotice(
                isGoogleAccount: _security.isGoogleAccount,
                isPhoneAccount: _security.isPhoneAccount,
              )
            else ...[
              TextField(
                controller: _emailController,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Neue E-Mail-Adresse',
                  hintText: 'name@beispiel.de',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !_saving,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Aktuelles Passwort',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Passwort anzeigen'
                        : 'Passwort ausblenden',
                    onPressed: _saving
                        ? null
                        : () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Aus Sicherheitsgründen bestätigst du die Änderung zuerst mit deinem aktuellen Passwort. '
                'Danach sendet Firebase einen Bestätigungslink an die neue Adresse.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mark_email_read_outlined),
                label: Text(
                  _saving
                      ? 'Wird vorbereitet …'
                      : 'Bestätigung senden',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderNotice extends StatelessWidget {
  const _ProviderNotice({
    required this.isGoogleAccount,
    required this.isPhoneAccount,
  });

  final bool isGoogleAccount;
  final bool isPhoneAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String title;
    String message;
    IconData icon;

    if (isGoogleAccount) {
      title = 'Mit Google angemeldet';
      message =
          'Dieses Luma-Konto verwendet Google zur Anmeldung. '
          'Die Anmelde-E-Mail wird über dein Google-Konto verwaltet und kann hier nicht separat geändert werden.';
      icon = Icons.account_circle_outlined;
    } else if (isPhoneAccount) {
      title = 'Mit Telefonnummer angemeldet';
      message =
          'Dieses Konto verwendet die Telefonnummer zur Anmeldung. '
          'Eine Änderung der Anmelde-E-Mail wird für diesen Kontotyp noch nicht angeboten.';
      icon = Icons.phone_android_rounded;
    } else {
      title = 'Änderung nicht verfügbar';
      message =
          'Für den aktuellen Anmeldeanbieter ist die E-Mail-Änderung derzeit nicht verfügbar.';
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
