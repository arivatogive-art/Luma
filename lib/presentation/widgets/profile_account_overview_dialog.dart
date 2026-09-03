// Pfad: lib/presentation/widgets/profile_account_overview_dialog.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/pages/application/page_controller.dart' as luma_pages;
import '../../features/pages/domain/models/page_model.dart';
import '../../domain/models/private_profile_model.dart';
import 'profile_sheet_action_button.dart';

class ProfileAccountOverviewDialog extends StatelessWidget {
  final PrivateProfileModel profile;
  final luma_pages.PageController pageController;
  final String currentAuthUserId;
  final Future<void> Function(LumaPageModel page) onOpenOwnedPage;
  final Future<void> Function() onOpenCreatorHub;

  const ProfileAccountOverviewDialog({
    super.key,
    required this.profile,
    required this.pageController,
    required this.currentAuthUserId,
    required this.onOpenOwnedPage,
    required this.onOpenCreatorHub,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 26,
      ),
      child: AnimatedBuilder(
        animation: pageController,
        builder: (context, _) {
          final ownedPages = pageController.state.pages
              .where((page) => page.isOwnedBy(currentAuthUserId))
              .toList(growable: false);

          return ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 540,
              maxHeight: 580,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.040),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.035),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kontenübersicht',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Wechsle klar getrennt zwischen deinem privaten Profil und öffentlichen Präsenzen im Creator Hub.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(
                            alpha: 0.64,
                          ),
                          fontSize: 12.5,
                          height: 1.24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _AccountOverviewCurrentProfileTile(
                        profile: profile,
                      ),
                      if (pageController.state.isLoading) ...[
                        const SizedBox(height: 5),
                        const _AccountOverviewLoadingTile(),
                      ] else if (ownedPages.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _AccountOverviewSectionLabel(
                          label: 'Deine Creator-Präsenzen',
                        ),
                        const SizedBox(height: 5),
                        for (final page in ownedPages) ...[
                          _AccountOverviewPageTile(
                            page: page,
                            onTap: () {
                              Navigator.of(context).pop();
                              unawaited(onOpenOwnedPage(page));
                            },
                          ),
                          const SizedBox(height: 5),
                        ],
                      ],
                      const SizedBox(height: 5),
                      _AccountOverviewCreatorHubTile(
                        hasCreatedPages: ownedPages.isNotEmpty,
                        onTap: () {
                          Navigator.of(context).pop();
                          unawaited(onOpenCreatorHub());
                        },
                      ),
                      const SizedBox(height: 5),
                      ProfileSheetActionButton(
                        label: 'Schließen',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccountOverviewCurrentProfileTile extends StatelessWidget {
  final PrivateProfileModel profile;

  const _AccountOverviewCurrentProfileTile({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = profile.displayName.trim().isEmpty
        ? 'Aktuelles Profil'
        : profile.displayName.trim();
    final username = profile.username.trim().isEmpty
        ? 'Privatprofil'
        : '@${profile.username.trim().replaceAll('@', '')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.09),
        ),
      ),
      child: Row(
        children: [
          _AccountOverviewAvatar(
            label: _initials(displayName),
            imageUrl: profile.profileImageUrl,
            icon: Icons.person_outline_rounded,
            isActive: true,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktuelles Profil',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.03,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.05,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.check_circle_rounded,
            color: colorScheme.primary,
            size: 22,
          ),
        ],
      ),
    );
  }

  static String _initials(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) return 'P';

    final parts = cleaned.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _AccountOverviewSectionLabel extends StatelessWidget {
  final String label;

  const _AccountOverviewSectionLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      label,
      style: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.54),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.02,
      ),
    );
  }
}

class _AccountOverviewLoadingTile extends StatelessWidget {
  const _AccountOverviewLoadingTile();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.040),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Creator-Präsenzen werden geladen ...',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountOverviewPageTile extends StatelessWidget {
  final LumaPageModel page;
  final VoidCallback onTap;

  const _AccountOverviewPageTile({
    required this.page,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final username = page.username.trim().isEmpty
        ? page.categoryLabel
        : page.username.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.11),
            ),
          ),
          child: Row(
            children: [
              _AccountOverviewAvatar(
                label: _initials(page.name),
                imageUrl: page.profileImageUrl ?? '',
                icon: Icons.auto_awesome_rounded,
                isActive: false,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$username · ${page.categoryLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.56),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.42),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) return 'P';

    final parts = cleaned.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _AccountOverviewCreatorHubTile extends StatelessWidget {
  final bool hasCreatedPages;
  final VoidCallback onTap;

  const _AccountOverviewCreatorHubTile({
    required this.hasCreatedPages,
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
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.11),
                colorScheme.surface.withValues(alpha: 0.94),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              const _AccountOverviewAvatar(
                label: 'C',
                imageUrl: '',
                icon: Icons.auto_awesome_rounded,
                isActive: false,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creator Hub',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasCreatedPages
                          ? 'Alle öffentlichen Präsenzen verwalten.'
                          : 'Erstelle deine erste öffentliche Präsenz.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.58),
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.46),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountOverviewAvatar extends StatelessWidget {
  final String label;
  final String imageUrl;
  final IconData icon;
  final bool isActive;

  const _AccountOverviewAvatar({
    required this.label,
    required this.imageUrl,
    required this.icon,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cleanedImageUrl = imageUrl.trim();

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isActive ? 0.10 : 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isActive ? 0.20 : 0.14),
        ),
      ),
      child: ClipOval(
        child: cleanedImageUrl.isNotEmpty
            ? Image.network(
                cleanedImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _AvatarFallback(
                    label: label,
                    icon: icon,
                  );
                },
              )
            : _AvatarFallback(
                label: label,
                icon: icon,
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String label;
  final IconData icon;

  const _AvatarFallback({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: label.trim().isEmpty
          ? Icon(
              icon,
              color: colorScheme.primary,
              size: 23,
            )
          : Text(
              label,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.1,
              ),
            ),
    );
  }
}





