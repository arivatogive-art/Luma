// Pfad: lib/presentation/widgets/profile_media_source_sheet.dart

import 'package:flutter/material.dart';

import 'profile_sheet_action_button.dart';
import 'profile_sheet_handle.dart';

class ProfileMediaSourceSheet extends StatelessWidget {
  final String title;
  final bool isProfileImage;
  final bool hasImage;
  final bool isUploading;
  final Future<void> Function() onPickFromGallery;
  final Future<void> Function() onPickFromCamera;
  final VoidCallback onRemove;

  const ProfileMediaSourceSheet({
    super.key,
    required this.title,
    required this.isProfileImage,
    required this.hasImage,
    required this.isUploading,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileSheetHandle(),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isProfileImage
                  ? 'Wähle ein Bild für deinen sichtbaren Profilauftritt.'
                  : 'Wähle ein Bild für die obere Darstellung deines Profils.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                fontSize: 12.5,
                height: 1.24,
              ),
            ),
            if (isUploading) ...[
              const SizedBox(height: 5),
              Text(
                isProfileImage
                    ? 'Profilbild wird gerade verarbeitet. Bitte warte, bis der aktuelle Upload abgeschlossen ist.'
                    : 'Coverbild wird gerade verarbeitet. Bitte warte, bis der aktuelle Upload abgeschlossen ist.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 5),
            ProfileSheetActionButton(
              label: isUploading ? 'Upload läuft ...' : 'Aus Galerie auswählen',
              onPressed: () async {
                if (isUploading) return;
                Navigator.of(context).pop();
                await onPickFromGallery();
              },
            ),
            const SizedBox(height: 5),
            ProfileSheetActionButton(
              label: isUploading ? 'Upload läuft ...' : 'Mit Kamera aufnehmen',
              onPressed: () async {
                if (isUploading) return;
                Navigator.of(context).pop();
                await onPickFromCamera();
              },
            ),
            if (hasImage) ...[
              const SizedBox(height: 5),
              ProfileSheetActionButton(
                label: isUploading ? 'Entfernen nicht möglich' : 'Entfernen',
                destructive: true,
                onPressed: () {
                  if (isUploading) return;
                  Navigator.of(context).pop();
                  onRemove();
                },
              ),
            ],
            const SizedBox(height: 5),
            ProfileSheetActionButton(
              label: 'Schließen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
