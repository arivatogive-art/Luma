// Pfad: lib/presentation/widgets/profile_photo_preview_builder.dart

import 'package:flutter/material.dart';

import '../../domain/models/profile_photo_model.dart';
import 'profile_photo_widgets.dart';

class ProfilePhotoPreviewBuilder {
  const ProfilePhotoPreviewBuilder._();

  static List<ProfilePhotoPreviewItemData> buildItems({
    required List<ProfilePhotoModel> profilePhotos,
    required String profileImageUrl,
    required String coverImageUrl,
  }) {
    final items = <ProfilePhotoPreviewItemData>[];
    final seenUrls = <String>{};

    void addItem({
      required String imageUrl,
      required String label,
      required IconData icon,
      ProfilePhotoType? type,
      DateTime? createdAt,
    }) {
      final cleanedUrl = imageUrl.trim();
      if (cleanedUrl.isEmpty) return;
      if (seenUrls.contains(cleanedUrl)) return;

      seenUrls.add(cleanedUrl);
      items.add(
        ProfilePhotoPreviewItemData(
          imageUrl: cleanedUrl,
          label: label,
          icon: icon,
          type: type,
          createdAt: createdAt,
        ),
      );
    }

    final sortedPhotos = [...profilePhotos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final photo in sortedPhotos) {
      final label = switch (photo.type) {
        ProfilePhotoType.profileImage => 'Profilbild',
        ProfilePhotoType.coverImage => 'Titelbild',
        ProfilePhotoType.upload => photo.hasCaption ? photo.caption : 'Foto',
      };

      final icon = switch (photo.type) {
        ProfilePhotoType.profileImage => Icons.account_circle_outlined,
        ProfilePhotoType.coverImage => Icons.landscape_outlined,
        ProfilePhotoType.upload => Icons.photo_outlined,
      };

      addItem(
        imageUrl: photo.imageUrl,
        label: label,
        icon: icon,
        type: photo.type,
        createdAt: photo.createdAt,
      );
    }

    addItem(
      imageUrl: profileImageUrl,
      label: 'Profilbild',
      icon: Icons.account_circle_outlined,
      type: ProfilePhotoType.profileImage,
    );

    addItem(
      imageUrl: coverImageUrl,
      label: 'Titelbild',
      icon: Icons.landscape_outlined,
      type: ProfilePhotoType.coverImage,
    );

    return items;
  }

  static List<String> buildUrls({
    required List<ProfilePhotoModel> profilePhotos,
    required String profileImageUrl,
    required String coverImageUrl,
  }) {
    return buildItems(
      profilePhotos: profilePhotos,
      profileImageUrl: profileImageUrl,
      coverImageUrl: coverImageUrl,
    )
        .map((item) => item.imageUrl)
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
  }
}
