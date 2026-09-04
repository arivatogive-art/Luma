// Pfad: lib/features/profile/domain/profile_photo_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ProfilePhotoType {
  profileImage,
  coverImage,
  upload,
}

@immutable
class ProfilePhotoModel {
  const ProfilePhotoModel({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.storagePath,
    required this.type,
    required this.caption,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String imageUrl;
  final String storagePath;
  final ProfilePhotoType type;
  final String caption;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasCaption => caption.trim().isNotEmpty;
  bool get isProfileImage => type == ProfilePhotoType.profileImage;
  bool get isCoverImage => type == ProfilePhotoType.coverImage;
  bool get isUpload => type == ProfilePhotoType.upload;

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'type': type.name,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ProfilePhotoModel.fromFirestore({
    required String id,
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return ProfilePhotoModel(
      id: id.trim(),
      userId: userId.trim(),
      imageUrl: _readString(data['imageUrl']),
      storagePath: _readString(data['storagePath']),
      type: _readType(data['type']),
      caption: _readString(data['caption']),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  static ProfilePhotoType _readType(dynamic value) {
    if (value is String) {
      final cleaned = value.trim();
      for (final type in ProfilePhotoType.values) {
        if (type.name == cleaned) return type;
      }
    }
    return ProfilePhotoType.upload;
  }

  static String _readString(dynamic value) {
    if (value is String) return value.trim();
    return '';
  }

  static DateTime _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
