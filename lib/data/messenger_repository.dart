// Pfad: lib/data/messenger_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/chat_model.dart';
import '../domain/models/message_model.dart';

class MessengerRepository {
  static const String _conversationsCollection = 'conversations';
  static const String _usersCollection = 'users';
  static const String _messagesSubcollection = 'messages';
  static const String _messageReportsCollection = 'message_reports';
  static const String _messengerBlocksCollection = 'messenger_blocks';

  final FirebaseFirestore _firestore;

  MessengerRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversationsRef {
    return _firestore.collection(_conversationsCollection);
  }

  CollectionReference<Map<String, dynamic>> get _usersRef {
    return _firestore.collection(_usersCollection);
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .collection(_messagesSubcollection);
  }

  Stream<List<ChatModel>> watchConversations({
    required String currentUserId,
    int limit = 50,
    bool includeEmptyConversations = false,
  }) {
    final cleanedUserId = currentUserId.trim();

    if (cleanedUserId.isEmpty) {
      return const Stream<List<ChatModel>>.empty();
    }

    final safeLimit = limit.clamp(1, 100).toInt();

    return _conversationsRef
        .where('participantIds', arrayContains: cleanedUserId)
        .orderBy('lastMessageAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .asyncMap((snapshot) async {
      final rawConversations = snapshot.docs
          .map((document) {
            return ChatModel.fromMap(
              id: document.id,
              map: document.data(),
              currentUserId: cleanedUserId,
            );
          })
          .toList(growable: false);

      final hydratedConversations = await Future.wait(
        rawConversations.map(
          (conversation) => _hydrateConversationParticipants(
            conversation: conversation,
            currentUserId: cleanedUserId,
          ),
        ),
      );

      final conversations = hydratedConversations.where((conversation) {
        if (includeEmptyConversations) return true;

        return _hasVisibleInboxActivity(conversation);
      }).toList(growable: false);

      conversations.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }

        return b.lastMessageAt.compareTo(a.lastMessageAt);
      });

      return conversations;
    });
  }

  Stream<List<MessageModel>> watchMessages({
    required String conversationId,
    required String currentUserId,
    int limit = 80,
  }) {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) {
      return const Stream<List<MessageModel>>.empty();
    }

    final safeLimit = limit.clamp(1, 150).toInt();

    return _messagesRef(cleanedConversationId)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((document) {
        return MessageModel.fromMap(
          id: document.id,
          chatId: cleanedConversationId,
          map: document.data(),
          currentUserId: cleanedUserId,
        );
      }).toList();

      messages.sort((a, b) {
        final createdCompare = a.createdAt.compareTo(b.createdAt);
        if (createdCompare != 0) return createdCompare;
        return a.id.compareTo(b.id);
      });

      return messages;
    });
  }

  Future<List<MessageModel>> loadMessagesBefore({
    required String conversationId,
    required String currentUserId,
    required DateTime before,
    int limit = 40,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedCurrentUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedCurrentUserId.isEmpty) {
      return const <MessageModel>[];
    }

    final safeLimit = limit.clamp(1, 100).toInt();

    final conversationSnapshot =
        await _conversationsRef.doc(cleanedConversationId).get();

    if (!conversationSnapshot.exists) {
      throw StateError('Die Unterhaltung existiert nicht mehr.');
    }

    final conversationData =
        conversationSnapshot.data() ?? <String, dynamic>{};

    final participantIds = _readStringList(
      conversationData['participantIds'],
    );

    if (!participantIds.contains(cleanedCurrentUserId)) {
      throw StateError(
        'Nutzer ist kein Teilnehmer dieser Unterhaltung.',
      );
    }

    final snapshot = await _messagesRef(cleanedConversationId)
        .orderBy('createdAt', descending: true)
        .startAfter(<Object>[
          Timestamp.fromDate(before),
        ])
        .limit(safeLimit)
        .get();

    final messages = snapshot.docs.map((document) {
      return MessageModel.fromMap(
        id: document.id,
        chatId: cleanedConversationId,
        map: document.data(),
        currentUserId: cleanedCurrentUserId,
      );
    }).toList(growable: false);

    messages.sort((a, b) {
      final createdCompare =
          a.createdAt.compareTo(b.createdAt);

      if (createdCompare != 0) {
        return createdCompare;
      }

      return a.id.compareTo(b.id);
    });

    return List<MessageModel>.unmodifiable(messages);
  }

  Future<int> countMessagesBefore({
    required String conversationId,
    required String currentUserId,
    required DateTime before,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedCurrentUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedCurrentUserId.isEmpty) {
      return 0;
    }

    final conversationSnapshot =
        await _conversationsRef.doc(cleanedConversationId).get();

    if (!conversationSnapshot.exists) {
      return 0;
    }

    final conversationData =
        conversationSnapshot.data() ?? <String, dynamic>{};

    final participantIds = _readStringList(
      conversationData['participantIds'],
    );

    if (!participantIds.contains(cleanedCurrentUserId)) {
      return 0;
    }

    final aggregateSnapshot =
        await _messagesRef(cleanedConversationId)
            .where(
              'createdAt',
              isLessThan: Timestamp.fromDate(before),
            )
            .count()
            .get();

    return aggregateSnapshot.count ?? 0;
  }

  Future<ChatModel> createOrGetDirectConversation({
    required String currentUserId,
    required ChatParticipantModel currentUserPreview,
    required ChatParticipantModel otherUserPreview,
  }) async {
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedOtherUserId = otherUserPreview.userId.trim();

    if (cleanedCurrentUserId.isEmpty || cleanedOtherUserId.isEmpty) {
      throw ArgumentError('Direktchat benötigt zwei gültige User-IDs.');
    }

    if (cleanedCurrentUserId == cleanedOtherUserId) {
      throw ArgumentError('Direktchat mit sich selbst ist nicht erlaubt.');
    }

    final resolvedPreviews = await Future.wait<ChatParticipantModel>([
      _loadParticipantProfile(
        userId: cleanedCurrentUserId,
        fallback: currentUserPreview.copyWith(
          userId: cleanedCurrentUserId,
        ),
      ),
      _loadParticipantProfile(
        userId: cleanedOtherUserId,
        fallback: otherUserPreview.copyWith(
          userId: cleanedOtherUserId,
        ),
      ),
    ]);

    final participantIds = <String>[
      cleanedCurrentUserId,
      cleanedOtherUserId,
    ]..sort();

    final conversationId = 'direct_${participantIds.join('_')}';
    final documentRef = _conversationsRef.doc(conversationId);

    final rawConversation = await _firestore.runTransaction<ChatModel>(
      (transaction) async {
        final document = await transaction.get(documentRef);

        if (document.exists) {
          return ChatModel.fromMap(
            id: document.id,
            map: document.data() ?? <String, dynamic>{},
            currentUserId: cleanedCurrentUserId,
          );
        }

        final now = DateTime.now();

        final conversation = ChatModel(
          id: conversationId,
          participants: resolvedPreviews,
          participantIds: participantIds,
          lastMessagePreview: 'Noch keine Nachrichten',
          lastMessageSenderId: '',
          lastMessageType: MessageType.text.name,
          lastMessageAt: now,
          createdAt: now,
          updatedAt: now,
          unreadCountsByUserId: <String, int>{
            cleanedCurrentUserId: 0,
            cleanedOtherUserId: 0,
          },
        );

        transaction.set(documentRef, conversation.toMap());

        return ChatModel.fromMap(
          id: conversationId,
          map: conversation.toMap(),
          currentUserId: cleanedCurrentUserId,
        );
      },
    );

    return _hydrateConversationParticipants(
      conversation: rawConversation,
      currentUserId: cleanedCurrentUserId,
    );
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String senderUserId,
    required List<String> participantIds,
    required String text,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedSenderUserId = senderUserId.trim();
    final cleanedText = text.trim();
    final cleanedParticipantIds = _cleanParticipantIds(participantIds);

    if (cleanedConversationId.isEmpty ||
        cleanedSenderUserId.isEmpty ||
        cleanedText.isEmpty ||
        cleanedParticipantIds.length < 2) {
      return;
    }

    if (!cleanedParticipantIds.contains(cleanedSenderUserId)) {
      return;
    }

    final now = DateTime.now();
    final conversationRef = _conversationsRef.doc(cleanedConversationId);
    final messageRef = _messagesRef(cleanedConversationId).doc();

    final message = MessageModel(
      id: messageRef.id,
      chatId: cleanedConversationId,
      senderUserId: cleanedSenderUserId,
      text: cleanedText,
      createdAt: now,
      isOwnMessage: true,
      deliveryStatus: MessageDeliveryStatus.sent,
      messageType: MessageType.text,
      deliveredToUserIds: <String>{cleanedSenderUserId},
      readByUserIds: <String>{cleanedSenderUserId},
    );

    var notificationParticipantIds = cleanedParticipantIds;

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);

      if (!conversationSnapshot.exists) {
        throw StateError('Die Unterhaltung existiert nicht mehr.');
      }

      final conversationData =
          conversationSnapshot.data() ?? <String, dynamic>{};

      final storedParticipantIds = _readStringList(
        conversationData['participantIds'],
      );

      final safeParticipantIds = storedParticipantIds.isNotEmpty
          ? storedParticipantIds
          : cleanedParticipantIds;

      notificationParticipantIds = safeParticipantIds;

      if (!safeParticipantIds.contains(cleanedSenderUserId)) {
        throw StateError('Sender ist kein Teilnehmer dieser Unterhaltung.');
      }

      transaction.set(messageRef, message.toMap());

      _setConversationAfterOutgoingMessage(
        transaction: transaction,
        conversationRef: conversationRef,
        conversationData: conversationData,
        senderUserId: cleanedSenderUserId,
        participantIds: safeParticipantIds,
        previewText: cleanedText,
        messageType: MessageType.text,
        timestamp: now,
      );
    });

    await _createDirectMessageNotificationsBestEffort(
      conversationId: cleanedConversationId,
      messageId: messageRef.id,
      senderUserId: cleanedSenderUserId,
      participantIds: notificationParticipantIds,
      previewText: cleanedText,
      messageType: MessageType.text,
      timestamp: now,
    );
  }

  Future<Map<String, String>> toggleMessageReaction({
    required String conversationId,
    required String messageId,
    required String currentUserId,
    required String emoji,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedMessageId = messageId.trim();
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedEmoji = emoji.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedMessageId.isEmpty ||
        cleanedCurrentUserId.isEmpty ||
        cleanedEmoji.isEmpty) {
      throw ArgumentError(
        'Nachrichtenreaktion benötigt gültige IDs und ein Emoji.',
      );
    }

    if (cleanedEmoji.length > 16) {
      throw ArgumentError('Die Reaktion ist ungültig.');
    }

    final conversationRef =
        _conversationsRef.doc(cleanedConversationId);
    final messageRef =
        _messagesRef(cleanedConversationId).doc(cleanedMessageId);

    return _firestore.runTransaction<Map<String, String>>(
      (transaction) async {
        final conversationSnapshot =
            await transaction.get(conversationRef);
        final messageSnapshot =
            await transaction.get(messageRef);

        if (!conversationSnapshot.exists) {
          throw StateError('Die Unterhaltung existiert nicht mehr.');
        }

        if (!messageSnapshot.exists) {
          throw StateError('Die Nachricht existiert nicht mehr.');
        }

        final conversationData =
            conversationSnapshot.data() ?? <String, dynamic>{};

        final participantIds = _readStringList(
          conversationData['participantIds'],
        );

        if (!participantIds.contains(cleanedCurrentUserId)) {
          throw StateError(
            'Nur Teilnehmer können auf Nachrichten reagieren.',
          );
        }

        final messageData =
            messageSnapshot.data() ?? <String, dynamic>{};

        final deletedAt = messageData['deletedAt'];

        if (deletedAt != null) {
          throw StateError(
            'Auf gelöschte Nachrichten kann nicht reagiert werden.',
          );
        }

        final rawReactions = messageData['reactions'];
        final reactions = <String, String>{};

        if (rawReactions is Map) {
          for (final entry in rawReactions.entries) {
            final userId = entry.key.toString().trim();
            final reaction = entry.value?.toString().trim() ?? '';

            if (userId.isEmpty || reaction.isEmpty) continue;

            reactions[userId] = reaction;
          }
        }

        final existingReaction = reactions[cleanedCurrentUserId];

        if (existingReaction == cleanedEmoji) {
          reactions.remove(cleanedCurrentUserId);
        } else {
          reactions[cleanedCurrentUserId] = cleanedEmoji;
        }

        final sortedEntries = reactions.entries.toList(growable: false)
          ..sort((a, b) => a.key.compareTo(b.key));

        final stableReactions = <String, String>{
          for (final entry in sortedEntries) entry.key: entry.value,
        };

        transaction.set(
          messageRef,
          <String, dynamic>{
            'reactions': stableReactions,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return Map<String, String>.unmodifiable(stableReactions);
      },
    );
  }

  Future<void> editTextMessage({
    required String conversationId,
    required String messageId,
    required String currentUserId,
    required String text,
    Duration editWindow = const Duration(minutes: 15),
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedMessageId = messageId.trim();
    final cleanedUserId = currentUserId.trim();
    final cleanedText = text.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedMessageId.isEmpty ||
        cleanedUserId.isEmpty ||
        cleanedText.isEmpty) {
      return;
    }

    final conversationRef = _conversationsRef.doc(cleanedConversationId);
    final messageRef = _messagesRef(cleanedConversationId).doc(cleanedMessageId);
    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);
      final messageSnapshot = await transaction.get(messageRef);

      if (!conversationSnapshot.exists || !messageSnapshot.exists) {
        throw StateError('Die Nachricht existiert nicht mehr.');
      }

      final conversationData =
          conversationSnapshot.data() ?? <String, dynamic>{};
      final messageData = messageSnapshot.data() ?? <String, dynamic>{};

      final participantIds = _readStringList(conversationData['participantIds']);
      if (participantIds.isNotEmpty && !participantIds.contains(cleanedUserId)) {
        throw StateError('Nutzer ist kein Teilnehmer dieser Unterhaltung.');
      }

      final senderUserId = _readString(messageData['senderUserId']);
      if (senderUserId != cleanedUserId) {
        throw StateError('Nur eigene Nachrichten können bearbeitet werden.');
      }

      final messageType = _readString(messageData['messageType'], fallback: 'text');
      if (messageType != MessageType.text.name) {
        throw StateError('Nur Textnachrichten können bearbeitet werden.');
      }

      final deletedAt = messageData['deletedAt'];
      if (deletedAt != null) {
        throw StateError('Gelöschte Nachrichten können nicht bearbeitet werden.');
      }

      final createdAt = _readDateTime(messageData['createdAt']);
      if (now.difference(createdAt) > editWindow) {
        throw StateError('Nachrichten können nur 15 Minuten lang bearbeitet werden.');
      }

      final existingText = _readString(messageData['text']);
      if (existingText == 'Diese Nachricht wurde gelöscht') {
        throw StateError('Gelöschte Nachrichten können nicht bearbeitet werden.');
      }
      if (existingText == cleanedText) return;

      transaction.set(
        messageRef,
        {
          'text': cleanedText,
          'isEdited': true,
          'editedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );

      final lastMessageSenderId = _readString(conversationData['lastMessageSenderId']);
      final lastMessageType = _readString(
        conversationData['lastMessageType'],
        fallback: MessageType.text.name,
      );
      final lastMessageAt = _readDateTime(
        conversationData['lastMessageAt'],
        fallback: createdAt,
      );

      final isLikelyLatestConversationMessage =
          lastMessageSenderId == cleanedUserId &&
          lastMessageType == MessageType.text.name &&
          lastMessageAt.difference(createdAt).abs() <= const Duration(seconds: 2);

      if (isLikelyLatestConversationMessage) {
        transaction.set(
          conversationRef,
          {
            'lastMessagePreview': cleanedText,
            'updatedAt': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      }
    });
  }


  Future<void> reportMessage({
    required String conversationId,
    required String messageId,
    required String reporterUserId,
    required String reason,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedMessageId = messageId.trim();
    final cleanedReporterUserId = reporterUserId.trim();
    final cleanedReason = reason.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedMessageId.isEmpty ||
        cleanedReporterUserId.isEmpty ||
        cleanedReason.isEmpty) {
      return;
    }

    final conversationRef = _conversationsRef.doc(cleanedConversationId);
    final messageRef = _messagesRef(cleanedConversationId).doc(cleanedMessageId);
    final reportRef = _firestore.collection(_messageReportsCollection).doc(
          _safeReportDocumentId(
            conversationId: cleanedConversationId,
            messageId: cleanedMessageId,
            reporterUserId: cleanedReporterUserId,
          ),
        );

    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);
      final messageSnapshot = await transaction.get(messageRef);

      if (!conversationSnapshot.exists || !messageSnapshot.exists) {
        throw StateError('Die gemeldete Nachricht existiert nicht mehr.');
      }

      final conversationData =
          conversationSnapshot.data() ?? <String, dynamic>{};
      final messageData = messageSnapshot.data() ?? <String, dynamic>{};

      final participantIds = _readStringList(conversationData['participantIds']);
      if (participantIds.isNotEmpty &&
          !participantIds.contains(cleanedReporterUserId)) {
        throw StateError('Nur Teilnehmer können Nachrichten melden.');
      }

      final reportedUserId = _readString(messageData['senderUserId']);
      if (reportedUserId.isEmpty) {
        throw StateError('Die gemeldete Nachricht hat keinen gültigen Absender.');
      }

      if (reportedUserId == cleanedReporterUserId) {
        throw StateError('Eigene Nachrichten können nicht gemeldet werden.');
      }

      final messageType = _readString(
        messageData['messageType'],
        fallback: MessageType.text.name,
      );
      final messagePreview = _reportPreviewFromMessageData(messageData);
      final messageCreatedAt = _readDateTime(messageData['createdAt']);

      final existingReportSnapshot = await transaction.get(reportRef);

      if (existingReportSnapshot.exists) {
        transaction.set(
          reportRef,
          {
            'reason': cleanedReason,
            'duplicateReportedAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
        return;
      }

      transaction.set(reportRef, {
        'conversationId': cleanedConversationId,
        'messageId': cleanedMessageId,
        'reporterUserId': cleanedReporterUserId,
        'reportedUserId': reportedUserId,
        'reason': cleanedReason,
        'messageType': messageType,
        'messagePreview': messagePreview,
        'messageCreatedAt': Timestamp.fromDate(messageCreatedAt),
        'reportedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'status': 'open',
        'source': 'messenger',
      });
    });
  }

  Future<void> reportConversation({
    required String conversationId,
    required String reporterUserId,
    required String reportedUserId,
    required String reason,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedReporterUserId = reporterUserId.trim();
    final cleanedReportedUserId = reportedUserId.trim();
    final cleanedReason = reason.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedReporterUserId.isEmpty ||
        cleanedReportedUserId.isEmpty ||
        cleanedReason.isEmpty) {
      return;
    }

    if (cleanedReporterUserId == cleanedReportedUserId) {
      throw ArgumentError('Eigene Unterhaltung kann nicht gemeldet werden.');
    }

    final conversationRef = _conversationsRef.doc(cleanedConversationId);
    final reportMessageId = 'conversation_report';
    final reportRef = _firestore.collection(_messageReportsCollection).doc(
          _safeReportDocumentId(
            conversationId: cleanedConversationId,
            messageId: reportMessageId,
            reporterUserId: cleanedReporterUserId,
          ),
        );

    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);

      if (!conversationSnapshot.exists) {
        throw StateError('Die gemeldete Unterhaltung existiert nicht mehr.');
      }

      final conversationData =
          conversationSnapshot.data() ?? <String, dynamic>{};

      final participantIds = _readStringList(conversationData['participantIds']);

      if (!participantIds.contains(cleanedReporterUserId) ||
          !participantIds.contains(cleanedReportedUserId)) {
        throw StateError('Nur Teilnehmer können eine Unterhaltung melden.');
      }

      final existingReportSnapshot = await transaction.get(reportRef);

      if (existingReportSnapshot.exists) {
        transaction.set(
          reportRef,
          {
            'reason': cleanedReason,
            'duplicateReportedAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
        return;
      }

      final title = _readString(
        conversationData['lastMessagePreview'],
        fallback: 'Unterhaltung gemeldet',
      );

      transaction.set(reportRef, {
        'conversationId': cleanedConversationId,
        'messageId': reportMessageId,
        'reporterUserId': cleanedReporterUserId,
        'reportedUserId': cleanedReportedUserId,
        'reason': cleanedReason,
        'messageType': MessageType.text.name,
        'messagePreview': title.isEmpty ? 'Unterhaltung gemeldet' : title,
        'messageCreatedAt': Timestamp.fromDate(now),
        'reportedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'status': 'open',
        'source': 'messenger',
      });
    });
  }


  Future<void> sendMediaMessage({
    required String conversationId,
    required String senderUserId,
    required List<String> participantIds,
    required MessageType messageType,
    required String mediaUrl,
    required String mediaStoragePath,
    String? thumbnailUrl,
    String? mimeType,
    int? fileSizeBytes,
    Duration? audioDuration,
    bool hasBlurEffect = false,
    Duration? photoViewTimer,
    String? uploadId,
    String? fileName,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedSenderUserId = senderUserId.trim();
    final cleanedMediaUrl = mediaUrl.trim();
    final cleanedMediaStoragePath = mediaStoragePath.trim();
    final cleanedThumbnailUrl = thumbnailUrl?.trim();
    final cleanedMimeType = mimeType?.trim();
    final cleanedUploadId = uploadId?.trim();
    final cleanedFileName = fileName?.trim();
    final cleanedParticipantIds = _cleanParticipantIds(participantIds);

    if (cleanedConversationId.isEmpty ||
        cleanedSenderUserId.isEmpty ||
        cleanedMediaUrl.isEmpty ||
        cleanedMediaStoragePath.isEmpty ||
        cleanedParticipantIds.length < 2) {
      return;
    }

    if (!cleanedParticipantIds.contains(cleanedSenderUserId)) {
      return;
    }

    if (messageType == MessageType.text) {
      throw ArgumentError('sendMediaMessage unterstützt keine Textnachrichten.');
    }

    if (messageType == MessageType.audio &&
        (audioDuration == null || audioDuration.inMilliseconds <= 0)) {
      throw ArgumentError('Audio-Nachrichten benötigen eine gültige Dauer.');
    }

    final now = DateTime.now();
    final conversationRef = _conversationsRef.doc(cleanedConversationId);
    final messageRef = _messagesRef(cleanedConversationId).doc();

    final message = MessageModel(
      id: messageRef.id,
      chatId: cleanedConversationId,
      senderUserId: cleanedSenderUserId,
      text: messageType == MessageType.file
          ? (cleanedFileName == null || cleanedFileName.isEmpty ? 'Datei' : cleanedFileName)
          : '',
      createdAt: now,
      isOwnMessage: true,
      deliveryStatus: MessageDeliveryStatus.sent,
      messageType: messageType,
      imageUrl: cleanedMediaUrl,
      thumbnailUrl: cleanedThumbnailUrl == null || cleanedThumbnailUrl.isEmpty
          ? null
          : cleanedThumbnailUrl,
      mediaStoragePath: cleanedMediaStoragePath,
      uploadId:
          cleanedUploadId == null || cleanedUploadId.isEmpty ? null : cleanedUploadId,
      mimeType:
          cleanedMimeType == null || cleanedMimeType.isEmpty ? null : cleanedMimeType,
      fileSizeBytes:
          fileSizeBytes == null || fileSizeBytes <= 0 ? null : fileSizeBytes,
      audioDuration: messageType == MessageType.audio ? audioDuration : null,
      hasBlurEffect: messageType == MessageType.image && hasBlurEffect,
      photoViewTimer: messageType == MessageType.image ? photoViewTimer : null,
      mediaTransferState: MediaTransferState.success,
      mediaUploadState: MediaUploadState.uploaded,
      deliveredToUserIds: <String>{cleanedSenderUserId},
      readByUserIds: <String>{cleanedSenderUserId},
    );

    var notificationParticipantIds = cleanedParticipantIds;
    final previewText = _previewTextForMediaMessage(message);

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);

      if (!conversationSnapshot.exists) {
        throw StateError('Die Unterhaltung existiert nicht mehr.');
      }

      final conversationData =
          conversationSnapshot.data() ?? <String, dynamic>{};

      final storedParticipantIds = _readStringList(
        conversationData['participantIds'],
      );

      final safeParticipantIds = storedParticipantIds.isNotEmpty
          ? storedParticipantIds
          : cleanedParticipantIds;

      notificationParticipantIds = safeParticipantIds;

      if (!safeParticipantIds.contains(cleanedSenderUserId)) {
        throw StateError('Sender ist kein Teilnehmer dieser Unterhaltung.');
      }

      transaction.set(messageRef, message.toMap());

      _setConversationAfterOutgoingMessage(
        transaction: transaction,
        conversationRef: conversationRef,
        conversationData: conversationData,
        senderUserId: cleanedSenderUserId,
        participantIds: safeParticipantIds,
        previewText: previewText,
        messageType: messageType,
        timestamp: now,
      );
    });

    await _createDirectMessageNotificationsBestEffort(
      conversationId: cleanedConversationId,
      messageId: messageRef.id,
      senderUserId: cleanedSenderUserId,
      participantIds: notificationParticipantIds,
      previewText: previewText,
      messageType: messageType,
      timestamp: now,
    );
  }

  Future<void> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) return;

    final conversationRef = _conversationsRef.doc(cleanedConversationId);

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);

      if (!conversationSnapshot.exists) return;

      final conversationData =
          conversationSnapshot.data() ?? <String, dynamic>{};

      final participantIds = _readStringList(conversationData['participantIds']);
      if (participantIds.isNotEmpty && !participantIds.contains(cleanedUserId)) {
        return;
      }

      final nextUnreadCounts = _readUnreadCounts(
        conversationData['unreadCountsByUserId'],
      );

      if ((nextUnreadCounts[cleanedUserId] ?? 0) == 0) return;

      nextUnreadCounts[cleanedUserId] = 0;

      transaction.set(
        conversationRef,
        {
          'unreadCountsByUserId': nextUnreadCounts,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> markMessagesAsRead({
    required String conversationId,
    required String currentUserId,
    required List<String> messageIds,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    final cleanedMessageIds = messageIds
        .map((messageId) => messageId.trim())
        .where((messageId) => messageId.isNotEmpty)
        .toSet()
        .take(80)
        .toList(growable: false);

    if (cleanedConversationId.isEmpty ||
        cleanedUserId.isEmpty ||
        cleanedMessageIds.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    var hasUpdates = false;

    for (final messageId in cleanedMessageIds) {
      batch.update(
        _messagesRef(cleanedConversationId).doc(messageId),
        {
          'deliveredToUserIds': FieldValue.arrayUnion(<String>[cleanedUserId]),
          'readByUserIds': FieldValue.arrayUnion(<String>[cleanedUserId]),
          'deliveryStatus': MessageDeliveryStatus.read.name,
        },
      );
      hasUpdates = true;
    }

    if (!hasUpdates) return;

    await batch.commit();
  }

  Future<void> markVisibleMessagesAsRead({
    required String conversationId,
    required String currentUserId,
    int limit = 80,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) return;

    final safeLimit = limit.clamp(1, 150).toInt();

    final snapshot = await _messagesRef(cleanedConversationId)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    var hasUpdates = false;

    for (final document in snapshot.docs) {
      final data = document.data();
      final senderUserId = _readString(data['senderUserId']);

      if (senderUserId.isEmpty || senderUserId == cleanedUserId) {
        continue;
      }

      final deliveredToUserIds = _readStringList(data['deliveredToUserIds']);
      final readByUserIds = _readStringList(data['readByUserIds']);

      final alreadyDelivered = deliveredToUserIds.contains(cleanedUserId);
      final alreadyRead = readByUserIds.contains(cleanedUserId);
      final currentDeliveryStatus = _readString(data['deliveryStatus']);

      if (alreadyDelivered &&
          alreadyRead &&
          currentDeliveryStatus == MessageDeliveryStatus.read.name) {
        continue;
      }

      batch.update(document.reference, {
        'deliveredToUserIds': FieldValue.arrayUnion(<String>[cleanedUserId]),
        'readByUserIds': FieldValue.arrayUnion(<String>[cleanedUserId]),
        'deliveryStatus': MessageDeliveryStatus.read.name,
      });

      hasUpdates = true;
    }

    if (!hasUpdates) return;

    await batch.commit();
  }


  Future<void> blockUserInConversation({
    required String conversationId,
    required String currentUserId,
    required String blockedUserId,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedBlockedUserId = blockedUserId.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedCurrentUserId.isEmpty ||
        cleanedBlockedUserId.isEmpty) {
      return;
    }

    if (cleanedCurrentUserId == cleanedBlockedUserId) {
      throw ArgumentError('Nutzer können sich nicht selbst blockieren.');
    }

    final conversationRef = _conversationsRef.doc(cleanedConversationId);
    final blockRef = _firestore.collection(_messengerBlocksCollection).doc(
          _safeBlockDocumentId(
            conversationId: cleanedConversationId,
            blockerUserId: cleanedCurrentUserId,
            blockedUserId: cleanedBlockedUserId,
          ),
        );

    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);

      if (!conversationSnapshot.exists) {
        throw StateError('Die Unterhaltung existiert nicht mehr.');
      }

      final conversationData =
          conversationSnapshot.data() ?? <String, dynamic>{};

      final participantIds = _readStringList(conversationData['participantIds']);
      if (!participantIds.contains(cleanedCurrentUserId) ||
          !participantIds.contains(cleanedBlockedUserId)) {
        throw StateError('Blockieren ist nur zwischen Teilnehmern möglich.');
      }

      transaction.set(
        blockRef,
        {
          'conversationId': cleanedConversationId,
          'blockerUserId': cleanedCurrentUserId,
          'blockedUserId': cleanedBlockedUserId,
          'participantIds': <String>[
            cleanedCurrentUserId,
            cleanedBlockedUserId,
          ]..sort(),
          'isActive': true,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> unblockUserInConversation({
    required String conversationId,
    required String currentUserId,
    required String blockedUserId,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedBlockedUserId = blockedUserId.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedCurrentUserId.isEmpty ||
        cleanedBlockedUserId.isEmpty) {
      return;
    }

    final blockRef = _firestore.collection(_messengerBlocksCollection).doc(
          _safeBlockDocumentId(
            conversationId: cleanedConversationId,
            blockerUserId: cleanedCurrentUserId,
            blockedUserId: cleanedBlockedUserId,
          ),
        );

    await blockRef.set(
      {
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<bool> isConversationBlockedForUser({
    required String conversationId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedOtherUserId = otherUserId.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedCurrentUserId.isEmpty ||
        cleanedOtherUserId.isEmpty) {
      return false;
    }

    final blocksCollection = _firestore.collection(_messengerBlocksCollection);

    final ownBlockSnapshot = await blocksCollection
        .doc(
          _safeBlockDocumentId(
            conversationId: cleanedConversationId,
            blockerUserId: cleanedCurrentUserId,
            blockedUserId: cleanedOtherUserId,
          ),
        )
        .get();

    if (_isActiveBlockDocument(ownBlockSnapshot.data())) {
      return true;
    }

    final incomingBlockSnapshot = await blocksCollection
        .doc(
          _safeBlockDocumentId(
            conversationId: cleanedConversationId,
            blockerUserId: cleanedOtherUserId,
            blockedUserId: cleanedCurrentUserId,
          ),
        )
        .get();

    return _isActiveBlockDocument(incomingBlockSnapshot.data());
  }

  Future<void> markConversationAsUnread({
    required String conversationId,
    required String currentUserId,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedCurrentUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty ||
        cleanedCurrentUserId.isEmpty) {
      return;
    }

    final conversationRef =
        _conversationsRef.doc(cleanedConversationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversationRef);

      if (!snapshot.exists) {
        throw StateError('Die Unterhaltung existiert nicht mehr.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};

      final participantIds = _readStringList(
        data['participantIds'],
      );

      if (!participantIds.contains(cleanedCurrentUserId)) {
        throw StateError(
          'Nutzer ist kein Teilnehmer dieser Unterhaltung.',
        );
      }

      final unreadCounts = <String, int>{};

      final rawUnreadCounts = data['unreadCountsByUserId'];

      if (rawUnreadCounts is Map) {
        for (final entry in rawUnreadCounts.entries) {
          final userId = entry.key.toString().trim();
          final value = entry.value;

          if (userId.isEmpty) continue;

          if (value is int) {
            unreadCounts[userId] = value < 0 ? 0 : value;
          } else if (value is num) {
            final normalized = value.toInt();
            unreadCounts[userId] =
                normalized < 0 ? 0 : normalized;
          }
        }
      }

      final currentUnreadCount =
          unreadCounts[cleanedCurrentUserId] ?? 0;

      unreadCounts[cleanedCurrentUserId] =
          currentUnreadCount > 0 ? currentUnreadCount : 1;

      transaction.set(
        conversationRef,
        <String, dynamic>{
          'unreadCountsByUserId': unreadCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> togglePinned({
    required String conversationId,
    required String currentUserId,
    required bool isPinned,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) return;

    await _conversationsRef.doc(cleanedConversationId).set(
      {
        'pinnedUserIds': isPinned
            ? FieldValue.arrayUnion(<String>[cleanedUserId])
            : FieldValue.arrayRemove(<String>[cleanedUserId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> toggleMuted({
    required String conversationId,
    required String currentUserId,
    required bool isMuted,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) return;

    await _conversationsRef.doc(cleanedConversationId).set(
      {
        'mutedUserIds': isMuted
            ? FieldValue.arrayUnion(<String>[cleanedUserId])
            : FieldValue.arrayRemove(<String>[cleanedUserId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }


  Future<void> toggleArchived({
    required String conversationId,
    required String currentUserId,
    required bool isArchived,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) return;

    await _conversationsRef.doc(cleanedConversationId).set(
      {
        'archivedUserIds': isArchived
            ? FieldValue.arrayUnion(<String>[cleanedUserId])
            : FieldValue.arrayRemove(<String>[cleanedUserId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }


  Future<void> setChatBackgroundPreset({
    required String conversationId,
    required String currentUserId,
    required MessengerChatBackgroundPreset preset,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) return;

    await _conversationsRef.doc(cleanedConversationId).set(
      {
        'chatBackgroundPresetsByUserId.$cleanedUserId': preset.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setFriendshipStatusForUser({
    required String conversationId,
    required String currentUserId,
    required MessengerFriendshipStatus status,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) return;

    await _conversationsRef.doc(cleanedConversationId).set(
      {
        'friendshipStatusesByUserId.$cleanedUserId': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setDeletedForCurrentUser({
    required String conversationId,
    required String currentUserId,
    required bool isDeleted,
  }) async {
    final cleanedConversationId = conversationId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedConversationId.isEmpty || cleanedUserId.isEmpty) return;

    await _conversationsRef.doc(cleanedConversationId).set(
      {
        'deletedForUserIds': isDeleted
            ? FieldValue.arrayUnion(<String>[cleanedUserId])
            : FieldValue.arrayRemove(<String>[cleanedUserId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  void _setConversationAfterOutgoingMessage({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> conversationRef,
    required Map<String, dynamic> conversationData,
    required String senderUserId,
    required List<String> participantIds,
    required String previewText,
    required MessageType messageType,
    required DateTime timestamp,
  }) {
    final currentUnreadCounts = _readUnreadCounts(
      conversationData['unreadCountsByUserId'],
    );

    final nextUnreadCounts = <String, int>{};

    for (final participantId in participantIds) {
      final currentCount = currentUnreadCounts[participantId] ?? 0;

      if (participantId == senderUserId) {
        nextUnreadCounts[participantId] = 0;
      } else {
        nextUnreadCounts[participantId] = currentCount + 1;
      }
    }

    transaction.set(
      conversationRef,
      {
        'participantIds': participantIds,
        'lastMessagePreview': previewText,
        'lastMessageSenderId': senderUserId,
        'lastMessageType': messageType.name,
        'lastMessageAt': Timestamp.fromDate(timestamp),
        'updatedAt': Timestamp.fromDate(timestamp),
        'unreadCountsByUserId': nextUnreadCounts,
        'archivedUserIds': FieldValue.arrayRemove(participantIds),
        'deletedForUserIds': FieldValue.arrayRemove(participantIds),
        'messageCount': FieldValue.increment(1),
        'hasMessages': true,
      },
      SetOptions(merge: true),
    );
  }

  Future<ChatModel> _hydrateConversationParticipants({
    required ChatModel conversation,
    required String currentUserId,
  }) async {
    final cleanedCurrentUserId = currentUserId.trim();

    final otherUserIds = conversation.participantIds
        .map((userId) => userId.trim())
        .where(
          (userId) =>
              userId.isNotEmpty && userId != cleanedCurrentUserId,
        )
        .toSet()
        .toList(growable: false);

    if (otherUserIds.isEmpty) {
      final storedOthers = conversation.participants
          .where(
            (participant) =>
                participant.userId.trim().isNotEmpty &&
                participant.userId.trim() != cleanedCurrentUserId,
          )
          .toList(growable: false);

      return storedOthers.isEmpty
          ? conversation.copyWith(
              participants: const <ChatParticipantModel>[],
            )
          : conversation.copyWith(participants: storedOthers);
    }

    final storedByUserId = <String, ChatParticipantModel>{
      for (final participant in conversation.participants)
        if (participant.userId.trim().isNotEmpty)
          participant.userId.trim(): participant,
    };

    final resolvedParticipants = await Future.wait(
      otherUserIds.map(
        (userId) => _loadParticipantProfile(
          userId: userId,
          fallback: storedByUserId[userId] ??
              ChatParticipantModel(
                userId: userId,
                displayName: 'Luma Nutzer',
                avatarUrl: '',
                isOnline: false,
              ),
        ),
      ),
    );

    return conversation.copyWith(
      participants: resolvedParticipants,
    );
  }

  Future<ChatParticipantModel> _loadParticipantProfile({
    required String userId,
    required ChatParticipantModel fallback,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return fallback;
    }

    try {
      final document = await _usersRef.doc(cleanedUserId).get();

      if (!document.exists) {
        return fallback.copyWith(userId: cleanedUserId);
      }

      final data = document.data() ?? <String, dynamic>{};

      final displayName = _firstNonEmptyString([
        data['displayName'],
        data['name'],
        data['fullName'],
        data['username'],
      ]);

      final avatarUrl = _firstNonEmptyString([
        data['avatarUrl'],
        data['profileImageUrl'],
        data['photoUrl'],
        data['photoURL'],
      ]);

      final isOnline = data['isOnline'] == true;

      return ChatParticipantModel(
        userId: cleanedUserId,
        displayName: displayName.isEmpty
            ? _safeParticipantFallbackName(fallback.displayName)
            : displayName,
        avatarUrl: avatarUrl.isEmpty ? fallback.avatarUrl.trim() : avatarUrl,
        isOnline: isOnline || fallback.isOnline,
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Messenger participant profile load failed '
        'for $cleanedUserId: ${error.code}',
      );

      return fallback.copyWith(userId: cleanedUserId);
    } catch (error) {
      debugPrint(
        'Messenger participant profile load failed '
        'for $cleanedUserId: $error',
      );

      return fallback.copyWith(userId: cleanedUserId);
    }
  }

  String _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is! String) continue;

      final cleanedValue = value.trim();
      if (cleanedValue.isNotEmpty) {
        return cleanedValue;
      }
    }

    return '';
  }

  String _safeParticipantFallbackName(String value) {
    final cleanedValue = value.trim();

    if (cleanedValue.isEmpty) return 'Luma Nutzer';

    final normalized = cleanedValue.toLowerCase();

    if (normalized == 'du' ||
        normalized == 'ich' ||
        normalized == 'me' ||
        normalized == 'you') {
      return 'Luma Nutzer';
    }

    return cleanedValue;
  }

  bool _hasVisibleInboxActivity(ChatModel conversation) {
    final lastMessageSenderId = conversation.lastMessageSenderId.trim();
    final lastMessagePreview = conversation.lastMessagePreview.trim();

    if (lastMessageSenderId.isNotEmpty) return true;
    if (conversation.hasUnreadMessages) return true;

    final hasAnyUnreadCount = conversation.unreadCountsByUserId.values.any(
      (count) => count > 0,
    );
    if (hasAnyUnreadCount) return true;

    if (lastMessagePreview.isEmpty) return false;
    if (lastMessagePreview == 'Noch keine Nachrichten') return false;

    return true;
  }



  bool _isActiveBlockDocument(Map<String, dynamic>? data) {
    if (data == null) return false;
    final value = data['isActive'];
    if (value is bool) return value;
    return false;
  }

  String _safeDocumentPart(String value) {
    final cleaned = value
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('#', '_')
        .replaceAll('?', '_')
        .trim();

    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  String _safeBlockDocumentId({
    required String conversationId,
    required String blockerUserId,
    required String blockedUserId,
  }) {
    return [
      conversationId,
      blockerUserId,
      blockedUserId,
    ].map(_safeDocumentPart).join('__');
  }

  String _safeReportDocumentId({
    required String conversationId,
    required String messageId,
    required String reporterUserId,
  }) {
    final raw = '${conversationId}_${messageId}_$reporterUserId';
    return raw
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('#', '_')
        .replaceAll('?', '_')
        .trim();
  }

  String _reportPreviewFromMessageData(Map<String, dynamic> messageData) {
    final messageType = _readString(
      messageData['messageType'],
      fallback: MessageType.text.name,
    );

    if (messageType == MessageType.image.name) return 'Foto';
    if (messageType == MessageType.audio.name) return 'Sprachnachricht';
    if (messageType == MessageType.file.name) {
      final text = _readString(messageData['text']);
      return text.isEmpty ? 'Datei' : text;
    }

    final text = _readString(messageData['text']);
    if (text.isEmpty) return 'Textnachricht';

    if (text.length <= 500) return text;
    return '${text.substring(0, 500)}…';
  }

  Future<void> _createDirectMessageNotificationsBestEffort({
    required String conversationId,
    required String messageId,
    required String senderUserId,
    required List<String> participantIds,
    required String previewText,
    required MessageType messageType,
    required DateTime timestamp,
  }) async {
    final recipients = participantIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty && userId != senderUserId)
        .toSet();

    if (recipients.isEmpty) return;

    final safePreview = previewText.trim().isEmpty
        ? _notificationPreviewForMessageType(messageType)
        : previewText.trim();

    for (final recipientUserId in recipients) {
      final notificationId = 'direct_${conversationId}_${messageId}_$recipientUserId'
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll('#', '_')
          .replaceAll('?', '_')
          .trim();

      try {
        await _firestore
            .collection('users')
            .doc(recipientUserId)
            .collection('notifications')
            .doc(notificationId)
            .set({
          'id': notificationId,
          'userId': recipientUserId,
          'type': 'directMessage',
          'priority': 'high',
          'targetType': 'chat',
          'referenceId': conversationId,
          'secondaryReferenceId': messageId,
          'title': 'Neue Nachricht',
          'body': safePreview.length <= 500
              ? safePreview
              : '${safePreview.substring(0, 500)}…',
          'createdAt': Timestamp.fromDate(timestamp),
          'updatedAt': Timestamp.fromDate(timestamp),
          'isRead': false,
        });
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Messenger notification create failed: $error');
          debugPrint('Messenger notification create stack: $stackTrace');
        }
      }
    }
  }

  String _notificationPreviewForMessageType(MessageType messageType) {
    switch (messageType) {
      case MessageType.image:
        return 'Foto';
      case MessageType.audio:
        return 'Sprachnachricht';
      case MessageType.file:
        return 'Datei';
      case MessageType.text:
        return 'Neue Nachricht';
    }
  }

  String _previewTextForMediaMessage(MessageModel message) {
    if (message.isImageMessage) {
      if (message.hasBlurEffect && message.hasPhotoViewTimer) {
        return 'Unscharfes Timer-Foto';
      }

      if (message.hasBlurEffect) return 'Unscharfes Foto';

      if (message.hasPhotoViewTimer) {
        return 'Timer-Foto';
      }

      return 'Foto';
    }

    if (message.isAudioMessage) {
      return 'Sprachnachricht';
    }

    if (message.isFileMessage) {
      final name = message.fileMessageName;
      return name == 'Datei' ? 'Datei' : 'Datei: $name';
    }

    return 'Nachricht';
  }

  List<String> _cleanParticipantIds(List<String> participantIds) {
    final cleaned = participantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    cleaned.sort();
    return cleaned;
  }

  Map<String, int> _readUnreadCounts(dynamic value) {
    if (value is! Map) return <String, int>{};

    final counts = <String, int>{};

    for (final entry in value.entries) {
      final key = entry.key;
      final rawValue = entry.value;

      if (key is! String || key.trim().isEmpty) continue;

      if (rawValue is int) {
        counts[key.trim()] = rawValue < 0 ? 0 : rawValue;
      } else if (rawValue is num) {
        final parsedValue = rawValue.toInt();
        counts[key.trim()] = parsedValue < 0 ? 0 : parsedValue;
      }
    }

    return counts;
  }

  String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  DateTime _readDateTime(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    }
    return fallback ?? DateTime.now();
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return <String>[];

    final cleaned = value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);

    cleaned.sort();
    return cleaned;
  }
}