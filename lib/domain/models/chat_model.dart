// Pfad: lib/domain/models/chat_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum MessengerChatBackgroundPreset {
  standard,
  softLight,
  calmDark,
  warmOrange;

  static MessengerChatBackgroundPreset fromName(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return MessengerChatBackgroundPreset.standard;

    for (final preset in MessengerChatBackgroundPreset.values) {
      if (preset.name == cleaned) return preset;
    }

    return MessengerChatBackgroundPreset.standard;
  }

  String get label {
    switch (this) {
      case MessengerChatBackgroundPreset.standard:
        return 'Standard';
      case MessengerChatBackgroundPreset.softLight:
        return 'Hell';
      case MessengerChatBackgroundPreset.calmDark:
        return 'Dunkel';
      case MessengerChatBackgroundPreset.warmOrange:
        return 'Orange';
    }
  }

  String get description {
    switch (this) {
      case MessengerChatBackgroundPreset.standard:
        return 'Luma Standard';
      case MessengerChatBackgroundPreset.softLight:
        return 'Weich und hell';
      case MessengerChatBackgroundPreset.calmDark:
        return 'Ruhig und dunkel';
      case MessengerChatBackgroundPreset.warmOrange:
        return 'Warmer Akzent';
    }
  }
}

enum MessengerFriendshipStatus {
  unknown,
  friends,
  requestSent,
  requestReceived,
  none;

  static MessengerFriendshipStatus fromName(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return MessengerFriendshipStatus.unknown;

    for (final status in MessengerFriendshipStatus.values) {
      if (status.name == cleaned) return status;
    }

    return MessengerFriendshipStatus.unknown;
  }

  String get label {
    switch (this) {
      case MessengerFriendshipStatus.friends:
        return 'Freunde';
      case MessengerFriendshipStatus.requestSent:
        return 'Anfrage gesendet';
      case MessengerFriendshipStatus.requestReceived:
        return 'Anfrage erhalten';
      case MessengerFriendshipStatus.none:
        return 'Kein Freund';
      case MessengerFriendshipStatus.unknown:
        return 'Direkter Kontakt';
    }
  }

  String get description {
    switch (this) {
      case MessengerFriendshipStatus.friends:
        return 'Ihr seid auf Luma befreundet.';
      case MessengerFriendshipStatus.requestSent:
        return 'Du hast dieser Person eine Freundschaftsanfrage gesendet.';
      case MessengerFriendshipStatus.requestReceived:
        return 'Diese Person hat dir eine Freundschaftsanfrage gesendet.';
      case MessengerFriendshipStatus.none:
        return 'Ihr seid aktuell nicht befreundet.';
      case MessengerFriendshipStatus.unknown:
        return 'Freundschaftsstatus ist gespeichert, sobald das Friendship-System ihn setzt.';
    }
  }
}

@immutable
class ChatParticipantModel {
  final String userId;
  final String displayName;
  final String avatarUrl;
  final bool isOnline;

  const ChatParticipantModel({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.isOnline = false,
  });

  factory ChatParticipantModel.fromMap(Map<String, dynamic> map) {
    return ChatParticipantModel(
      userId: _readString(map['userId']),
      displayName: _readString(map['displayName'], fallback: 'Luma Nutzer'),
      avatarUrl: _readString(map['avatarUrl']),
      isOnline: _readBool(map['isOnline']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId.trim(),
      'displayName': displayName.trim().isEmpty
          ? 'Luma Nutzer'
          : displayName.trim(),
      'avatarUrl': avatarUrl.trim(),
    };
  }

  ChatParticipantModel copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    bool? isOnline,
  }) {
    return ChatParticipantModel(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatParticipantModel &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.isOnline == isOnline;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      displayName,
      avatarUrl,
      isOnline,
    );
  }
}

@immutable
class ChatModel {
  final String id;
  final List<ChatParticipantModel> participants;
  final List<String> participantIds;
  final String lastMessagePreview;
  final String lastMessageSenderId;
  final String lastMessageType;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> unreadCountsByUserId;
  final Set<String> pinnedUserIds;
  final Set<String> mutedUserIds;
  final Set<String> archivedUserIds;
  final Set<String> deletedForUserIds;
  final Map<String, String> chatBackgroundPresetsByUserId;
  final Map<String, String> friendshipStatusesByUserId;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final bool isDeletedForCurrentUser;

  /// Page-Metadaten bleiben getrennt von der technischen User-ID des
  /// angemeldeten Page-Verwalters.
  final String conversationType;
  final String pageId;
  final String pageName;
  final String pageUsername;
  final String pageAvatarUrl;
  final String pageOwnerUserId;
  final Set<String> pageTeamUserIds;
  final String supportRequesterUserId;
  final String supportStatus;
  final String pageMessagingMode;
  final bool isManagedByCurrentUser;

  const ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    this.participantIds = const <String>[],
    this.lastMessageSenderId = '',
    this.lastMessageType = 'text',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.unreadCountsByUserId = const <String, int>{},
    this.pinnedUserIds = const <String>{},
    this.mutedUserIds = const <String>{},
    this.archivedUserIds = const <String>{},
    this.deletedForUserIds = const <String>{},
    this.chatBackgroundPresetsByUserId = const <String, String>{},
    this.friendshipStatusesByUserId = const <String, String>{},
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.isDeletedForCurrentUser = false,
    this.conversationType = '',
    this.pageId = '',
    this.pageName = '',
    this.pageUsername = '',
    this.pageAvatarUrl = '',
    this.pageOwnerUserId = '',
    this.pageTeamUserIds = const <String>{},
    this.supportRequesterUserId = '',
    this.supportStatus = '',
    this.pageMessagingMode = '',
    this.isManagedByCurrentUser = false,
  })  : createdAt = createdAt ?? lastMessageAt,
        updatedAt = updatedAt ?? lastMessageAt;

  factory ChatModel.fromMap({
    required String id,
    required Map<String, dynamic> map,
    required String currentUserId,
  }) {
    final participantsRaw = map['participants'];
    final participants = participantsRaw is List
        ? participantsRaw
            .whereType<Map>()
            .map(
              (entry) => ChatParticipantModel.fromMap(
                Map<String, dynamic>.from(entry),
              ),
            )
            .where((participant) => participant.userId.trim().isNotEmpty)
            .toList(growable: false)
        : const <ChatParticipantModel>[];

    final participantIdsFromMap = _readStringList(map['participantIds']);
    final participantIds = participantIdsFromMap.isNotEmpty
        ? participantIdsFromMap
        : _participantIdsFromParticipants(participants);

    final unreadCounts = _readIntMap(map['unreadCountsByUserId']);
    final pinnedUserIds = _readStringSet(map['pinnedUserIds']);
    final mutedUserIds = _readStringSet(map['mutedUserIds']);
    final archivedUserIds = _readStringSet(map['archivedUserIds']);
    final deletedForUserIds = _readStringSet(map['deletedForUserIds']);
    final chatBackgroundPresetsByUserId = _readStringMap(map['chatBackgroundPresetsByUserId']);
    final friendshipStatusesByUserId = _readStringMap(map['friendshipStatusesByUserId']);

    final lastMessageAt = _readDateTime(map['lastMessageAt']);
    final createdAt = _readDateTime(map['createdAt'], fallback: lastMessageAt);
    final updatedAt = _readDateTime(map['updatedAt'], fallback: lastMessageAt);

    final cleanedCurrentUserId = currentUserId.trim();
    final conversationType = _readString(map['conversationType']);
    final pageId = _readString(map['pageId']);
    final pageName = _readString(map['pageName']);
    final pageUsername = _readString(map['pageUsername']);
    final pageAvatarUrl = _readString(map['pageAvatarUrl']);
    final pageOwnerUserId = _readString(map['pageOwnerUserId']);
    final pageTeamUserIds = _readStringSet(map['pageTeamUserIds']);
    final supportRequesterUserId =
        _readString(map['supportRequesterUserId']);
    final supportStatus = _readString(map['supportStatus']);
    final pageMessagingMode = _readString(
      map['pageMessagingMode'],
      fallback: conversationType == 'pageSupport'
          ? 'support'
          : '',
    );
    final isManagedByCurrentUser =
        pageTeamUserIds.contains(cleanedCurrentUserId) ||
        (pageOwnerUserId.isNotEmpty &&
            pageOwnerUserId == cleanedCurrentUserId);

    final visibleParticipants = participants
        .where((participant) => participant.userId != cleanedCurrentUserId)
        .toList(growable: false);

    return ChatModel(
      id: id.trim(),
      participants: visibleParticipants.isEmpty ? participants : visibleParticipants,
      participantIds: participantIds,
      lastMessagePreview: _readString(
        map['lastMessagePreview'],
        fallback: 'Noch keine Nachrichten',
      ),
      lastMessageSenderId: _readString(map['lastMessageSenderId']),
      lastMessageType: _readString(map['lastMessageType'], fallback: 'text'),
      lastMessageAt: lastMessageAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      unreadCountsByUserId: unreadCounts,
      pinnedUserIds: pinnedUserIds,
      mutedUserIds: mutedUserIds,
      archivedUserIds: archivedUserIds,
      deletedForUserIds: deletedForUserIds,
      chatBackgroundPresetsByUserId: chatBackgroundPresetsByUserId,
      friendshipStatusesByUserId: friendshipStatusesByUserId,
      unreadCount: unreadCounts[cleanedCurrentUserId] ?? 0,
      isPinned: pinnedUserIds.contains(cleanedCurrentUserId),
      isMuted: mutedUserIds.contains(cleanedCurrentUserId),
      isArchived: archivedUserIds.contains(cleanedCurrentUserId),
      isDeletedForCurrentUser: deletedForUserIds.contains(cleanedCurrentUserId),
      conversationType: conversationType,
      pageId: pageId,
      pageName: pageName,
      pageUsername: pageUsername,
      pageAvatarUrl: pageAvatarUrl,
      pageOwnerUserId: pageOwnerUserId,
      pageTeamUserIds: pageTeamUserIds,
      supportRequesterUserId: supportRequesterUserId,
      supportStatus: supportStatus,
      pageMessagingMode: pageMessagingMode,
      isManagedByCurrentUser: isManagedByCurrentUser,
    );
  }

  Map<String, dynamic> toMap() {
    final safeParticipantIds = participantIds.isNotEmpty
        ? _cleanStringList(participantIds)
        : _participantIdsFromParticipants(participants);

    return {
      'participantIds': safeParticipantIds,
      'participants': participants
          .where((participant) => participant.userId.trim().isNotEmpty)
          .map((participant) => participant.toMap())
          .toList(growable: false),
      'lastMessagePreview': lastMessagePreview.trim().isEmpty
          ? 'Noch keine Nachrichten'
          : lastMessagePreview.trim(),
      'lastMessageSenderId': lastMessageSenderId.trim(),
      'lastMessageType': lastMessageType.trim().isEmpty
          ? 'text'
          : lastMessageType.trim(),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'unreadCountsByUserId': _cleanIntMap(unreadCountsByUserId),
      'pinnedUserIds': _cleanStringSet(pinnedUserIds).toList(growable: false),
      'mutedUserIds': _cleanStringSet(mutedUserIds).toList(growable: false),
      'archivedUserIds': _cleanStringSet(archivedUserIds).toList(growable: false),
      'deletedForUserIds': _cleanStringSet(deletedForUserIds).toList(growable: false),
      'chatBackgroundPresetsByUserId': _cleanStringMap(chatBackgroundPresetsByUserId),
      'friendshipStatusesByUserId': _cleanStringMap(friendshipStatusesByUserId),
      if (conversationType.trim().isNotEmpty)
        'conversationType': conversationType.trim(),
      if (pageId.trim().isNotEmpty) 'pageId': pageId.trim(),
      if (pageName.trim().isNotEmpty) 'pageName': pageName.trim(),
      if (pageUsername.trim().isNotEmpty)
        'pageUsername': pageUsername.trim(),
      if (pageAvatarUrl.trim().isNotEmpty)
        'pageAvatarUrl': pageAvatarUrl.trim(),
      if (pageOwnerUserId.trim().isNotEmpty)
        'pageOwnerUserId': pageOwnerUserId.trim(),
      if (pageTeamUserIds.isNotEmpty)
        'pageTeamUserIds':
            _cleanStringSet(pageTeamUserIds).toList(growable: false),
      if (supportRequesterUserId.trim().isNotEmpty)
        'supportRequesterUserId': supportRequesterUserId.trim(),
      if (supportStatus.trim().isNotEmpty)
        'supportStatus': supportStatus.trim(),
      if (pageMessagingMode.trim().isNotEmpty)
        'pageMessagingMode': pageMessagingMode.trim(),
    };
  }

  bool get isPageConversation =>
      conversationType == 'pageSupport' && pageId.trim().isNotEmpty;

  bool get isCreatorPageConversation =>
      isPageConversation && pageMessagingMode == 'creator';

  bool get isSupportPageConversation =>
      isPageConversation && !isCreatorPageConversation;

  String get visiblePageName {
    final value = pageName.trim();
    return value.isEmpty ? 'Luma Page' : value;
  }

  String get title {
    if (isPageConversation &&
        !isManagedByCurrentUser &&
        pageName.trim().isNotEmpty) {
      return pageName.trim();
    }

    if (participants.isEmpty) {
      return 'Unbekannter Chat';
    }

    if (participants.length == 1) {
      final name = participants.first.displayName.trim();
      return name.isEmpty ? 'Luma Nutzer' : name;
    }

    return participants
        .map((participant) => participant.displayName.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
  }

  String get primaryAvatarUrl {
    if (isPageConversation &&
        !isManagedByCurrentUser &&
        pageAvatarUrl.trim().isNotEmpty) {
      return pageAvatarUrl.trim();
    }

    if (participants.isEmpty) {
      return '';
    }

    return participants.first.avatarUrl;
  }

  bool get hasUnreadMessages => unreadCount > 0;

  bool isPinnedForUser(String userId) {
    return pinnedUserIds.contains(userId.trim());
  }

  bool isMutedForUser(String userId) {
    return mutedUserIds.contains(userId.trim());
  }

  bool isArchivedForUser(String userId) {
    return archivedUserIds.contains(userId.trim());
  }

  bool isDeletedForUser(String userId) {
    return deletedForUserIds.contains(userId.trim());
  }

  int unreadCountForUser(String userId) {
    return unreadCountsByUserId[userId.trim()] ?? 0;
  }

  MessengerChatBackgroundPreset chatBackgroundPresetForUser(String userId) {
    return MessengerChatBackgroundPreset.fromName(
      chatBackgroundPresetsByUserId[userId.trim()],
    );
  }

  MessengerFriendshipStatus friendshipStatusForUser(String userId) {
    return MessengerFriendshipStatus.fromName(
      friendshipStatusesByUserId[userId.trim()],
    );
  }

  ChatModel copyWith({
    String? id,
    List<ChatParticipantModel>? participants,
    List<String>? participantIds,
    String? lastMessagePreview,
    String? lastMessageSenderId,
    String? lastMessageType,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? unreadCountsByUserId,
    Set<String>? pinnedUserIds,
    Set<String>? mutedUserIds,
    Set<String>? archivedUserIds,
    Set<String>? deletedForUserIds,
    Map<String, String>? chatBackgroundPresetsByUserId,
    Map<String, String>? friendshipStatusesByUserId,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isArchived,
    bool? isDeletedForCurrentUser,
    String? conversationType,
    String? pageId,
    String? pageName,
    String? pageUsername,
    String? pageAvatarUrl,
    String? pageOwnerUserId,
    Set<String>? pageTeamUserIds,
    String? supportRequesterUserId,
    String? supportStatus,
    String? pageMessagingMode,
    bool? isManagedByCurrentUser,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantIds: participantIds ?? this.participantIds,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCountsByUserId:
          unreadCountsByUserId ?? this.unreadCountsByUserId,
      pinnedUserIds: pinnedUserIds ?? this.pinnedUserIds,
      mutedUserIds: mutedUserIds ?? this.mutedUserIds,
      archivedUserIds: archivedUserIds ?? this.archivedUserIds,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
      chatBackgroundPresetsByUserId: chatBackgroundPresetsByUserId ?? this.chatBackgroundPresetsByUserId,
      friendshipStatusesByUserId: friendshipStatusesByUserId ?? this.friendshipStatusesByUserId,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      isDeletedForCurrentUser:
          isDeletedForCurrentUser ?? this.isDeletedForCurrentUser,
      conversationType: conversationType ?? this.conversationType,
      pageId: pageId ?? this.pageId,
      pageName: pageName ?? this.pageName,
      pageUsername: pageUsername ?? this.pageUsername,
      pageAvatarUrl: pageAvatarUrl ?? this.pageAvatarUrl,
      pageOwnerUserId: pageOwnerUserId ?? this.pageOwnerUserId,
      pageTeamUserIds: pageTeamUserIds ?? this.pageTeamUserIds,
      supportRequesterUserId:
          supportRequesterUserId ?? this.supportRequesterUserId,
      supportStatus: supportStatus ?? this.supportStatus,
      pageMessagingMode: pageMessagingMode ?? this.pageMessagingMode,
      isManagedByCurrentUser:
          isManagedByCurrentUser ?? this.isManagedByCurrentUser,
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return _cleanStringList(value.whereType<String>());
  }

  static Set<String> _readStringSet(dynamic value) {
    if (value is! List) return const <String>{};
    return _cleanStringSet(value.whereType<String>());
  }

  static Map<String, int> _readIntMap(dynamic value) {
    if (value is! Map) return const <String, int>{};

    final result = <String, int>{};

    for (final entry in value.entries) {
      final key = entry.key;
      final rawValue = entry.value;

      if (key is! String || key.trim().isEmpty) continue;

      if (rawValue is int) {
        result[key.trim()] = rawValue < 0 ? 0 : rawValue;
      } else if (rawValue is num) {
        final parsed = rawValue.toInt();
        result[key.trim()] = parsed < 0 ? 0 : parsed;
      }
    }

    return Map.unmodifiable(result);
  }

  static Map<String, String> _readStringMap(dynamic value) {
    if (value is! Map) return const <String, String>{};

    final result = <String, String>{};

    for (final entry in value.entries) {
      final key = entry.key;
      final rawValue = entry.value;

      if (key is! String || key.trim().isEmpty) continue;
      if (rawValue is! String || rawValue.trim().isEmpty) continue;

      result[key.trim()] = rawValue.trim();
    }

    return Map.unmodifiable(result);
  }

  static Map<String, String> _cleanStringMap(Map<String, String> values) {
    final cleaned = <String, String>{};

    for (final entry in values.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();

      if (key.isEmpty || value.isEmpty) continue;
      cleaned[key] = value;
    }

    return Map.unmodifiable(cleaned);
  }

  static DateTime _readDateTime(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    }
    return fallback ?? DateTime.now();
  }

  static List<String> _participantIdsFromParticipants(
    List<ChatParticipantModel> participants,
  ) {
    return _cleanStringList(
      participants.map((participant) => participant.userId),
    );
  }

  static List<String> _cleanStringList(Iterable<String> values) {
    final cleaned = values
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);

    cleaned.sort();
    return List.unmodifiable(cleaned);
  }

  static Set<String> _cleanStringSet(Iterable<String> values) {
    final cleaned = values
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();

    return Set.unmodifiable(cleaned);
  }

  static Map<String, int> _cleanIntMap(Map<String, int> values) {
    final cleaned = <String, int>{};

    for (final entry in values.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;

      cleaned[key] = entry.value < 0 ? 0 : entry.value;
    }

    return Map.unmodifiable(cleaned);
  }

  static int _stableStringSetHash(Set<String> values) {
    final sorted = values.toList(growable: false)..sort();
    return Object.hashAll(sorted);
  }

  static int _stableStringListHash(List<String> values) {
    final sorted = values.toList(growable: false)..sort();
    return Object.hashAll(sorted);
  }

  static int _stableStringMapHash(Map<String, String> values) {
    final entries = values.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    return Object.hashAll(
      entries.map((entry) => Object.hash(entry.key, entry.value)),
    );
  }

  static int _stableIntMapHash(Map<String, int> values) {
    final entries = values.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    return Object.hashAll(
      entries.map((entry) => Object.hash(entry.key, entry.value)),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatModel &&
        other.id == id &&
        listEquals(other.participants, participants) &&
        listEquals(other.participantIds, participantIds) &&
        other.lastMessagePreview == lastMessagePreview &&
        other.lastMessageSenderId == lastMessageSenderId &&
        other.lastMessageType == lastMessageType &&
        other.lastMessageAt == lastMessageAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        mapEquals(other.unreadCountsByUserId, unreadCountsByUserId) &&
        setEquals(other.pinnedUserIds, pinnedUserIds) &&
        setEquals(other.mutedUserIds, mutedUserIds) &&
        setEquals(other.archivedUserIds, archivedUserIds) &&
        setEquals(other.deletedForUserIds, deletedForUserIds) &&
        mapEquals(other.chatBackgroundPresetsByUserId, chatBackgroundPresetsByUserId) &&
        mapEquals(other.friendshipStatusesByUserId, friendshipStatusesByUserId) &&
        other.unreadCount == unreadCount &&
        other.isPinned == isPinned &&
        other.isMuted == isMuted &&
        other.isArchived == isArchived &&
        other.isDeletedForCurrentUser == isDeletedForCurrentUser;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      Object.hashAll(participants),
      _stableStringListHash(participantIds),
      lastMessagePreview,
      lastMessageSenderId,
      lastMessageType,
      lastMessageAt,
      createdAt,
      updatedAt,
      _stableIntMapHash(unreadCountsByUserId),
      _stableStringSetHash(pinnedUserIds),
      _stableStringSetHash(mutedUserIds),
      _stableStringSetHash(archivedUserIds),
      _stableStringSetHash(deletedForUserIds),
      _stableStringMapHash(chatBackgroundPresetsByUserId),
      _stableStringMapHash(friendshipStatusesByUserId),
      unreadCount,
      isPinned,
      isMuted,
      isArchived,
      isDeletedForCurrentUser,
    ]);
  }
}
