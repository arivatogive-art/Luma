// Pfad: lib/features/comments/domain/profile_post_comment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePostCommentModel {
  const ProfilePostCommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.parentCommentId,
    required this.likeCount,
    required this.reactionCount,
    required this.reactionCounts,
    required this.replyCount,
    required this.isDeleted,
    required this.schemaVersion,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? parentCommentId;
  final int likeCount;
  final int reactionCount;
  final Map<String, int> reactionCounts;
  final int replyCount;
  final bool isDeleted;
  final int schemaVersion;

  bool get isReply {
    final value = parentCommentId?.trim() ?? '';
    return value.isNotEmpty;
  }

  bool get isRootComment => !isReply;

  static ProfilePostCommentModel fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final rawParentCommentId = _readString(data['parentCommentId']).trim();

    return ProfilePostCommentModel(
      id: _readString(data['id']).trim().isNotEmpty
          ? _readString(data['id']).trim()
          : id.trim(),
      postId: _readString(data['postId']).trim(),
      authorId: _readString(data['authorId']).trim(),
      authorName: _readString(data['authorName']).trim(),
      authorAvatarUrl: _readString(data['authorAvatarUrl']).trim(),
      text: _readString(data['text']).trim(),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readNullableDateTime(data['updatedAt']),
      deletedAt: _readNullableDateTime(data['deletedAt']),
      parentCommentId:
          rawParentCommentId.isEmpty ? null : rawParentCommentId,
      likeCount: _readNonNegativeInt(data['likeCount']),
      reactionCount: _readNonNegativeInt(data['reactionCount']),
      reactionCounts: _readReactionCounts(data['reactionCounts']),
      replyCount: _readNonNegativeInt(data['replyCount']),
      isDeleted: data['isDeleted'] == true,
      schemaVersion: _readNonNegativeInt(data['schemaVersion']),
    );
  }

  static String _readString(dynamic value) {
    return value is String ? value : '';
  }

  static int _readNonNegativeInt(dynamic value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final converted = value.toInt();
      return converted < 0 ? 0 : converted;
    }

    return 0;
  }

  static DateTime _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _readNullableDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
  }

  static Map<String, int> _readReactionCounts(dynamic value) {
    const supportedTypes = <String>{
      'like',
      'love',
      'haha',
      'wow',
      'sad',
      'angry',
    };

    if (value is! Map) {
      return const <String, int>{
        'like': 0,
        'love': 0,
        'haha': 0,
        'wow': 0,
        'sad': 0,
        'angry': 0,
      };
    }

    final counts = <String, int>{};

    for (final type in supportedTypes) {
      counts[type] = _readNonNegativeInt(value[type]);
    }

    return Map<String, int>.unmodifiable(counts);
  }
}
