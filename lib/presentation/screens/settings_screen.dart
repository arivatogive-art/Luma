// Pfad: lib/presentation/screens/settings_screen.dart
//
// Finale Hauptstruktur von „Mein Luma“.
// Bestehende Firebase- und Auth-Logik bleibt erhalten.
// Die sichtbare Oberfläche ist nach Nutzeraufgaben geordnet.
// Historische, derzeit fehlende Unterseiten bleiben bis zur gezielten Wiederanbindung isoliert.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'appearance_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _openAccountSettings() async {
    _showPendingAreaMessage('Konto');
  }

  Future<void> _openPrivacySettings() async {
    _showPendingAreaMessage('Privatsphäre');
  }

  Future<void> _openNotificationSettings() async {
    _showPendingAreaMessage('Benachrichtigungen');
  }

  Future<void> _openSecuritySettings() async {
    _showPendingAreaMessage('Sicherheit');
  }

  Future<void> _openVisibilitySettings() async {
    _showPendingAreaMessage('Auffindbarkeit');
  }

  Future<void> _openBlockedUsersSettings() async {
    _showPendingAreaMessage('Blockieren & Einschränken');
  }

  Future<void> _openAppearanceSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AppearanceSettingsScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openLegalHelpSettings() async {
    _showPendingAreaMessage('Hilfe & Rechtliches');
  }

  Future<void> _openVerificationRequest() async {
    final userId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (userId.isEmpty) {
      _showAuthenticationMessage();
      return;
    }
    _showPendingAreaMessage('Verifikation');
  }

  Future<void> _openPagesHub() async {
    final userId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (userId.isEmpty) {
      _showAuthenticationMessage();
      return;
    }
    _showPendingAreaMessage('Creator Hub');
  }

  void _showPendingAreaMessage(String area) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$area wird in Luma Core 2.0 wieder angebunden.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAuthenticationMessage() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Bitte melde dich erneut an, um diesen Bereich zu öffnen.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SettingsAuthLoadingScreen();
        }

        if (authSnapshot.data == null) {
          return const _SettingsAuthenticationRequiredScreen();
        }

        return _buildAuthenticatedSettings(context);
      },
    );
  }

  Widget _buildAuthenticatedSettings(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? LumaTheme.darkBackground
        : const Color(0xFFF8F4EF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: const Text(
          'MEIN LUMA',
          style: TextStyle(
            color: LumaTheme.lumaOrange,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.35,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
              children: [
                const _SettingsIntro(),
                const SizedBox(height: 24),
                _SettingsGroup(
                  title: 'Mein Konto',
                  subtitle: 'Verwalte deine Daten, deinen Schutz und deine Privatsphäre.',
                  icon: Icons.manage_accounts_outlined,
                  children: [
                    _SettingsNavigationTile(
                      title: 'Konto',
                      subtitle:
                          'Persönliche Daten, Passwort und Kontoverwaltung.',
                      icon: Icons.person_outline_rounded,
                      onTap: _openAccountSettings,
                    ),
                    _SettingsNavigationTile(
                      title: 'Sicherheit',
                      subtitle:
                          'Schütze dein Konto und verwalte angemeldete Geräte.',
                      icon: Icons.security_rounded,
                      onTap: _openSecuritySettings,
                    ),
                    _SettingsNavigationTile(
                      title: 'Privatsphäre',
                      subtitle:
                          'Bestimme, wer dich und deine Inhalte sehen darf.',
                      icon: Icons.privacy_tip_outlined,
                      onTap: _openPrivacySettings,
                    ),
                    _SettingsNavigationTile(
                      title: 'Auffindbarkeit',
                      subtitle:
                          'Lege fest, wie andere dein Profil finden können.',
                      icon: Icons.search_rounded,
                      onTap: _openVisibilitySettings,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _SettingsGroup(
                  title: 'Community',
                  subtitle: 'Verwalte deinen öffentlichen Auftritt und persönliche Grenzen.',
                  icon: Icons.groups_2_outlined,
                  children: [
                    _SettingsNavigationTile(
                      title: 'Creator Hub',
                      subtitle:
                          'Verwalte Seiten und deinen öffentlichen Auftritt.',
                      icon: Icons.campaign_outlined,
                      onTap: _openPagesHub,
                    ),
                    _SettingsNavigationTile(
                      title: 'Verifikation',
                      subtitle: 'Bestätige deine Identität oder beantrage ein offizielles Profil.',
                      icon: Icons.verified_outlined,
                      onTap: _openVerificationRequest,
                    ),
                    _SettingsNavigationTile(
                      title: 'Blockieren & Einschränken',
                      subtitle: 'Verwalte blockierte, eingeschränkte und stummgeschaltete Personen.',
                      icon: Icons.block_rounded,
                      onTap: _openBlockedUsersSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _SettingsGroup(
                  title: 'Deine App',
                  subtitle: 'Passe Benachrichtigungen und Darstellung an deinen Alltag an.',
                  icon: Icons.tune_rounded,
                  children: [
                    _SettingsNavigationTile(
                      title: 'Benachrichtigungen',
                      subtitle:
                          'Lege fest, worüber Luma dich informieren darf.',
                      icon: Icons.notifications_none_rounded,
                      onTap: _openNotificationSettings,
                    ),
                    _SettingsNavigationTile(
                      title: 'Darstellung',
                      subtitle: 'Wähle zwischen System, Hell und Dunkel.',
                      icon: Icons.contrast_rounded,
                      onTap: _openAppearanceSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _SettingsGroup(
                  title: 'Hilfe',
                  subtitle: 'Support, Datenschutz und wichtige Informationen zu Luma.',
                  icon: Icons.help_outline_rounded,
                  children: [
                    _SettingsNavigationTile(
                      title: 'Hilfe & Rechtliches',
                      subtitle:
                          'Support, Datenschutz und wichtige Informationen.',
                      icon: Icons.info_outline_rounded,
                      onTap: _openLegalHelpSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _AccountExitHeader(),
                const SizedBox(height: 10),
                _SettingsNavigationTile(
                  title: 'Abmelden',
                  subtitle: 'Der bestehende Abmeldeablauf wird separat wieder angebunden.',
                  icon: Icons.logout_rounded,
                  onTap: () => _showPendingAreaMessage('Abmelden'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: LumaTheme.lumaOrange.withValues(
                alpha: isDark ? 0.13 : 0.15,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dashboard_customize_outlined,
              color: LumaTheme.lumaOrange,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alles an einem Ort.',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18.2,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Verwalte dein Konto, deine Privatsphäre und dein Erlebnis in Luma.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.9,
                    fontWeight: FontWeight.w500,
                    height: 1.38,
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: LumaTheme.lumaOrange.withValues(
                    alpha: isDark ? 0.11 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: LumaTheme.lumaOrange, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                        letterSpacing: -0.24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.9,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tileColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE8DCCE);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: LumaTheme.lumaOrange.withValues(alpha: 0.05),
          highlightColor: LumaTheme.lumaOrange.withValues(alpha: 0.025),
          child: Container(
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LumaTheme.lumaOrange.withValues(
                      alpha: isDark ? 0.11 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: LumaTheme.lumaOrange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14.8,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          letterSpacing: -0.08,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12.3,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textSecondary.withValues(alpha: 0.66),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountExitHeader extends StatelessWidget {
  const _AccountExitHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        'Konto verlassen',
        style: TextStyle(
          color: isDark ? LumaTheme.darkTextPrimary : const Color(0xFF102033),
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.18,
        ),
      ),
    );
  }
}

class _SettingsAuthLoadingScreen extends StatelessWidget {
  const _SettingsAuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? LumaTheme.darkBackground
          : const Color(0xFFF8F4EF),
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(LumaTheme.lumaOrange),
        ),
      ),
    );
  }
}

class _SettingsAuthenticationRequiredScreen extends StatelessWidget {
  const _SettingsAuthenticationRequiredScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? LumaTheme.darkBackground
        : const Color(0xFFF8F4EF);
    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : const Color(0xFFE8DCCE),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: LumaTheme.lumaOrange.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: LumaTheme.lumaOrange,
                        size: 27,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Anmeldung erforderlich',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Melde dich an, um deine persönlichen Einstellungen zu verwalten.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
