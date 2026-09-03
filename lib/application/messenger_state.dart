import 'package:flutter/foundation.dart';

import '../domain/models/chat_model.dart';
import '../domain/models/message_model.dart';

@immutable
class MessengerState {
  final List<ChatModel> chats;
  final Map<String, List<MessageModel>> messagesByChatId;
  final Set<String> typingChatIds;
  final Set<String> openChatIds;
  final Map<String, DateTime> lastActiveByUserId;

  final ChatModel? lastDeletedChat;
  final List<MessageModel>? lastDeletedMessages;
  final int? lastDeletedIndex;

  MessengerState({
    required List<ChatModel> chats,
    required Map<String, List<MessageModel>> messagesByChatId,
    required Set<String> typingChatIds,
    required Set<String> openChatIds,
    required Map<String, DateTime> lastActiveByUserId,
    this.lastDeletedChat,
    List<MessageModel>? lastDeletedMessages,
    this.lastDeletedIndex,
  })  : chats = List<ChatModel>.unmodifiable(chats),
        messagesByChatId = _copyMessagesByChatId(messagesByChatId),
        typingChatIds = Set<String>.unmodifiable(
          typingChatIds
              .map((chatId) => chatId.trim())
              .where((chatId) => chatId.isNotEmpty),
        ),
        openChatIds = Set<String>.unmodifiable(
          openChatIds
              .map((chatId) => chatId.trim())
              .where((chatId) => chatId.isNotEmpty),
        ),
        lastActiveByUserId = Map<String, DateTime>.unmodifiable(
          Map<String, DateTime>.fromEntries(
            lastActiveByUserId.entries.where(
              (entry) => entry.key.trim().isNotEmpty,
            ).map(
              (entry) => MapEntry<String, DateTime>(
                entry.key.trim(),
                entry.value,
              ),
            ),
          ),
        ),
        lastDeletedMessages = lastDeletedMessages == null
            ? null
            : List<MessageModel>.unmodifiable(lastDeletedMessages);

  factory MessengerState.initial({
    required List<ChatModel> chats,
    required Map<String, List<MessageModel>> messagesByChatId,
  }) {
    return MessengerState(
      chats: chats,
      messagesByChatId: messagesByChatId,
      typingChatIds: const <String>{},
      openChatIds: const <String>{},
      lastActiveByUserId: const <String, DateTime>{},
    );
  }

  bool get hasChats => chats.isNotEmpty;

  bool get hasOpenChats => openChatIds.isNotEmpty;

  bool get hasTypingChats => typingChatIds.isNotEmpty;

  bool get canRestoreDeletedChat {
    return lastDeletedChat != null &&
        lastDeletedMessages != null &&
        lastDeletedIndex != null;
  }

  MessengerState copyWith({
    List<ChatModel>? chats,
    Map<String, List<MessageModel>>? messagesByChatId,
    Set<String>? typingChatIds,
    Set<String>? openChatIds,
    Map<String, DateTime>? lastActiveByUserId,
    ChatModel? lastDeletedChat,
    List<MessageModel>? lastDeletedMessages,
    int? lastDeletedIndex,
    bool clearLastDeleted = false,
  }) {
    return MessengerState(
      chats: chats ?? this.chats,
      messagesByChatId: messagesByChatId ?? this.messagesByChatId,
      typingChatIds: typingChatIds ?? this.typingChatIds,
      openChatIds: openChatIds ?? this.openChatIds,
      lastActiveByUserId: lastActiveByUserId ?? this.lastActiveByUserId,
      lastDeletedChat:
          clearLastDeleted ? null : (lastDeletedChat ?? this.lastDeletedChat),
      lastDeletedMessages: clearLastDeleted
          ? null
          : (lastDeletedMessages ?? this.lastDeletedMessages),
      lastDeletedIndex:
          clearLastDeleted ? null : (lastDeletedIndex ?? this.lastDeletedIndex),
    );
  }

  static Map<String, List<MessageModel>> _copyMessagesByChatId(
    Map<String, List<MessageModel>> source,
  ) {
    final copied = <String, List<MessageModel>>{};

    for (final entry in source.entries) {
      final chatId = entry.key.trim();
      if (chatId.isEmpty) continue;

      final messages = List<MessageModel>.from(entry.value)
        ..sort((a, b) {
          final createdCompare = a.createdAt.compareTo(b.createdAt);
          if (createdCompare != 0) return createdCompare;
          return a.id.compareTo(b.id);
        });

      copied[chatId] = List<MessageModel>.unmodifiable(messages);
    }

    return Map<String, List<MessageModel>>.unmodifiable(copied);
  }

  static bool _messagesMapEquals(
    Map<String, List<MessageModel>> a,
    Map<String, List<MessageModel>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;

    for (final entry in a.entries) {
      final otherMessages = b[entry.key];
      if (otherMessages == null) return false;
      if (!listEquals(entry.value, otherMessages)) return false;
    }

    return true;
  }

  static int _messagesMapHash(
    Map<String, List<MessageModel>> value,
  ) {
    final entries = value.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    return Object.hashAll(
      entries.map(
        (entry) => Object.hash(
          entry.key,
          Object.hashAll(entry.value),
        ),
      ),
    );
  }

  static int _stringSetHash(Set<String> value) {
    final sorted = value.toList(growable: false)..sort();
    return Object.hashAll(sorted);
  }

  static int _dateMapHash(Map<String, DateTime> value) {
    final entries = value.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    return Object.hashAll(
      entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MessengerState &&
        listEquals(other.chats, chats) &&
        _messagesMapEquals(other.messagesByChatId, messagesByChatId) &&
        setEquals(other.typingChatIds, typingChatIds) &&
        setEquals(other.openChatIds, openChatIds) &&
        mapEquals(other.lastActiveByUserId, lastActiveByUserId) &&
        other.lastDeletedChat == lastDeletedChat &&
        listEquals(other.lastDeletedMessages, lastDeletedMessages) &&
        other.lastDeletedIndex == lastDeletedIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(chats),
      _messagesMapHash(messagesByChatId),
      _stringSetHash(typingChatIds),
      _stringSetHash(openChatIds),
      _dateMapHash(lastActiveByUserId),
      lastDeletedChat,
      lastDeletedMessages == null ? null : Object.hashAll(lastDeletedMessages!),
      lastDeletedIndex,
    );
  }
}
