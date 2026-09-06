// Pfad: lib/presentation/screens/change_password_screen.dart

import 'package:flutter/material.dart';

import '../../application/account_security_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final AccountSecurityService _security = AccountSecurityService();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _repeatController = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showRepeat = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final newPassword = _newController.text;
    final repeatedPassword = _repeatController.text;

    if (newPassword != repeatedPassword) {
      _showMessage('Die neuen Passwörter stimmen nicht überein.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await _security.changePassword(
        currentPassword: _currentController.text,
        newPassword: newPassword,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Passwort geändert'),
          content: const Text(
            'Dein neues Passwort ist jetzt aktiv. '
            'Deine aktuelle Luma-Sitzung bleibt bestehen.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Verstanden'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AccountSecurityException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Das Passwort konnte momentan nicht geändert werden.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPasswordAccount = _security.isPasswordAccount;

    return Scaffold(
      appBar: AppBar(title: const Text('Passwort ändern')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'Kontopasswort',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bestätige zuerst dein aktuelles Passwort. Danach kannst du ein neues festlegen.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (!isPasswordAccount)
              _PasswordProviderNotice(
                isGoogleAccount: _security.isGoogleAccount,
                isPhoneAccount: _security.isPhoneAccount,
              )
            else ...[
              _PasswordField(
                controller: _currentController,
                label: 'Aktuelles Passwort',
                visible: _showCurrent,
                enabled: !_saving,
                onVisibilityChanged: () {
                  setState(() => _showCurrent = !_showCurrent);
                },
              ),
              const SizedBox(height: 16),
              _PasswordField(
                controller: _newController,
                label: 'Neues Passwort',
                visible: _showNew,
                enabled: !_saving,
                onVisibilityChanged: () {
                  setState(() => _showNew = !_showNew);
                },
              ),
              const SizedBox(height: 16),
              _PasswordField(
                controller: _repeatController,
                label: 'Neues Passwort wiederholen',
                visible: _showRepeat,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onVisibilityChanged: () {
                  setState(() => _showRepeat = !_showRepeat);
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Das neue Passwort muss mindestens 8 Zeichen lang sein.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
                    : const Icon(Icons.lock_reset_rounded),
                label: Text(
                  _saving ? 'Wird geändert …' : 'Passwort ändern',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.enabled,
    required this.onVisibilityChanged,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final bool enabled;
  final VoidCallback onVisibilityChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: !visible,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.password],
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: visible ? 'Passwort ausblenden' : 'Passwort anzeigen',
          onPressed: enabled ? onVisibilityChanged : null,
          icon: Icon(
            visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}

class _PasswordProviderNotice extends StatelessWidget {
  const _PasswordProviderNotice({
    required this.isGoogleAccount,
    required this.isPhoneAccount,
  });

  final bool isGoogleAccount;
  final bool isPhoneAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = isGoogleAccount
        ? 'Mit Google angemeldet'
        : isPhoneAccount
            ? 'Mit Telefonnummer angemeldet'
            : 'Passwort nicht verfügbar';

    final message = isGoogleAccount
        ? 'Dieses Luma-Konto verwendet Google zur Anmeldung. '
            'Ein separates Luma-Passwort kann hier deshalb nicht geändert werden.'
        : isPhoneAccount
            ? 'Dieses Konto verwendet die Telefonnummer zur Anmeldung. '
                'Für diesen Kontotyp wird hier kein Passwort verwaltet.'
            : 'Für den aktuellen Anmeldeanbieter ist die Passwortänderung derzeit nicht verfügbar.';

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
          const Icon(Icons.info_outline_rounded, size: 26),
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
