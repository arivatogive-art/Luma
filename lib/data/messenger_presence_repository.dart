// Pfad: lib/data/messenger_presence_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum MessengerActivityState {
  idle,
  typing,
  recordingAudio,
  uploadingMedia,
  sendingMessage;

  static MessengerActivityState fromName(String? value) {
    final cleanedValue = value?.trim();

    if (cleanedValue == null || cleanedValue.isEmpty) {
      return MessengerActivityState.idle;
    }

    for (final state in MessengerActivityState.values) {
      if (state.name == cleanedValue) {
        return state;
      }
    }

    return MessengerActivityState.idle;
  }
}

@immutable
class MessengerPresenceSnapshot {
  final String userId;
  final bool isOnline;
  final DateTime? lastActiveAt;
  final DateTime? updatedAt;

  const MessengerPresenceSnapshot({
    required this.userId,
    required this.isOnline,
    required this.lastActiveAt,
    required this.updatedAt,
  });

  factory MessengerPresenceSnapshot.offline(String userId) {
    return MessengerPresenceSnapshot(
      userId: userId.trim(),
      isOnline: false,
      lastActiveAt: null,
      updatedAt: null,
    );
  }

  factory MessengerPresenceSnapshot.fromMap({
    required String userId,
    required Map<String, dynamic> map,
  }) {
    return MessengerPresenceSnapshot(
      userId: userId.trim(),
      isOnline: _readBool(map['isOnline']),
      lastActiveAt: _readNullableDateTime(map['lastActiveAt']),
      updatedAt: _readNullableDateTime(map['updatedAt']),
    );
  }

  static bool _readBool(Object? value) {
    return value is bool && value;
  }

  static DateTime? _readNullableDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

@immutable
class MessengerConversationActivitySnapshot {
  final String conversationId;
  final String userId;
  final MessengerActivityState state;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  const MessengerConversationActivitySnapshot({
    required this.conversationId,
    required this.userId,
    required this.state,
    required this.updatedAt,
    required this.expiresAt,
  });

  bool get isActive {
    if (state == MessengerActivityState.idle) return false;

    final expiry = expiresAt;
    if (expiry == null) return true;

    return expiry.isAfter(DateTime.now());
  }

  bool get isTyping =>
      isActive && state == MessengerActivityState.typing;

  bool get isRecordingAudio =>
      isActive && state == MessengerActivityState.recordingAudio;

  bool get isUploadingMedia =>
      isActive && state == MessengerActivityState.uploadingMedia;

  bool get isSendingMessage =>
      isActive && state == MessengerActivityState.sendingMessage;

  factory MessengerConversationActivitySnapshot.idle({
    required String conversationId,
    required String userId,
  }) {
    return MessengerConversationActivitySnapshot(
      conversationId: conversationId.trim(),
      userId: userId.trim(),
      state: MessengerActivityState.idle,
      updatedAt: null,
      expiresAt: null,
    );
  }

  factory MessengerConversationActivitySnapshot.fromMap({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> map,
  }) {
    return MessengerConversationActivitySnapshot(
      conversationId: conversationId.trim(),
      userId: userId.trim(),
      state: MessengerActivityState.fromName(
        _readString(map['state']),
      ),
      updatedAt: _readNullableDateTime(map['updatedAt']),
      expiresAt: _readNullableDateTime(map['expiresAt']),
    );
  }

  static String _readString(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }

  static DateTime? _readNullableDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class MessengerPresenceRepository {
  static const String _presenceCollection = 'messenger_presence';
  static const String _conversationsCollection = 'conversations';
  static const String _activitySubcollection = 'activity';

  static const Duration _defaultActivityLifetime =
      Duration(seconds: 8);

  final FirebaseFirestore _firestore;

  MessengerPresenceRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _presenceRef {
    return _firestore.collection(_presenceCollection);
  }

  CollectionReference<Map<String, dynamic>> get _conversationsRef {
    return _firestore.collection(_conversationsCollection);
  }

  DocumentReference<Map<String, dynamic>> _activityRef({
    required String conversationId,
    required String userId,
  }) {
    return _conversationsRef
        .doc(conversationId)
        .collection(_activitySubcollection)
        .doc(userId);
  }

  Stream<MessengerPresenceSnapshot> watchUserPresence({
    required String userId,
  }) {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return Stream<MessengerPresenceSnapshot>.value(
        MessengerPresenceSnapshot.offline(''),
      );
    }

    return _presenceRef.doc(cleanedUserId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return MessengerPresenceSnapshot.offline(cleanedUserId);
      }

      return MessengerPresenceSnapshot.fromMap(
        userId: cleanedUserId,
        map: data,
      );
    });
  }

  Stream<MessengerConversationActivitySnapshot>
      watchConversationActivity({
    required String conversationId,
    required String userId,
  }) {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = userId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) {
      return Stream<MessengerConversationActivitySnapshot>.value(
        MessengerConversationActivitySnapshot.idle(
          conversationId: cleanedConversationId,
          userId: cleanedUserId,
        ),
      );
    }

    return _activityRef(
      conversationId: cleanedConversationId,
      userId: cleanedUserId,
    ).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return MessengerConversationActivitySnapshot.idle(
          conversationId: cleanedConversationId,
          userId: cleanedUserId,
        );
      }

      final activity =
          MessengerConversationActivitySnapshot.fromMap(
        conversationId: cleanedConversationId,
        userId: cleanedUserId,
        map: data,
      );

      if (!activity.isActive) {
        return MessengerConversationActivitySnapshot.idle(
          conversationId: cleanedConversationId,
          userId: cleanedUserId,
        );
      }

      return activity;
    });
  }

  Future<void> markOnline({
    required String userId,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    final now = DateTime.now();

    await _presenceRef.doc(cleanedUserId).set(
      <String, dynamic>{
        'userId': cleanedUserId,
        'isOnline': true,
        'lastActiveAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markOffline({
    required String userId,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    final now = DateTime.now();

    await _presenceRef.doc(cleanedUserId).set(
      <String, dynamic>{
        'userId': cleanedUserId,
        'isOnline': false,
        'lastActiveAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> touchLastActive({
    required String userId,
    bool keepOnline = true,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    final now = DateTime.now();

    await _presenceRef.doc(cleanedUserId).set(
      <String, dynamic>{
        'userId': cleanedUserId,
        if (keepOnline) 'isOnline': true,
        'lastActiveAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setConversationActivity({
    required String conversationId,
    required String userId,
    required MessengerActivityState state,
    Duration lifetime = _defaultActivityLifetime,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = userId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) {
      return;
    }

    if (state == MessengerActivityState.idle) {
      await clearConversationActivity(
        conversationId: cleanedConversationId,
        userId: cleanedUserId,
      );
      return;
    }

    final safeLifetime = lifetime <= Duration.zero
        ? _defaultActivityLifetime
        : lifetime;

    final now = DateTime.now();
    final expiresAt = now.add(safeLifetime);

    await _activityRef(
      conversationId: cleanedConversationId,
      userId: cleanedUserId,
    ).set(
      <String, dynamic>{
        'conversationId': cleanedConversationId,
        'userId': cleanedUserId,
        'state': state.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> clearConversationActivity({
    required String conversationId,
    required String userId,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = userId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) {
      return;
    }

    await _activityRef(
      conversationId: cleanedConversationId,
      userId: cleanedUserId,
    ).set(
      <String, dynamic>{
        'conversationId': cleanedConversationId,
        'userId': cleanedUserId,
        'state': MessengerActivityState.idle.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> clearAllConversationActivityForUser({
    required String userId,
    required Iterable<String> conversationIds,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    final cleanedConversationIds = conversationIds
        .map((conversationId) => conversationId.trim())
        .where((conversationId) => conversationId.isNotEmpty)
        .toSet();

    if (cleanedConversationIds.isEmpty) return;

    final batch = _firestore.batch();

    for (final conversationId in cleanedConversationIds) {
      batch.set(
        _activityRef(
          conversationId: conversationId,
          userId: cleanedUserId,
        ),
        <String, dynamic>{
          'conversationId': conversationId,
          'userId': cleanedUserId,
          'state': MessengerActivityState.idle.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}
