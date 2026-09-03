// Pfad: lib/presentation/widgets/profile_info_sheet.dart

import 'package:flutter/material.dart';

import '../../domain/models/private_profile_model.dart';
import 'profile_about_card.dart';
import 'profile_sheet_action_button.dart';
import 'profile_sheet_handle.dart';

class ProfileInfoSheet extends StatelessWidget {
  final PrivateProfileModel profile;
  final bool isOwnProfile;
  final bool showBirthdayYear;
  final ValueChanged<String> onWebsiteTap;

  const ProfileInfoSheet({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.showBirthdayYear,
    required this.onWebsiteTap,
  });

  static void show({
    required BuildContext context,
    required PrivateProfileModel profile,
    required bool isOwnProfile,
    required bool showBirthdayYear,
    required ValueChanged<String> onWebsiteTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return ProfileInfoSheet(
          profile: profile,
          isOwnProfile: isOwnProfile,
          showBirthdayYear: showBirthdayYear,
          onWebsiteTap: onWebsiteTap,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProfileSheetHandle(),
              Text(
                'Info',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  letterSpacing: -0.18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isOwnProfile
                    ? 'Deine Profilinformationen an einem Ort. Sichtbarkeit und Privatsphäre können später gezielt angebunden werden.'
                    : 'Die sichtbaren Profilinformationen dieses Nutzers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.56),
                  fontSize: 12.7,
                  height: 1.32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 12),
              ProfileAboutCard(
                profile: profile,
                isOwnProfile: isOwnProfile,
                showBirthdayYear: showBirthdayYear,
                onWebsiteTap: onWebsiteTap,
              ),
              const SizedBox(height: 12),
              ProfileSheetActionButton(
                label: 'Schließen',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
