// Pfad: lib/features/notifications/domain/notification_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum LumaNotificationType {
  postLike,
  postComment,
  commentReply,
  commentLike,
  postShare,
  friendRequest,
  friendRequestAccepted,
  storyView,
  storyReaction,
  storyReply,
  mention,
  groupActivity,
  pageActivity,
  newFollower,
  relationshipRequest,
  relationshipAccepted,
  relationshipRejected,
  relationshipCancelled,
  relationshipRemoved,
  relationshipChanged,
  securityAlert,
  systemUpdate,
  unknown,
}

enum LumaNotificationPriority {
  high,
  medium,
  low,
  unknown,
}

enum LumaNotificationTargetType {
  post,
  comment,
  profile,
  story,
  group,
  page,
  relationship,
  system,
  unknown,
}

class LumaNotificationModel {
  const LumaNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.priority,
    required this.targetType,
    required this.referenceId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.isRead,
    required this.isActionable,
    required this.schemaVersion,
    this.actorUserId,
    this.actorDisplayName,
    this.actorUsername,
    this.actorAvatarUrl,
    this.secondaryReferenceId,
    this.friendshipId,
    this.previewText,
    this.contentThumbnailUrl,
    this.reactionType,
    this.groupKey,
    this.deduplicationKey,
    this.groupCount = 1,
    this.actorUserIds = const <String>[],
    this.actorDisplayNames = const <String>[],
    this.groupedNotificationIds = const <String>[],
    this.unreadNotificationIds = const <String>[],
    this.readAt,
    this.friendRequestStatus,
  });

  final String id;
  final String userId;
  final String? actorUserId;
  final String? actorDisplayName;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final LumaNotificationType type;
  final LumaNotificationPriority priority;
  final LumaNotificationTargetType targetType;
  final String referenceId;
  final String? secondaryReferenceId;
  final String? friendshipId;
  final String? previewText;
  final String? contentThumbnailUrl;
  final String? reactionType;
  final String? groupKey;
  final String? deduplicationKey;
  final int groupCount;
  final List<String> actorUserIds;
  final List<String> actorDisplayNames;
  final List<String> groupedNotificationIds;
  final List<String> unreadNotificationIds;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final bool isRead;
  final bool isActionable;
  final int schemaVersion;
  final String? friendRequestStatus;

  bool get isUnread => !isRead;

  factory LumaNotificationModel.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return LumaNotificationModel(
      id: _readString(data['id'], fallback: id),
      userId: _readString(data['userId']),
      actorUserId: _readNullableString(data['actorUserId']),
      actorDisplayName: _readNullableString(data['actorDisplayName']),
      actorUsername: _readNullableString(data['actorUsername']),
      actorAvatarUrl: _readNullableString(data['actorAvatarUrl']),
      type: _readType(data['type']),
      priority: _readPriority(data['priority']),
      targetType: _readTargetType(data['targetType']),
      referenceId: _readString(data['referenceId']),
      secondaryReferenceId: _readNullableString(data['secondaryReferenceId']),
      friendshipId: _readNullableString(data['friendshipId']),
      previewText: _readNullableString(data['previewText']),
      contentThumbnailUrl: _readNullableString(data['contentThumbnailUrl']),
      reactionType: _readNullableString(data['reactionType']),
      groupKey: _readNullableString(data['groupKey']),
      deduplicationKey: _readNullableString(data['deduplicationKey']),
      groupCount: _readNonNegativeInt(data['groupCount'], fallback: 1),
      actorUserIds: _readStringList(data['actorUserIds']),
      actorDisplayNames: _readStringList(data['actorDisplayNames']),
      groupedNotificationIds: _readStringList(data['groupedNotificationIds']),
      unreadNotificationIds: _readStringList(data['unreadNotificationIds']),
      title: _readString(data['title'], fallback: 'Benachrichtigung'),
      body: _readString(data['body']),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
      readAt: _readNullableDateTime(data['readAt']),
      isRead: data['isRead'] == true,
      isActionable: data['isActionable'] == true,
      schemaVersion: _readNonNegativeInt(data['schemaVersion'], fallback: 1),
      friendRequestStatus: _readNullableString(data['friendRequestStatus']),
    );
  }

  static LumaNotificationType _readType(dynamic value) {
    final raw = _readString(value);
    for (final type in LumaNotificationType.values) {
      if (type.name == raw) return type;
    }
    return LumaNotificationType.unknown;
  }

  static LumaNotificationPriority _readPriority(dynamic value) {
    final raw = _readString(value);
    for (final priority in LumaNotificationPriority.values) {
      if (priority.name == raw) return priority;
    }
    return LumaNotificationPriority.unknown;
  }

  static LumaNotificationTargetType _readTargetType(dynamic value) {
    final raw = _readString(value);
    for (final target in LumaNotificationTargetType.values) {
      if (target.name == raw) return target;
    }
    return LumaNotificationTargetType.unknown;
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static String? _readNullableString(dynamic value) {
    if (value is! String) return null;
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static int _readNonNegativeInt(dynamic value, {required int fallback}) {
    if (value is num) {
      final parsed = value.toInt();
      return parsed < 0 ? 0 : parsed;
    }
    return fallback;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];

    final result = <String>[];
    for (final item in value) {
      if (item is! String) continue;
      final cleaned = item.trim();
      if (cleaned.isNotEmpty) {
        result.add(cleaned);
      }
    }

    return List<String>.unmodifiable(result);
  }

  static DateTime _readDateTime(dynamic value) {
    return _readNullableDateTime(value) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _readNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);

    try {
      final dynamic seconds = value.seconds;
      final dynamic nanoseconds = value.nanoseconds;
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 +
              (nanoseconds is int ? nanoseconds ~/ 1000000 : 0),
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
