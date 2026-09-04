// Pfad: lib/features/profile/presentation/widgets/profile_photos_section.dart

import 'package:flutter/material.dart';

import '../../application/profile_photos_controller.dart';
import '../../domain/profile_photo_model.dart';

class ProfilePhotosSection extends StatelessWidget {
  const ProfilePhotosSection({
    super.key,
    required this.state,
    required this.photos,
    required this.onOpenAll,
    required this.onOpenPhoto,
    this.errorMessage,
  });

  final ProfilePhotosLoadState state;
  final List<ProfilePhotoModel> photos;
  final VoidCallback onOpenAll;
  final ValueChanged<ProfilePhotoModel> onOpenPhoto;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Fotos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (photos.isNotEmpty)
                    TextButton(
                      onPressed: onOpenAll,
                      child: const Text('Alle ansehen'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (state) {
      case ProfilePhotosLoadState.initial:
      case ProfilePhotosLoadState.loading:
        return const SizedBox(
          height: 120,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

      case ProfilePhotosLoadState.hidden:
        return const _PhotoMessage(
          icon: Icons.lock_outline_rounded,
          text: 'Diese Fotos sind für dich nicht sichtbar.',
        );

      case ProfilePhotosLoadState.error:
        return _PhotoMessage(
          icon: Icons.cloud_off_outlined,
          text: errorMessage ?? 'Fotos konnten nicht geladen werden.',
        );

      case ProfilePhotosLoadState.loaded:
        if (photos.isEmpty) {
          return const _PhotoMessage(
            icon: Icons.photo_library_outlined,
            text: 'Noch keine Fotos vorhanden.',
          );
        }

        final visible = photos.take(6).toList(growable: false);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final photo = visible[index];

            return Material(
              color:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onOpenPhoto(photo),
                child: Hero(
                  tag: 'profile-photo-${photo.id}',
                  child: Image.network(
                    photo.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image_outlined),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
    }
  }
}

class _PhotoMessage extends StatelessWidget {
  const _PhotoMessage({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 96,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
