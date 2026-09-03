// Pfad: lib/presentation/widgets/profile_photos_sheet.dart

import 'package:flutter/material.dart';

import 'profile_photo_widgets.dart';
import 'profile_sheet_action_button.dart';
import 'profile_sheet_handle.dart';

class ProfilePhotosSheet {
  const ProfilePhotosSheet._();

  static void show({
    required BuildContext context,
    required List<ProfilePhotoPreviewItemData> photoPreviewItems,
    required bool isViewingOwnProfile,
    required ValueChanged<ProfilePhotoPreviewItemData> onPhotoTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPhotos = photoPreviewItems.isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfileSheetHandle(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fotos',
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
                      ),
                      if (hasPhotos)
                        Text(
                          photoPreviewItems.length == 1
                              ? '1 Foto'
                              : '${photoPreviewItems.length} Fotos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.46),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1,
                            letterSpacing: -0.02,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasPhotos
                        ? 'Profilbilder, Titelbilder und hochgeladene Profilfotos werden hier gesammelt. Tippe ein Foto an, um es größer anzusehen.'
                        : isViewingOwnProfile
                            ? 'Deine Profilfotos erscheinen hier, sobald du ein Profilbild, Titelbild oder weitere Profilfotos gespeichert hast.'
                            : 'Dieses Profil zeigt aktuell keine sichtbaren Fotos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.56),
                      fontSize: 12.7,
                      height: 1.32,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.02,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (hasPhotos)
                    Flexible(
                      child: ProfilePhotosGrid(
                        photos: photoPreviewItems,
                        onPhotoTap: onPhotoTap,
                      ),
                    )
                  else
                    ProfilePhotosEmptySheetState(
                      isOwnProfile: isViewingOwnProfile,
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
      },
    );
  }
}
