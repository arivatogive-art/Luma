// Pfad: lib/presentation/screens/settings_screen.dart
//
// Luma Core Rebuild 2.0
// Schlanker, eigenständiger Einstieg für „Mein Luma“.
// Historische Settings-Abhängigkeiten werden bewusst nicht reaktiviert.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting &&
            authSnapshot.data == null) {
          return const _SettingsAuthLoadingScreen();
        }

        if (authSnapshot.data == null) {
          return const _SettingsAuthenticationRequiredScreen();
        }

        return const _AuthenticatedSettingsScreen();
      },
    );
  }
}

class _AuthenticatedSettingsScreen extends StatelessWidget {
  const _AuthenticatedSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? LumaTheme.darkBackground : const Color(0xFFF8F4EF);

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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
          children: const [
            _SettingsIntro(),
            SizedBox(height: 24),
            _SettingsGroup(
              title: 'Mein Konto',
              subtitle:
                  'Verwalte deine Daten, deinen Schutz und deine Privatsphäre.',
              icon: Icons.manage_accounts_outlined,
              children: [
                _SettingsPlaceholderTile(
                  title: 'Konto',
                  subtitle:
                      'Persönliche Daten und Kontoverwaltung werden hier wieder angebunden.',
                  icon: Icons.person_outline_rounded,
                ),
                _SettingsPlaceholderTile(
                  title: 'Sicherheit',
                  subtitle:
                      'Kontoschutz und angemeldete Geräte werden hier wieder angebunden.',
                  icon: Icons.security_rounded,
                ),
                _SettingsPlaceholderTile(
                  title: 'Privatsphäre',
                  subtitle:
                      'Deine Privatsphäre-Einstellungen werden hier wieder angebunden.',
                  icon: Icons.privacy_tip_outlined,
                ),
                _SettingsPlaceholderTile(
                  title: 'Auffindbarkeit',
                  subtitle:
                      'Einstellungen zur Auffindbarkeit werden hier wieder angebunden.',
                  icon: Icons.search_rounded,
                ),
              ],
            ),
            SizedBox(height: 24),
            _SettingsGroup(
              title: 'Community',
              subtitle:
                  'Verwalte deinen öffentlichen Auftritt und persönliche Grenzen.',
              icon: Icons.groups_2_outlined,
              children: [
                _SettingsPlaceholderTile(
                  title: 'Creator Hub',
                  subtitle:
                      'Seiten und öffentliche Auftritte werden später wieder angebunden.',
                  icon: Icons.campaign_outlined,
                ),
                _SettingsPlaceholderTile(
                  title: 'Verifikation',
                  subtitle:
                      'Die Verifikation wird später wieder an den bestehenden Backend-Bereich angebunden.',
                  icon: Icons.verified_outlined,
                ),
                _SettingsPlaceholderTile(
                  title: 'Blockieren & Einschränken',
                  subtitle:
                      'Blockierte und eingeschränkte Personen werden hier wieder angebunden.',
                  icon: Icons.block_rounded,
                ),
              ],
            ),
            SizedBox(height: 24),
            _SettingsGroup(
              title: 'Deine App',
              subtitle:
                  'Passe Benachrichtigungen und Darstellung an deinen Alltag an.',
              icon: Icons.tune_rounded,
              children: [
                _SettingsPlaceholderTile(
                  title: 'Benachrichtigungen',
                  subtitle:
                      'Deine Benachrichtigungseinstellungen werden hier wieder angebunden.',
                  icon: Icons.notifications_none_rounded,
                ),
                _SettingsPlaceholderTile(
                  title: 'Darstellung',
                  subtitle:
                      'System, Hell und Dunkel werden hier wieder angebunden.',
                  icon: Icons.contrast_rounded,
                ),
              ],
            ),
            SizedBox(height: 24),
            _SettingsGroup(
              title: 'Hilfe',
              subtitle:
                  'Support, Datenschutz und wichtige Informationen zu Luma.',
              icon: Icons.help_outline_rounded,
              children: [
                _SettingsPlaceholderTile(
                  title: 'Hilfe & Rechtliches',
                  subtitle:
                      'Support und rechtliche Informationen werden hier wieder angebunden.',
                  icon: Icons.info_outline_rounded,
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

    final cardColor =
        isDark ? LumaTheme.darkSurfaceSoft : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);
    final textPrimary =
        isDark ? LumaTheme.darkTextPrimary : const Color(0xFF102033);
    final textSecondary =
        isDark ? LumaTheme.darkTextSecondary : const Color(0xFF756D65);

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

    final textPrimary =
        isDark ? LumaTheme.darkTextPrimary : const Color(0xFF102033);
    final textSecondary =
        isDark ? LumaTheme.darkTextSecondary : const Color(0xFF756D65);

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
                child: Icon(
                  icon,
                  color: LumaTheme.lumaOrange,
                  size: 18,
                ),
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

class _SettingsPlaceholderTile extends StatelessWidget {
  const _SettingsPlaceholderTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tileColor =
        isDark ? LumaTheme.darkSurfaceSoft : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE8DCCE);
    final textPrimary =
        isDark ? LumaTheme.darkTextPrimary : const Color(0xFF102033);
    final textSecondary =
        isDark ? LumaTheme.darkTextSecondary : const Color(0xFF756D65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: tileColor,
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
              child: Icon(
                icon,
                color: LumaTheme.lumaOrange,
                size: 20,
              ),
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
              Icons.schedule_rounded,
              color: textSecondary.withValues(alpha: 0.58),
              size: 20,
            ),
          ],
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
      backgroundColor:
          isDark ? LumaTheme.darkBackground : const Color(0xFFF8F4EF),
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            LumaTheme.lumaOrange,
          ),
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

    final backgroundColor =
        isDark ? LumaTheme.darkBackground : const Color(0xFFF8F4EF);
    final cardColor =
        isDark ? LumaTheme.darkSurfaceSoft : const Color(0xFFFFFCF8);
    final textPrimary =
        isDark ? LumaTheme.darkTextPrimary : const Color(0xFF102033);
    final textSecondary =
        isDark ? LumaTheme.darkTextSecondary : const Color(0xFF756D65);

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
                      'Deine Sitzung ist nicht mehr aktiv. Öffne Luma erneut über den vorhandenen Anmeldeablauf.',
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
