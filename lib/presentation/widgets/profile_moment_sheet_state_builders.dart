// Pfad: lib/presentation/widgets/profile_moment_sheet_state_builders.dart

import 'package:flutter/material.dart';

import 'profile_screen_support_widgets.dart';

class ProfileMomentSheetStateBuilders {
  const ProfileMomentSheetStateBuilders._();

  static Widget buildLoading(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ProfileMomentSheetStateCard(
      icon: Icons.auto_awesome_motion_outlined,
      iconColor: colorScheme.primary,
      backgroundColor: isDark
          ? colorScheme.surface.withValues(alpha: 0.44)
          : colorScheme.surface.withValues(alpha: 0.74),
      borderColor: isDark
          ? colorScheme.outline.withValues(alpha: 0.13)
          : const Color(0xFFEDE1D4),
      title: 'Momente werden geladen',
      message:
          'Luma sammelt gerade die sichtbaren Profilmomente für diesen Bereich.',
      trailing: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: colorScheme.primary.withValues(alpha: 0.82),
        ),
      ),
    );
  }

  static Widget buildError({
    required BuildContext context,
    required String? momentError,
    required String viewedUserId,
    required void Function(String viewedUserId) onRetry,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cleanViewedUserId = viewedUserId.trim();

    return ProfileMomentSheetStateCard(
      icon: Icons.cloud_off_outlined,
      iconColor: colorScheme.error.withValues(alpha: isDark ? 0.74 : 0.68),
      backgroundColor: isDark
          ? colorScheme.error.withValues(alpha: 0.035)
          : colorScheme.errorContainer.withValues(alpha: 0.18),
      borderColor: colorScheme.error.withValues(alpha: isDark ? 0.14 : 0.12),
      title: 'Momente konnten nicht geladen werden',
      message: momentError?.trim().isNotEmpty == true
          ? momentError!.trim()
          : 'Die Verbindung zu den Profilmomenten wurde kurz unterbrochen.',
      actionLabel: cleanViewedUserId.isEmpty ? null : 'Erneut versuchen',
      onActionTap: cleanViewedUserId.isEmpty
          ? null
          : () => onRetry(cleanViewedUserId),
    );
  }

  static Widget buildEmpty({
    required BuildContext context,
    required bool isViewingOwnProfile,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ProfileMomentSheetStateCard(
      icon: isViewingOwnProfile
          ? Icons.auto_awesome_outlined
          : Icons.notes_outlined,
      iconColor: colorScheme.primary,
      backgroundColor: isDark
          ? colorScheme.surface.withValues(alpha: 0.44)
          : const Color(0xFFFFFBF6),
      borderColor: isDark
          ? colorScheme.outline.withValues(alpha: 0.13)
          : const Color(0xFFEDE1D4),
      title: isViewingOwnProfile
          ? 'Noch kein Moment geteilt'
          : 'Noch keine sichtbaren Momente',
      message: isViewingOwnProfile
          ? 'Teile einen kurzen Gedanken, eine Stimmung oder eine kleine Erinnerung, wenn dein Profil persönlicher wirken soll.'
          : 'Dieses Profil hat aktuell keine Profilmomente freigegeben.',
    );
  }
}
