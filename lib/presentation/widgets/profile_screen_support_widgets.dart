// Pfad: lib/presentation/widgets/profile_screen_support_widgets.dart

import 'package:flutter/material.dart';

import '../../domain/models/private_profile_model.dart';

class ProfileBackToFeedButton extends StatelessWidget {
  const ProfileBackToFeedButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.72)
            : const Color(0xFFFFFCF8).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(999),
          splashColor: colorScheme.primary.withValues(alpha: 0.07),
          highlightColor: colorScheme.primary.withValues(alpha: 0.035),
          child: Container(
            padding: const EdgeInsets.fromLTRB(9, 7, 13, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.075)
                    : const Color(0xFFEFE2D6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: colorScheme.onSurface.withValues(alpha: 0.78),
                ),
                const SizedBox(width: 7),
                Text(
                  'Zurück',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.78),
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.03,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileFlowSection extends StatelessWidget {
  final int order;
  final double topSpacing;
  final Widget child;

  const ProfileFlowSection({
    required this.order,
    required this.topSpacing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final animationDelay = order * 18 > 54 ? 54 : order * 18;

    return Padding(
      padding: EdgeInsets.only(top: topSpacing),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 170 + animationDelay),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 5 * (1 - value)),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

class ProfileInlineMomentErrorCard extends StatelessWidget {
  final String message;

  const ProfileInlineMomentErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.error.withValues(alpha: 0.035)
            : colorScheme.errorContainer.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: isDark ? 0.14 : 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: isDark ? 0.10 : 0.08),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              Icons.cloud_off_outlined,
              color: colorScheme.error.withValues(alpha: isDark ? 0.74 : 0.68),
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Momente konnten nicht aktualisiert werden',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.03,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  cleanMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.60),
                    fontSize: 12.2,
                    height: 1.36,
                    fontWeight: FontWeight.w600,
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

class ProfileMutualFriendsStrip extends StatelessWidget {
  const ProfileMutualFriendsStrip({
    required this.mutualFriends,
    required this.onTap,
    required this.onOpenFriendProfile,
  });

  final List<PrivateProfileModel> mutualFriends;
  final VoidCallback onTap;
  final void Function(PrivateProfileModel friend) onOpenFriendProfile;

  String get _title {
    if (mutualFriends.length == 1) {
      return '1 gemeinsamer Freund';
    }

    return '${mutualFriends.length} gemeinsame Freunde';
  }

  String get _subtitle {
    final names = mutualFriends
        .map((friend) => friend.displayName.trim())
        .where((name) => name.isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (names.isEmpty) {
      return 'Ihr habt gemeinsame Kontakte auf Luma.';
    }

    if (mutualFriends.length == 1) {
      return names.first;
    }

    if (mutualFriends.length == 2 && names.length == 2) {
      return '${names.first} und ${names.last}';
    }

    final remainingCount = mutualFriends.length - names.length;

    if (remainingCount <= 0) {
      return names.join(', ');
    }

    return '${names.join(', ')} und $remainingCount weitere';
  }

  @override
  Widget build(BuildContext context) {
    if (mutualFriends.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final previewFriends = mutualFriends.take(3).toList(growable: false);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: colorScheme.primary.withValues(alpha: 0.06),
        highlightColor: colorScheme.primary.withValues(alpha: 0.025),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.42)
                : const Color(0xFFFFFCF8).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withValues(alpha: 0.10)
                  : const Color(0xFFEADFD2),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                height: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = 0; index < previewFriends.length; index++)
                      Positioned(
                        left: index * 16,
                        child: ProfileMutualFriendAvatar(
                          friend: previewFriends[index],
                          onTap: () => onOpenFriendProfile(previewFriends[index]),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.82),
                        fontSize: 13.2,
                        height: 1.14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.04,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 12.0,
                        height: 1.18,
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
                color: colorScheme.onSurface.withValues(alpha: 0.34),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMutualFriendAvatar extends StatelessWidget {
  const ProfileMutualFriendAvatar({
    required this.friend,
    required this.onTap,
  });

  final PrivateProfileModel friend;
  final VoidCallback onTap;

  String get _initials {
    final cleanedName = friend.displayName.trim();

    if (cleanedName.isEmpty) return 'L';

    final parts = cleanedName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'L';

    if (parts.length == 1) {
      final first = parts.first;
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = friend.profileImageUrl.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.surface,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallback(context);
                },
              )
            : _buildFallback(context),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.primary.withValues(alpha: 0.10),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 10.8,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.08,
          ),
        ),
      ),
    );
  }
}

class ProfilePrimaryNavigation extends StatelessWidget {
  final int momentsCount;
  final int photosCount;
  final VoidCallback onPostsTap;
  final VoidCallback onInfoTap;
  final VoidCallback onPhotosTap;

  const ProfilePrimaryNavigation({
    required this.momentsCount,
    required this.photosCount,
    required this.onPostsTap,
    required this.onInfoTap,
    required this.onPhotosTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.30)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.045)
              : const Color(0xFFEAE1D8).withValues(alpha: 0.46),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.040 : 0.012),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.012 : 0.64),
            blurRadius: 0,
            offset: const Offset(0, 1),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ProfilePrimaryNavigationItem(
              icon: Icons.article_outlined,
              label: 'Beiträge',
              value: momentsCount,
              highlighted: true,
              onTap: onPostsTap,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: ProfilePrimaryNavigationItem(
              icon: Icons.info_outline_rounded,
              label: 'Info',
              onTap: onInfoTap,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: ProfilePrimaryNavigationItem(
              icon: Icons.photo_library_outlined,
              label: 'Fotos',
              value: photosCount,
              onTap: onPhotosTap,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePrimaryNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool highlighted;
  final VoidCallback onTap;

  const ProfilePrimaryNavigationItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final foregroundColor = highlighted
        ? colorScheme.onSurface.withValues(alpha: 0.82)
        : colorScheme.onSurface.withValues(alpha: 0.52);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        splashColor: colorScheme.onSurface.withValues(alpha: 0.030),
        highlightColor: colorScheme.onSurface.withValues(alpha: 0.016),
        child: Container(
          height: 48,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: highlighted ? 0.050 : 0.018)
                : Colors.white.withValues(alpha: highlighted ? 0.98 : 0.70),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: highlighted ? 0.070 : 0.030)
                  : highlighted
                      ? const Color(0xFFE6DDD3).withValues(alpha: 0.62)
                      : const Color(0xFFEFE7DE).withValues(alpha: 0.32),
            ),
            boxShadow: [
              if (!isDark && highlighted)
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.026),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              if (!isDark && highlighted)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.72),
                  blurRadius: 0,
                  offset: const Offset(0, 1),
                  spreadRadius: -1,
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15.5,
                color: foregroundColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontSize: 12.5,
                    height: 1,
                    fontWeight: highlighted ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: -0.08,
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: highlighted ? 0.060 : 0.040)
                        : const Color(0xFFF4F1ED).withValues(alpha: highlighted ? 0.88 : 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: highlighted ? 0.075 : 0.045)
                          : const Color(0xFFE4DBD2).withValues(alpha: highlighted ? 0.64 : 0.42),
                    ),
                  ),
                  child: Text(
                    '$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(
                        alpha: highlighted ? 0.58 : 0.40,
                      ),
                      fontSize: 10.4,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.02,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMomentSheetStateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final String title;
  final String message;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const ProfileMomentSheetStateCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.title,
    required this.message,
    this.trailing,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.035),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.095),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              icon,
              color: iconColor.withValues(alpha: 0.88),
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 14.4,
                    fontWeight: FontWeight.w800,
                    height: 1.24,
                    letterSpacing: -0.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.60),
                    fontSize: 13,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (actionLabel != null && onActionTap != null) ...[
                  const SizedBox(height: 9),
                  ProfileMomentStateActionButton(
                    label: actionLabel!,
                    onTap: onActionTap!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileMomentStateActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const ProfileMomentStateActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                color: colorScheme.primary.withValues(alpha: 0.88),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.02,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class BlockedProfileActionCard extends StatelessWidget {
  const BlockedProfileActionCard({
    required this.blockedByMe,
    required this.isUpdating,
    required this.onUnblock,
    required this.onOpenOptions,
  });

  final bool blockedByMe;
  final bool isUpdating;
  final VoidCallback onUnblock;
  final VoidCallback onOpenOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.36)
            : const Color(0xFFFFFCF8).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: blockedByMe
              ? colorScheme.error.withValues(alpha: isDark ? 0.22 : 0.16)
              : colorScheme.outline.withValues(alpha: isDark ? 0.11 : 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.055 : 0.018),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: blockedByMe
                      ? colorScheme.error.withValues(alpha: isDark ? 0.14 : 0.09)
                      : colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.block_rounded,
                  color: blockedByMe
                      ? colorScheme.error
                      : colorScheme.onSurface.withValues(alpha: 0.58),
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blockedByMe ? 'Profil blockiert' : 'Interaktion eingeschränkt',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.88),
                        fontSize: 13.4,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      blockedByMe
                          ? 'Du hast dieses Profil blockiert. Freundschaft, Nachrichten und direkte Interaktionen sind deaktiviert.'
                          : 'Zwischen euch besteht eine Blockierung. Direkte Interaktionen sind deaktiviert.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 11.7,
                        fontWeight: FontWeight.w600,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (blockedByMe) ...[
                Expanded(
                  child: FilledButton(
                    onPressed: isUpdating ? null : onUnblock,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(isUpdating ? 'Bitte warten ...' : 'Blockierung aufheben'),
                  ),
                ),
                const SizedBox(width: 9),
              ],
              SizedBox(
                width: 48,
                height: 44,
                child: OutlinedButton(
                  onPressed: onOpenOptions,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
