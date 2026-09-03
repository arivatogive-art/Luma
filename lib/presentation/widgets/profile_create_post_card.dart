// Pfad: lib/presentation/widgets/profile_create_post_card.dart

import 'package:flutter/material.dart';

class ProfileCreatePostCard extends StatelessWidget {
  final String displayName;
  final String profileImageUrl;
  final VoidCallback onCreatePost;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddMood;
  final VoidCallback onTagFriends;
  final VoidCallback onChangeVisibility;

  const ProfileCreatePostCard({
    super.key,
    required this.displayName,
    required this.profileImageUrl,
    required this.onCreatePost,
    required this.onAddPhoto,
    required this.onAddMood,
    required this.onTagFriends,
    required this.onChangeVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cleanImageUrl = profileImageUrl.trim();
    final cleanDisplayName = displayName.trim();
    final firstLetter = cleanDisplayName.isEmpty
        ? 'L'
        : cleanDisplayName.characters.first.toUpperCase();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.72)
            : const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.12)
              : const Color(0xFFE8DDD1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.10 : 0.026),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProfileCreatePostAvatar(
                  imageUrl: cleanImageUrl,
                  fallbackLetter: firstLetter,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileCreatePostInputPill(
                    displayName: cleanDisplayName,
                    onTap: onCreatePost,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: isDark
                  ? colorScheme.outline.withValues(alpha: 0.10)
                  : const Color(0xFFEDE1D5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ProfileCreatePostAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Foto',
                    onTap: onAddPhoto,
                    emphasis: _ProfileCreatePostActionEmphasis.green,
                  ),
                ),
                Expanded(
                  child: _ProfileCreatePostAction(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Gefühl',
                    onTap: onAddMood,
                    emphasis: _ProfileCreatePostActionEmphasis.orange,
                  ),
                ),
                Expanded(
                  child: _ProfileCreatePostAction(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Freunde',
                    onTap: onTagFriends,
                    emphasis: _ProfileCreatePostActionEmphasis.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ProfileCreatePostVisibilityRow(
              onTap: onChangeVisibility,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCreatePostInputPill extends StatelessWidget {
  final String displayName;
  final VoidCallback onTap;

  const _ProfileCreatePostInputPill({
    required this.displayName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cleanDisplayName = displayName.trim();
    final prompt = cleanDisplayName.isEmpty
        ? 'Was möchtest du teilen?'
        : 'Was möchtest du teilen, $cleanDisplayName?';

    return Material(
      color: isDark
          ? colorScheme.surface.withValues(alpha: 0.44)
          : const Color(0xFFF7F0E8),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 42,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withValues(alpha: 0.10)
                  : const Color(0xFFE2D5C7),
            ),
          ),
          child: Text(
            prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.64),
              fontWeight: FontWeight.w700,
              fontSize: 14.2,
              height: 1,
              letterSpacing: -0.04,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCreatePostAvatar extends StatelessWidget {
  final String imageUrl;
  final String fallbackLetter;

  const _ProfileCreatePostAvatar({
    required this.imageUrl,
    required this.fallbackLetter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? Center(
              child: Text(
                fallbackLetter,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Center(
                  child: Text(
                    fallbackLetter,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

enum _ProfileCreatePostActionEmphasis {
  green,
  orange,
  blue,
}

class _ProfileCreatePostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _ProfileCreatePostActionEmphasis emphasis;

  const _ProfileCreatePostAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.emphasis,
  });

  Color _resolveIconColor(ColorScheme colorScheme, bool isDark) {
    switch (emphasis) {
      case _ProfileCreatePostActionEmphasis.green:
        return isDark ? const Color(0xFF7AD99B) : const Color(0xFF2E8C57);
      case _ProfileCreatePostActionEmphasis.orange:
        return colorScheme.primary;
      case _ProfileCreatePostActionEmphasis.blue:
        return isDark ? const Color(0xFF8FB9FF) : const Color(0xFF3D6FA8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = _resolveIconColor(colorScheme, isDark);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.8,
                    height: 1,
                    letterSpacing: -0.02,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCreatePostVisibilityRow extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileCreatePostVisibilityRow({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? colorScheme.surface.withValues(alpha: 0.28)
          : const Color(0xFFF9F3EC),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withValues(alpha: 0.10)
                  : const Color(0xFFE8DDD1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.10),
                ),
                child: Icon(
                  Icons.public_rounded,
                  color: colorScheme.primary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sichtbarkeit vor dem Veröffentlichen prüfen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -0.02,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.38),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
