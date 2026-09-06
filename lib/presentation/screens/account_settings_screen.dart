// Pfad: lib/presentation/screens/account_settings_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/domain/profile_model.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileRepository _profiles = ProfileRepository();
  ProfileModel? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Dein Konto konnte nicht geladen werden.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await user.reload();
      final profile = await _profiles.fetchProfile(uid: user.uid);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _error = profile == null
            ? 'Deine Profilinformationen konnten nicht geladen werden.'
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Deine Kontoinformationen konnten nicht geladen werden.';
        });
      }
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditScreen(profile: profile),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _changeEmail() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ChangeEmailScreen()),
    );

    if (changed == true) {
      await _load();
    }
  }

  Future<void> _changePassword() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _deleteAccount() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    final emailText = email == null || email.isEmpty
        ? 'Keine E-Mail-Adresse hinterlegt'
        : email;

    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_off_outlined, size: 42),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: [
                    Text(
                      'Dein Konto',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hier findest du deine wichtigsten Konto- und Anmeldeinformationen.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ProfileCard(profile: _profile!, onEdit: _editProfile),
                    const SizedBox(height: 24),
                    const _SectionTitle('Anmeldeinformationen'),
                    const SizedBox(height: 10),
                    _Card(
                      children: [
                        _InfoRow(
                          Icons.email_outlined,
                          'E-Mail-Adresse',
                          emailText,
                        ),
                        const Divider(height: 1),
                        _InfoRow(
                          user?.emailVerified == true
                              ? Icons.verified_outlined
                              : Icons.info_outline_rounded,
                          'E-Mail-Status',
                          user?.emailVerified == true
                              ? 'Bestätigt'
                              : 'Nicht bestätigt',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle('Kontosicherheit'),
                    const SizedBox(height: 10),
                    _Card(
                      children: [
                        _ActionRow(
                          Icons.alternate_email_rounded,
                          'E-Mail-Adresse ändern',
                          'Ändere die Adresse, mit der du dich bei Luma anmeldest.',
                          _changeEmail,
                        ),
                        const Divider(height: 1),
                        _ActionRow(
                          Icons.password_rounded,
                          'Passwort ändern',
                          'Verwalte das Passwort für dein Luma-Konto.',
                          _changePassword,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle('Konto verwalten'),
                    const SizedBox(height: 10),
                    _Card(
                      children: [
                        _ActionRow(
                          Icons.delete_outline_rounded,
                          'Konto löschen',
                          'Lösche dein Luma-Konto und die dazugehörigen Kontodaten dauerhaft.',
                          _deleteAccount,
                          destructive: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit});
  final ProfileModel profile;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = profile.profileImageUrl.trim();
    final name = profile.displayName.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
            child: image.isEmpty
                ? Text(
                    name.isEmpty ? 'L' : name[0].toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (profile.username.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '@${profile.username.trim()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Profil bearbeiten'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.title, this.value);
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 23),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _ActionRow extends StatelessWidget {
  const _ActionRow(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 23, color: foreground),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
