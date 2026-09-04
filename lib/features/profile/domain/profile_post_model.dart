// Pfad: lib/features/profile/domain/profile_post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ProfilePostVisibility {
  public,
  friends,
  private,
}

enum ProfilePostType {
  standard,
  repost,
}

@immutable
class ProfilePostModel {
  const ProfilePostModel({
    required this.id,
    required this.authorId,
    required this.username,
    required this.userAvatarUrl,
    required this.contentText,
    required this.imageUrl,
    required this.videoUrl,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.visibility,
    required this.postType,
    required this.originalPostId,
    required this.originalUsername,
    required this.originalContentText,
    required this.originalImageUrl,
    required this.originalVideoUrl,
  });

  final String id;
  final String authorId;
  final String username;
  final String userAvatarUrl;
  final String contentText;
  final String imageUrl;
  final String videoUrl;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final ProfilePostVisibility visibility;
  final ProfilePostType postType;

  final String originalPostId;
  final String originalUsername;
  final String originalContentText;
  final String originalImageUrl;
  final String originalVideoUrl;

  bool get hasText => contentText.trim().isNotEmpty;
  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasVideo => videoUrl.trim().isNotEmpty;
  bool get isRepost => postType == ProfilePostType.repost;

  bool get hasOriginalContent =>
      originalPostId.trim().isNotEmpty ||
      originalContentText.trim().isNotEmpty ||
      originalImageUrl.trim().isNotEmpty ||
      originalVideoUrl.trim().isNotEmpty;

  factory ProfilePostModel.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final userId = _readString(data['userId']);
    final authorId = _readString(data['authorId']);

    return ProfilePostModel(
      id: id.trim(),
      authorId: authorId.isNotEmpty ? authorId : userId,
      username: _readString(
        data['username'],
        fallback: 'Luma Nutzer',
      ),
      userAvatarUrl: _readString(data['userAvatarUrl']),
      contentText: _readString(data['contentText']),
      imageUrl: _readFirstString(
        data,
        const <String>['imageUrl', 'feedImageUrl'],
      ),
      videoUrl: _readString(data['videoUrl']),
      createdAt: _readDateTime(data['createdAt']),
      likeCount: _readInt(data['likeCount']),
      commentCount: _readInt(data['commentCount']),
      visibility: _readVisibility(data['visibility']),
      postType: _readPostType(data['postType']),
      originalPostId: _readString(data['originalPostId']),
      originalUsername: _readString(data['originalUsername']),
      originalContentText: _readString(data['originalContentText']),
      originalImageUrl: _readString(data['originalImageUrl']),
      originalVideoUrl: _readString(data['originalVideoUrl']),
    );
  }

  static ProfilePostVisibility _readVisibility(dynamic value) {
    final cleaned = _readString(value).toLowerCase();
    switch (cleaned) {
      case 'private':
        return ProfilePostVisibility.private;
      case 'friends':
        return ProfilePostVisibility.friends;
      case 'public':
      default:
        return ProfilePostVisibility.public;
    }
  }

  static ProfilePostType _readPostType(dynamic value) {
    return _readString(value).toLowerCase() == 'repost'
        ? ProfilePostType.repost
        : ProfilePostType.standard;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.isNotEmpty) return cleaned;
    }
    return fallback;
  }

  static String _readFirstString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _readString(data[key]);
      if (value.isNotEmpty) return value;
    }
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
