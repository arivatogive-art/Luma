import 'package:flutter/material.dart';

class ProfileOptionsSheet extends StatelessWidget {
  const ProfileOptionsSheet({
    super.key,
    required this.onClose,
    this.isOwnProfile = false,
    this.profileDisplayName = '',
    this.profileUsername = '',
    this.isBlocked = false,
    this.onReportProfile,
    this.onBlockProfile,
    this.onUnblockProfile,
    this.onHideProfile,
    this.onOpenPrivacyInfo,
  });

  final VoidCallback onClose;
  final bool isOwnProfile;
  final String profileDisplayName;
  final String profileUsername;
  final bool isBlocked;
  final VoidCallback? onReportProfile;
  final VoidCallback? onBlockProfile;
  final VoidCallback? onUnblockProfile;
  final VoidCallback? onHideProfile;
  final VoidCallback? onOpenPrivacyInfo;

  String get _safeDisplayName {
    final cleanName = profileDisplayName.trim();

    if (cleanName.isNotEmpty) {
      return cleanName;
    }

    final cleanUsername = profileUsername.trim();

    if (cleanUsername.isNotEmpty) {
      return cleanUsername.startsWith('@') ? cleanUsername : '@$cleanUsername';
    }

    return isOwnProfile ? 'Dein Profil' : 'Dieses Profil';
  }

  String get _safeUsername {
    final cleanUsername = profileUsername.trim();

    if (cleanUsername.isEmpty) {
      return '';
    }

    return cleanUsername.startsWith('@') ? cleanUsername : '@$cleanUsername';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: availableHeight * 0.88,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isOwnProfile
                        ? colorScheme.primary.withValues(
                            alpha: isDark ? 0.16 : 0.10,
                          )
                        : colorScheme.onSurface.withValues(
                            alpha: isDark ? 0.10 : 0.055,
                          ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOwnProfile
                          ? colorScheme.primary.withValues(
                              alpha: isDark ? 0.18 : 0.12,
                            )
                          : colorScheme.outline.withValues(
                              alpha: isDark ? 0.12 : 0.08,
                            ),
                    ),
                  ),
                  child: Icon(
                    isOwnProfile
                        ? Icons.manage_accounts_outlined
                        : Icons.shield_outlined,
                    color: isOwnProfile
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.68),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOwnProfile ? 'Profiloptionen' : _safeDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.94),
                          fontSize: 17,
                          height: 1.10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.22,
                        ),
                      ),
                      if (_safeUsername.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _safeUsername,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.48),
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.03,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 3),
                        Text(
                          isOwnProfile
                              ? 'Verwalte dein privates Profil.'
                              : 'Sicherheits- und Sichtbarkeitsoptionen.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.48),
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isOwnProfile) ...[
              _ProfileOptionsInfoCard(
                icon: Icons.lock_outline_rounded,
                title: 'Privates Profil schützen',
                message:
                    'Profilangaben, Freunde und Momente werden über Sichtbarkeit und Freundschaftsstatus gesteuert.',
              ),
              const SizedBox(height: 10),
              _ProfileOptionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Sichtbarkeit verstehen',
                subtitle: 'Was andere auf deinem Profil sehen können.',
                onTap: onOpenPrivacyInfo,
              ),
            ] else ...[
              _ProfileOptionTile(
                icon: Icons.visibility_off_outlined,
                title: 'Profil ausblenden',
                subtitle: 'Entfernt dieses Profil aus deiner aktuellen Ansicht.',
                onTap: onHideProfile,
              ),
              const SizedBox(height: 8),
              _ProfileOptionTile(
                icon: Icons.flag_outlined,
                title: 'Profil melden',
                subtitle: 'Melde Missbrauch, Fake-Profile, Spam oder Belästigung.',
                onTap: onReportProfile,
              ),
              const SizedBox(height: 8),
              _ProfileOptionTile(
                icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                title: isBlocked ? 'Blockierung aufheben' : 'Profil blockieren',
                subtitle: isBlocked
                    ? 'Erlaubt diesem Profil wieder, dich zu finden und anzufragen.'
                    : 'Verhindert weitere direkte Interaktion mit diesem Profil.',
                destructive: !isBlocked,
                onTap: isBlocked ? onUnblockProfile : onBlockProfile,
              ),
              const SizedBox(height: 10),
              _ProfileOptionsInfoCard(
                icon: Icons.verified_user_outlined,
                title: 'Sicherheit zuerst',
                message:
                    'Melden und Blockieren sind bewusst getrennt: Melden prüft Inhalte, Blockieren schützt deine eigene Nutzung.',
              ),
            ],
            const SizedBox(height: 12),
            _ProfileCloseButton(
              onTap: onClose,
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOptionTile extends StatefulWidget {
  const _ProfileOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  State<_ProfileOptionTile> createState() => _ProfileOptionTileState();
}

class _ProfileOptionTileState extends State<_ProfileOptionTile> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;

    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final enabled = widget.onTap != null;
    final foregroundColor = widget.destructive
        ? colorScheme.error
        : colorScheme.onSurface.withValues(alpha: 0.84);

    return AnimatedScale(
      scale: _isPressed ? 0.992 : 1,
      duration: const Duration(milliseconds: 105),
      curve: Curves.easeOutCubic,
      child: Material(
        color: widget.destructive
            ? colorScheme.error.withValues(alpha: isDark ? 0.070 : 0.045)
            : colorScheme.surface.withValues(alpha: isDark ? 0.34 : 0.74),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? widget.onTap : null,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: foregroundColor.withValues(alpha: 0.055),
          highlightColor: foregroundColor.withValues(alpha: 0.025),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.destructive
                    ? colorScheme.error.withValues(alpha: isDark ? 0.16 : 0.13)
                    : colorScheme.outline.withValues(
                        alpha: isDark ? 0.10 : 0.070,
                      ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: foregroundColor.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: foregroundColor.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: foregroundColor.withValues(alpha: enabled ? 0.86 : 0.38),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foregroundColor.withValues(alpha: enabled ? 1 : 0.44),
                          fontSize: 13.7,
                          height: 1.16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.04,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(
                            alpha: enabled ? 0.48 : 0.30,
                          ),
                          fontSize: 11.7,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.02,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: foregroundColor.withValues(alpha: enabled ? 0.38 : 0.18),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileOptionsInfoCard extends StatelessWidget {
  const _ProfileOptionsInfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isDark ? 0.080 : 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.11 : 0.080),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: colorScheme.primary.withValues(alpha: 0.82),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.86),
                    fontSize: 12.9,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 11.7,
                    height: 1.34,
                    fontWeight: FontWeight.w500,
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

class _ProfileCloseButton extends StatelessWidget {
  const _ProfileCloseButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.040)
          : Colors.white.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: colorScheme.onSurface.withValues(alpha: 0.045),
        highlightColor: colorScheme.onSurface.withValues(alpha: 0.020),
        child: Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.045)
                  : const Color(0xFFE9DDD0).withValues(alpha: 0.42),
            ),
          ),
          child: Center(
            child: Text(
              'Schließen',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.76),
                fontSize: 13.3,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.04,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
