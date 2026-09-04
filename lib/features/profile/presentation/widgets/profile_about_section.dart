// Pfad: lib/features/profile/presentation/widgets/profile_about_section.dart

import 'package:flutter/material.dart';

import '../../domain/profile_model.dart';

class ProfileAboutSection extends StatelessWidget {
  const ProfileAboutSection({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    if (!profile.hasAboutInformation) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Info',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              if (profile.hasLocation)
                _ProfileAboutRow(
                  icon: Icons.location_on_outlined,
                  label: 'Wohnort',
                  value: profile.location,
                ),
              if (profile.hasWork)
                _ProfileAboutRow(
                  icon: Icons.work_outline_rounded,
                  label: 'Arbeit',
                  value: profile.work,
                ),
              if (profile.hasEducation)
                _ProfileAboutRow(
                  icon: Icons.school_outlined,
                  label: 'Ausbildung',
                  value: profile.education,
                ),
              if (profile.hasWebsite)
                _ProfileAboutRow(
                  icon: Icons.language_rounded,
                  label: 'Webseite',
                  value: profile.website,
                  isLast: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAboutRow extends StatelessWidget {
  const _ProfileAboutRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 21,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
