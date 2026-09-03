// Pfad: lib/application/messenger_controller.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/messenger_presence_repository.dart';
import '../data/messenger_repository.dart';
import '../domain/models/chat_model.dart';
import '../domain/models/message_model.dart';
import 'messenger_media_pending_message_factory.dart';
import 'messenger_media_upload_service.dart';
import 'messenger_mock_data.dart';
import 'messenger_remote_mode.dart';
import 'messenger_storage_service.dart';
import 'messenger_state.dart';
import 'messenger_audio_playback_service.dart';

class _ReplyMessagePreview {
  final String messageId;
  final String text;
  final String senderUserId;
  final MessageType messageType;

  const _ReplyMessagePreview({
    required this.messageId,
    required this.text,
    required this.senderUserId,
    required this.messageType,
  });
}

class MessengerController extends ChangeNotifier
    with WidgetsBindingObserver {
  MessengerController._internal({
    MessengerRepository? repository,
    MessengerPresenceRepository? presenceRepository,
    MessengerMediaUploadService? mediaUploadService,
    MessengerStorageService? storageService,
    MessengerMediaPendingMessageFactory? pendingMessageFactory,
    MessengerAudioPlaybackService? audioPlaybackService,
    MessengerRemoteMode remoteMode = MessengerRemoteMode.remoteOnly,
  })  : _repository = repository ?? MessengerRepository(),
        _presenceRepository =
            presenceRepository ?? MessengerPresenceRepository(),
        _mediaUploadService =
            mediaUploadService ?? const MessengerMediaUploadService(),
        _storageService = storageService ?? MessengerStorageService(),
        _pendingMessageFactory =
            pendingMessageFactory ?? const MessengerMediaPendingMessageFactory(),
        _audioPlaybackService =
            audioPlaybackService ?? MessengerAudioPlaybackService(),
        _remoteMode = remoteMode {
    if (_remoteMode.isRemoteOnly) {
      _state = MessengerState.initial(
        chats: const <ChatModel>[],
        messagesByChatId: const <String, List<MessageModel>>{},
      );
    } else {
      final initialMessagesByChatId = {
        for (final entry in MessengerMockData.messagesByChatId.entries)
          entry.key: List<MessageModel>.from(entry.value),
      };

      _state = MessengerState.initial(
        chats: List<ChatModel>.from(MessengerMockData.chats),
        messagesByChatId: initialMessagesByChatId,
      );

      _initializePresenceState();
      _startPresenceSimulation();
    }

    WidgetsBinding.instance.addObserver(this);

    unawaited(_audioPlaybackService.initialize());
    _audioPlaybackSubscription =
        _audioPlaybackService.snapshots.listen(_handleAudioPlaybackSnapshot);
  }

  static final MessengerController instance = MessengerController._internal();

  late MessengerState _state;

  final MessengerRepository _repository;
  final MessengerPresenceRepository _presenceRepository;
  final MessengerMediaUploadService _mediaUploadService;
  final MessengerStorageService _storageService;
  final MessengerMediaPendingMessageFactory _pendingMessageFactory;
  final MessengerAudioPlaybackService _audioPlaybackService;

  StreamSubscription<MessengerAudioPlaybackSnapshot>? _audioPlaybackSubscription;

  MessengerRemoteMode _remoteMode;

  final Random _random = Random();
  final Map<String, Timer> _typingTimersByChatId = <String, Timer>{};
  final Map<String, Timer> _remoteActivityClearTimersByChatId =
      <String, Timer>{};
  final Map<String, DateTime> _lastReadSyncAtByChatId = <String, DateTime>{};
  final Set<String> _readSyncsInFlightByChatId = <String>{};
  final Set<String> _mediaUploadIdsInFlight = <String>{};
  final Map<String, bool> _blockStateByChatId = <String, bool>{};
  final Set<String> _blockStateLoadsInFlight = <String>{};

  static const Duration _readSyncDebounceDuration = Duration(seconds: 3);
  static const Duration _typingActivityLifetime = Duration(seconds: 8);
  static const Duration _recordingActivityLifetime = Duration(seconds: 12);
  static const Duration _uploadingActivityLifetime = Duration(seconds: 20);
  static const Duration _sendingActivityLifetime = Duration(seconds: 8);
  static const Duration _presenceHeartbeatInterval =
      Duration(seconds: 45);
  static const Duration messageEditWindow = Duration(minutes: 15);

  Timer? _presenceTimer;
  Timer? _remotePresenceHeartbeatTimer;
  StreamSubscription<List<ChatModel>>? _remoteConversationsSubscription;

  final Map<String, StreamSubscription<List<MessageModel>>>
      _remoteMessageSubscriptions =
      <String, StreamSubscription<List<MessageModel>>>{};

  final Set<String> _olderMessageLoadsInFlight =
      <String>{};

  final Set<String> _olderMessagesExhaustedChatIds =
      <String>{};

  final Map<String, StreamSubscription<MessengerPresenceSnapshot>>
      _remotePresenceSubscriptionsByUserId =
      <String, StreamSubscription<MessengerPresenceSnapshot>>{};

  final Map<String,
          StreamSubscription<MessengerConversationActivitySnapshot>>
      _remoteActivitySubscriptionsByChatId =
      <String,
          StreamSubscription<MessengerConversationActivitySnapshot>>{};

  final Map<String, MessengerActivityState>
      _remoteActivityStateByChatId =
      <String, MessengerActivityState>{};

  String? _remoteCurrentUserId;
  bool _isRemoteConversationSyncActive = false;
  int _remoteUserGeneration = 0;
  bool _isDisposed = false;

  MessengerState get state => _state;

  MessengerRemoteMode get remoteMode => _remoteMode;

  bool get isUsingRemote => _remoteMode.usesRemote;

  int get totalUnreadCount {
    return _state.chats.fold<int>(0, (total, chat) {
      final count = chat.unreadCount;
      return total + (count < 0 ? 0 : count);
    });
  }

  bool get hasUnreadMessages => totalUnreadCount > 0;

  bool isParticipantTypingInChat(String chatId) {
    return _state.typingChatIds.contains(chatId);
  }

  MessengerActivityState participantActivityForChat(String chatId) {
    return _remoteActivityStateByChatId[chatId.trim()] ??
        MessengerActivityState.idle;
  }

  bool isParticipantRecordingAudioInChat(String chatId) {
    return participantActivityForChat(chatId) ==
        MessengerActivityState.recordingAudio;
  }

  bool isParticipantUploadingMediaInChat(String chatId) {
    return participantActivityForChat(chatId) ==
        MessengerActivityState.uploadingMedia;
  }

  bool isParticipantSendingMessageInChat(String chatId) {
    return participantActivityForChat(chatId) ==
        MessengerActivityState.sendingMessage;
  }

  String? participantActivityLabelForChat(String chatId) {
    switch (participantActivityForChat(chatId)) {
      case MessengerActivityState.typing:
        return 'schreibt gerade ...';
      case MessengerActivityState.recordingAudio:
        return 'nimmt eine Sprachnachricht auf ...';
      case MessengerActivityState.uploadingMedia:
        return 'lädt eine Datei hoch ...';
      case MessengerActivityState.sendingMessage:
        return 'Nachricht wird gesendet ...';
      case MessengerActivityState.idle:
        return null;
    }
  }

  bool isChatBlocked(String chatId) {
    return _blockStateByChatId[chatId.trim()] ?? false;
  }

  Future<void> refreshBlockState(String chatId) async {
    final cleanedChatId = chatId.trim();
    if (cleanedChatId.isEmpty) return;
    if (_blockStateLoadsInFlight.contains(cleanedChatId)) return;

    final remoteUserId = _remoteCurrentUserId;
    final chat = chatById(cleanedChatId);
    final otherUserId = _otherUserIdForDirectChat(chat);

    if (!_remoteMode.usesRemote ||
        remoteUserId == null ||
        remoteUserId.isEmpty ||
        otherUserId == null ||
        otherUserId.isEmpty) {
      _blockStateByChatId[cleanedChatId] = false;
      notifyListeners();
      return;
    }

    _blockStateLoadsInFlight.add(cleanedChatId);

    try {
      final isBlocked = await _repository.isConversationBlockedForUser(
        conversationId: cleanedChatId,
        currentUserId: remoteUserId,
        otherUserId: otherUserId,
      );

      if (_isDisposed) return;

      if (_blockStateByChatId[cleanedChatId] != isBlocked) {
        _blockStateByChatId[cleanedChatId] = isBlocked;
        notifyListeners();
      } else {
        _blockStateByChatId[cleanedChatId] = isBlocked;
      }
    } catch (error) {
      debugPrint('Messenger refreshBlockState failed: $error');
    } finally {
      _blockStateLoadsInFlight.remove(cleanedChatId);
    }
  }

  Future<bool> blockUserInChat(String chatId) async {
    final cleanedChatId = chatId.trim();
    if (cleanedChatId.isEmpty) return false;

    final remoteUserId = _remoteCurrentUserId;
    final chat = chatById(cleanedChatId);
    final otherUserId = _otherUserIdForDirectChat(chat);

    if (!_remoteMode.usesRemote ||
        remoteUserId == null ||
        remoteUserId.isEmpty ||
        otherUserId == null ||
        otherUserId.isEmpty) {
      return false;
    }

    final previousValue = _blockStateByChatId[cleanedChatId] ?? false;
    _blockStateByChatId[cleanedChatId] = true;
    notifyListeners();

    try {
      await _repository.blockUserInConversation(
        conversationId: cleanedChatId,
        currentUserId: remoteUserId,
        blockedUserId: otherUserId,
      );
      return true;
    } catch (error) {
      debugPrint('Messenger blockUserInChat failed: $error');
      if (!_isDisposed) {
        _blockStateByChatId[cleanedChatId] = previousValue;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> unblockUserInChat(String chatId) async {
    final cleanedChatId = chatId.trim();
    if (cleanedChatId.isEmpty) return false;

    final remoteUserId = _remoteCurrentUserId;
    final chat = chatById(cleanedChatId);
    final otherUserId = _otherUserIdForDirectChat(chat);

    if (!_remoteMode.usesRemote ||
        remoteUserId == null ||
        remoteUserId.isEmpty ||
        otherUserId == null ||
        otherUserId.isEmpty) {
      return false;
    }

    final previousValue = _blockStateByChatId[cleanedChatId] ?? false;
    _blockStateByChatId[cleanedChatId] = false;
    notifyListeners();

    try {
      await _repository.unblockUserInConversation(
        conversationId: cleanedChatId,
        currentUserId: remoteUserId,
        blockedUserId: otherUserId,
      );
      await refreshBlockState(cleanedChatId);
      return true;
    } catch (error) {
      debugPrint('Messenger unblockUserInChat failed: $error');
      if (!_isDisposed) {
        _blockStateByChatId[cleanedChatId] = previousValue;
        notifyListeners();
      }
      return false;
    }
  }


  static const List<String> _autoReplyPool = [
    'Klingt gut.',
    'Alles klar, ich schaue es mir an.',
    'Das wirkt schon deutlich sauberer.',
    'Sehr gut, so ergibt der Verlauf mehr Sinn.',
    'Ja, das passt für die erste Version.',
    'Sieht stabil aus.',
    'Guter Schritt. Machen wir so weiter.',
    'Das fühlt sich jetzt deutlich realistischer an.',
  ];

  static const List<String> _mockImagePool = [
    'mock://messenger/image/city_walk_01',
    'mock://messenger/image/layout_preview_01',
    'mock://messenger/image/moodboard_01',
    'mock://messenger/image/camera_roll_01',
  ];

  static const List<Duration> _mockPhotoTimerPool = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
  ];

  static const List<Duration> _mockAudioDurations = [
    Duration(seconds: 7),
    Duration(seconds: 12),
    Duration(seconds: 18),
    Duration(seconds: 24),
  ];

  static const List<ChatParticipantModel> _suggestedContacts = [
    ChatParticipantModel(
      userId: 'user_emma',
      displayName: 'Emma Fischer',
      avatarUrl: '',
      isOnline: true,
    ),
    ChatParticipantModel(
      userId: 'user_leon',
      displayName: 'Leon Hoffmann',
      avatarUrl: '',
      isOnline: false,
    ),
    ChatParticipantModel(
      userId: 'user_hannah',
      displayName: 'Hannah Wolf',
      avatarUrl: '',
      isOnline: true,
    ),
    ChatParticipantModel(
      userId: 'user_jonas',
      displayName: 'Jonas Richter',
      avatarUrl: '',
      isOnline: false,
    ),
    ChatParticipantModel(
      userId: 'user_clara',
      displayName: 'Clara Neumann',
      avatarUrl: '',
      isOnline: true,
    ),
    ChatParticipantModel(
      userId: 'user_ben',
      displayName: 'Ben Lehmann',
      avatarUrl: '',
      isOnline: false,
    ),
  ];

  Future<void> configureRemoteMode({
    required MessengerRemoteMode mode,
    String? currentUserId,
  }) async {
    if (_isDisposed) return;

    final cleanedUserId = currentUserId?.trim();
    final nextUserId =
        cleanedUserId == null || cleanedUserId.isEmpty ? null : cleanedUserId;

    final nextUsesRemote = mode.usesRemote && nextUserId != null;
    final currentUsesRemote = _remoteMode.usesRemote &&
        _remoteCurrentUserId != null &&
        _remoteConversationsSubscription != null;

    final isSameConfiguration =
        _remoteMode == mode && _remoteCurrentUserId == nextUserId;

    if (isSameConfiguration) {
      if (nextUsesRemote && !currentUsesRemote) {
        _startRemoteConversationSync(nextUserId);
      }
      return;
    }

    final previousRemoteUserId = _remoteCurrentUserId;
    final userChanged = previousRemoteUserId != nextUserId;

    if (userChanged) {
      ++_remoteUserGeneration;

      if (previousRemoteUserId != null &&
          previousRemoteUserId.isNotEmpty) {
        unawaited(
          _presenceRepository.markOffline(
            userId: previousRemoteUserId,
          ),
        );
      }

      _clearUserScopedState();
    }

    _remoteMode = mode;
    _remoteCurrentUserId = nextUserId;

    _olderMessageLoadsInFlight.clear();
    _olderMessagesExhaustedChatIds.clear();

    await _stopRemoteConversationSync();
    await _stopAllRemoteMessageSyncs();
    await _stopAllRemotePresenceSyncs();

    if (_isDisposed) return;

    if (_remoteMode.isRemoteOnly) {
      _stopPresenceSimulation();
      _removeMockOnlyState();
    } else {
      _restoreMockOnlyStateIfNeeded();
      _initializePresenceState();
      _startPresenceSimulation();
    }

    if (nextUsesRemote) {
      _startRemoteConversationSync(nextUserId);
      unawaited(_presenceRepository.markOnline(userId: nextUserId));
      _startRemotePresenceHeartbeat(nextUserId);
    } else {
      _stopRemotePresenceHeartbeat();
    }

    notifyListeners();
  }

  Future<void> useMockOnly() async {
    await configureRemoteMode(mode: MessengerRemoteMode.mockOnly);
  }

  void _startRemoteConversationSync(String currentUserId) {
    if (_isDisposed) return;

    final generation = _remoteUserGeneration;

    unawaited(_remoteConversationsSubscription?.cancel());
    _remoteConversationsSubscription = null;
    _isRemoteConversationSyncActive = false;

    _remoteConversationsSubscription = _repository
        .watchConversations(currentUserId: currentUserId)
        .listen(
      (remoteChats) {
        if (_isDisposed ||
            generation != _remoteUserGeneration ||
            _remoteCurrentUserId != currentUserId) {
          return;
        }

        _handleRemoteConversations(remoteChats);
      },
      onError: (error) {
        debugPrint('Messenger watchConversations failed: $error');

        if (_isDisposed ||
            generation != _remoteUserGeneration ||
            _remoteCurrentUserId != currentUserId) {
          return;
        }

        _isRemoteConversationSyncActive = false;

        if (_remoteMode.isRemoteOnly) {
          _state = _state.copyWith(chats: const <ChatModel>[]);
          notifyListeners();
        }
      },
    );
  }

  Future<void> _stopRemoteConversationSync() async {
    final subscription = _remoteConversationsSubscription;
    _remoteConversationsSubscription = null;
    _isRemoteConversationSyncActive = false;

    if (subscription != null) {
      await subscription.cancel();
    }
  }

  Future<void> _stopAllRemoteMessageSyncs() async {
    final subscriptions =
        List<StreamSubscription<List<MessageModel>>>.from(
      _remoteMessageSubscriptions.values,
    );

    _remoteMessageSubscriptions.clear();

    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  void _handleRemoteConversations(List<ChatModel> remoteChats) {
    if (_isDisposed) return;

    if (remoteChats.isEmpty && _remoteMode.allowsMockFallback) {
      _isRemoteConversationSyncActive = false;
      notifyListeners();
      return;
    }

    final nextMessagesByChatId =
        Map<String, List<MessageModel>>.from(_state.messagesByChatId);

    if (_remoteMode.isRemoteOnly) {
      final remoteChatIds = remoteChats.map((chat) => chat.id).toSet();
      nextMessagesByChatId.removeWhere(
        (chatId, _) => !remoteChatIds.contains(chatId),
      );
    }

    for (final chat in remoteChats) {
      nextMessagesByChatId.putIfAbsent(chat.id, () => <MessageModel>[]);
    }

    _state = _state.copyWith(
      chats: remoteChats,
      messagesByChatId: nextMessagesByChatId,
    );

    _isRemoteConversationSyncActive = true;

    for (final chat in remoteChats) {
      _startRemoteMessageSync(chat.id);
    }

    _syncRemotePresenceForChats(remoteChats);

    notifyListeners();
  }

  List<ChatModel> get chats {
    final sorted = List<ChatModel>.from(_state.chats);
    sorted.sort(_compareChatsForInbox);
    return List.unmodifiable(sorted);
  }

  int _compareChatsForInbox(ChatModel a, ChatModel b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }

    final activityCompare =
        b.lastMessageAt.compareTo(a.lastMessageAt);

    if (activityCompare != 0) {
      return activityCompare;
    }

    final updatedCompare =
        b.updatedAt.compareTo(a.updatedAt);

    if (updatedCompare != 0) {
      return updatedCompare;
    }

    final unreadCompare =
        b.unreadCount.compareTo(a.unreadCount);

    if (unreadCompare != 0) {
      return unreadCompare;
    }

    return a.id.compareTo(b.id);
  }

  ChatModel? chatById(String chatId) {
    for (final chat in _state.chats) {
      if (chat.id == chatId) return chat;
    }
    return null;
  }

  ChatModel? directChatWithUser(String userId) {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return null;

    for (final chat in _state.chats) {
      final participantIds = chat.participantIds;
      final isDirectChat = participantIds.length == 2 || chat.participants.length == 1;

      if (!isDirectChat) continue;

      if (participantIds.contains(cleanedUserId)) return chat;

      for (final participant in chat.participants) {
        if (participant.userId == cleanedUserId) return chat;
      }
    }

    return null;
  }

  List<ChatParticipantModel> searchableContacts(String query) {
    final contactsByUserId = <String, ChatParticipantModel>{};

    for (final chat in _state.chats) {
      for (final participant in chat.participants) {
        if (participant.userId == MessengerMockData.currentUserId) continue;
        if (participant.userId == _remoteCurrentUserId) continue;
        contactsByUserId[participant.userId] = participant;
      }
    }

    if (!_remoteMode.isRemoteOnly) {
      for (final participant in _suggestedContacts) {
        contactsByUserId.putIfAbsent(participant.userId, () => participant);
      }
    }

    final contacts = contactsByUserId.values.toList()
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;

        return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
      });

    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return List.unmodifiable(contacts);

    final filtered = contacts.where((contact) {
      final name = contact.displayName.toLowerCase();
      final id = contact.userId.toLowerCase();
      return name.contains(trimmed) || id.contains(trimmed);
    }).toList();

    return List.unmodifiable(filtered);
  }

  Future<ChatModel> openOrCreateDirectChat(
    ChatParticipantModel participant, {
    ChatParticipantModel? currentUserPreview,
  }) async {
    final existing = directChatWithUser(participant.userId);

    if (existing != null) {
      return existing;
    }

    final remoteUserId = _remoteCurrentUserId;

    final canUseRemote =
        _remoteMode.usesRemote &&
        remoteUserId != null &&
        remoteUserId.isNotEmpty;

    if (canUseRemote) {
      final safeCurrentUserPreview = currentUserPreview ??
          ChatParticipantModel(
            userId: remoteUserId,
            displayName: 'Luma Nutzer',
            avatarUrl: '',
            isOnline: true,
          );

      final remoteChat = await _repository.createOrGetDirectConversation(
        currentUserId: remoteUserId,
        currentUserPreview: safeCurrentUserPreview.copyWith(
          userId: remoteUserId,
          isOnline: true,
        ),
        otherUserPreview: participant,
      );

      final updatedChats = List<ChatModel>.from(_state.chats);

      final existingIndex = updatedChats.indexWhere(
        (chat) => chat.id == remoteChat.id,
      );

      if (existingIndex >= 0) {
        updatedChats[existingIndex] = remoteChat;
      } else {
        updatedChats.add(remoteChat);
      }

      final updatedMessagesByChatId =
          Map<String, List<MessageModel>>.from(
        _state.messagesByChatId,
      );

      updatedMessagesByChatId.putIfAbsent(
        remoteChat.id,
        () => <MessageModel>[],
      );

      _state = _state.copyWith(
        chats: updatedChats,
        messagesByChatId: updatedMessagesByChatId,
      );

      notifyListeners();

      _startRemoteMessageSync(remoteChat.id);

      return remoteChat;
    }

    final now = DateTime.now();

    final chatId =
        'chat_${participant.userId}_${now.microsecondsSinceEpoch}';

    final newChat = ChatModel(
      id: chatId,
      participants: [participant],
      participantIds: <String>[
        MessengerMockData.currentUserId,
        participant.userId,
      ],
      lastMessagePreview: 'Noch keine Nachrichten',
      lastMessageAt: now,
      unreadCount: 0,
      isPinned: false,
      isMuted: false,
    );

    final updatedChats = List<ChatModel>.from(_state.chats)..add(newChat);

    final updatedMessagesByChatId =
        Map<String, List<MessageModel>>.from(
      _state.messagesByChatId,
    );

    updatedMessagesByChatId[chatId] = <MessageModel>[];

    final updatedLastActiveByUserId =
        Map<String, DateTime>.from(
      _state.lastActiveByUserId,
    );

    updatedLastActiveByUserId.putIfAbsent(
      participant.userId,
      () => DateTime.now().subtract(
        Duration(minutes: 1 + _random.nextInt(12)),
      ),
    );

    _state = _state.copyWith(
      chats: updatedChats,
      messagesByChatId: updatedMessagesByChatId,
      lastActiveByUserId: updatedLastActiveByUserId,
    );

    notifyListeners();

    return newChat;
  }

  List<MessageModel> messagesForChat(String chatId) {
    final messages = List<MessageModel>.from(
      _state.messagesByChatId[chatId] ?? const [],
    )..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return List.unmodifiable(messages);
  }

  bool isLoadingOlderMessages(String chatId) {
    return _olderMessageLoadsInFlight.contains(chatId.trim());
  }

  bool hasMoreOlderMessages(String chatId) {
    final cleanedChatId = chatId.trim();

    if (cleanedChatId.isEmpty) {
      return false;
    }

    return !_olderMessagesExhaustedChatIds.contains(
      cleanedChatId,
    );
  }

  Future<int> loadOlderMessages({
    required String chatId,
    int pageSize = 40,
  }) async {
    final cleanedChatId = chatId.trim();
    final currentUserId = _remoteCurrentUserId;

    if (cleanedChatId.isEmpty ||
        currentUserId == null ||
        currentUserId.trim().isEmpty ||
        !_remoteMode.usesRemote ||
        !_isRemoteConversationSyncActive) {
      return 0;
    }

    if (_olderMessageLoadsInFlight.contains(cleanedChatId) ||
        _olderMessagesExhaustedChatIds.contains(cleanedChatId)) {
      return 0;
    }

    final existingMessages = messagesForChat(cleanedChatId);

    if (existingMessages.isEmpty) {
      _olderMessagesExhaustedChatIds.add(cleanedChatId);
      return 0;
    }

    final safePageSize = pageSize.clamp(10, 100).toInt();
    final oldestMessage = existingMessages.first;

    _olderMessageLoadsInFlight.add(cleanedChatId);
    notifyListeners();

    try {
      final olderMessages =
          await _repository.loadMessagesBefore(
        conversationId: cleanedChatId,
        currentUserId: currentUserId,
        before: oldestMessage.createdAt,
        limit: safePageSize,
      );

      if (_isDisposed) {
        return 0;
      }

      if (olderMessages.isEmpty) {
        _olderMessagesExhaustedChatIds.add(
          cleanedChatId,
        );
        return 0;
      }

      final messagesById = <String, MessageModel>{
        for (final message in existingMessages)
          message.id: message,
      };

      for (final message in olderMessages) {
        messagesById.putIfAbsent(
          message.id,
          () => message,
        );
      }

      final mergedMessages =
          messagesById.values.toList(growable: false)
            ..sort((a, b) {
              final createdCompare =
                  a.createdAt.compareTo(b.createdAt);

              if (createdCompare != 0) {
                return createdCompare;
              }

              return a.id.compareTo(b.id);
            });

      _replaceMessagesForChat(
        chatId: cleanedChatId,
        messages: mergedMessages,
      );

      if (olderMessages.length < safePageSize) {
        _olderMessagesExhaustedChatIds.add(
          cleanedChatId,
        );
      }

      return olderMessages.length;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Messenger loadOlderMessages failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      return 0;
    } finally {
      _olderMessageLoadsInFlight.remove(cleanedChatId);

      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  MessageModel? latestMessageForChat(String chatId) {
    final messages = _state.messagesByChatId[chatId];
    if (messages == null || messages.isEmpty) return null;

    final sorted = List<MessageModel>.from(messages)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted.first;
  }

  String conversationPreviewText(ChatModel chat) {
    final activityLabel = participantActivityLabelForChat(chat.id);
    if (activityLabel != null) return activityLabel;

    final latestMessage = latestMessageForChat(chat.id);
    if (latestMessage == null) {
      final fallback = chat.lastMessagePreview.trim();
      return fallback.isEmpty ? 'Noch keine Nachrichten' : fallback;
    }

    final prefix = latestMessage.isOwnMessage ? 'Du: ' : '';

    if (latestMessage.isTextMessage) {
      final text = latestMessage.text.trim();
      if (text.isNotEmpty) return '$prefix$text';
      return prefix.isNotEmpty ? '${prefix}Nachricht' : 'Nachricht';
    }

    if (latestMessage.isImageMessage) {
      if (latestMessage.isUploadQueued) {
        return latestMessage.isOwnMessage
            ? 'Du bereitest ein Foto vor ...'
            : 'Foto wird vorbereitet ...';
      }

      if (latestMessage.isUploading) {
        return latestMessage.isOwnMessage
            ? 'Du lädst ein Foto hoch ...'
            : 'Foto wird geladen ...';
      }

      if (latestMessage.isUploadFailed || latestMessage.isMediaFailed) {
        return latestMessage.isOwnMessage
            ? 'Dein Foto konnte nicht gesendet werden'
            : 'Foto fehlgeschlagen';
      }

      return '$prefix${_imagePreviewLabel(latestMessage)}';
    }

    if (latestMessage.isAudioMessage) {
      if (latestMessage.isUploadQueued) {
        return latestMessage.isOwnMessage
            ? 'Du bereitest eine Sprachnachricht vor ...'
            : 'Sprachnachricht wird vorbereitet ...';
      }

      if (latestMessage.isUploading) {
        return latestMessage.isOwnMessage
            ? 'Du lädst eine Sprachnachricht hoch ...'
            : 'Sprachnachricht wird geladen ...';
      }

      if (latestMessage.isUploadFailed || latestMessage.isMediaFailed) {
        return latestMessage.isOwnMessage
            ? 'Deine Sprachnachricht konnte nicht gesendet werden'
            : 'Sprachnachricht fehlgeschlagen';
      }

      return '$prefix🎤 Sprachnachricht';
    }

    if (latestMessage.isFileMessage) {
      final fileName = latestMessage.fileMessageName.trim();

      if (latestMessage.isUploadQueued) {
        return latestMessage.isOwnMessage
            ? 'Du bereitest eine Datei vor ...'
            : 'Datei wird vorbereitet ...';
      }

      if (latestMessage.isUploading) {
        return latestMessage.isOwnMessage
            ? 'Du lädst eine Datei hoch ...'
            : 'Datei wird geladen ...';
      }

      if (latestMessage.isUploadFailed ||
          latestMessage.isMediaFailed) {
        return latestMessage.isOwnMessage
            ? 'Deine Datei konnte nicht gesendet werden'
            : 'Datei fehlgeschlagen';
      }

      return fileName.isEmpty
          ? '${prefix}📄 Dokument'
          : '${prefix}📄 $fileName';
    }

    return '${prefix}Nachricht';
  }

  List<ChatModel> filteredChats(String query) {
    final trimmed = query.trim().toLowerCase();
    final sortedChats = chats;

    if (trimmed.isEmpty) return sortedChats;

    final filtered = sortedChats.where((chat) {
      final title = chat.title.toLowerCase();
      final preview = conversationPreviewText(chat).toLowerCase();
      return title.contains(trimmed) || preview.contains(trimmed);
    }).toList();

    return List.unmodifiable(filtered);
  }

  String participantSubtitleForChat(String chatId) {
    final chat = chatById(chatId);
    if (chat == null || chat.participants.isEmpty) {
      return 'Zuletzt aktiv unbekannt';
    }

    final activityLabel = participantActivityLabelForChat(chatId);
    if (activityLabel != null) return activityLabel;

    final participant = chat.participants.first;

    if (participant.isOnline) return 'Online';

    final lastActive = _state.lastActiveByUserId[participant.userId];
    if (lastActive == null) return 'Zuletzt aktiv unbekannt';

    final difference = DateTime.now().difference(lastActive);

    if (difference.inMinutes < 1) return 'Gerade eben aktiv';
    if (difference.inMinutes < 60) {
      return 'Vor ${difference.inMinutes} Min. aktiv';
    }
    if (difference.inHours < 24) {
      return 'Vor ${difference.inHours} Std. aktiv';
    }

    return 'Vor ${difference.inDays} Tg. aktiv';
  }

  void openChat(String chatId) {
    final updatedOpenChatIds = Set<String>.from(_state.openChatIds)..add(chatId);

    _state = _state.copyWith(openChatIds: updatedOpenChatIds);

    markChatAsRead(chatId);

    final remoteUserId = _remoteCurrentUserId;

    if (_remoteMode.usesRemote &&
        remoteUserId != null &&
        _isRemoteConversationSyncActive) {
      _startRemoteMessageSync(chatId);
    }
  }

  void closeChat(String chatId) {
    final updatedOpenChatIds = Set<String>.from(_state.openChatIds)
      ..remove(chatId);

    if (!setEquals(updatedOpenChatIds, _state.openChatIds)) {
      _state = _state.copyWith(openChatIds: updatedOpenChatIds);
      notifyListeners();
    }

    unawaited(_stopRemoteMessageSync(chatId));
    unawaited(clearCurrentUserActivity(chatId));
  }

  Future<void> setCurrentUserTyping({
    required String chatId,
    required bool isTyping,
  }) async {
    if (isTyping) {
      await _setCurrentUserActivity(
        chatId: chatId,
        state: MessengerActivityState.typing,
        lifetime: _typingActivityLifetime,
      );
    } else {
      await clearCurrentUserActivity(chatId);
    }
  }

  Future<void> setCurrentUserRecordingAudio({
    required String chatId,
    required bool isRecording,
  }) async {
    if (isRecording) {
      await _setCurrentUserActivity(
        chatId: chatId,
        state: MessengerActivityState.recordingAudio,
        lifetime: _recordingActivityLifetime,
      );
    } else {
      await clearCurrentUserActivity(chatId);
    }
  }

  Future<void> setCurrentUserUploadingMedia({
    required String chatId,
    required bool isUploading,
  }) async {
    if (isUploading) {
      await _setCurrentUserActivity(
        chatId: chatId,
        state: MessengerActivityState.uploadingMedia,
        lifetime: _uploadingActivityLifetime,
      );
    } else {
      await clearCurrentUserActivity(chatId);
    }
  }

  Future<void> setCurrentUserSendingMessage({
    required String chatId,
    required bool isSending,
  }) async {
    if (isSending) {
      await _setCurrentUserActivity(
        chatId: chatId,
        state: MessengerActivityState.sendingMessage,
        lifetime: _sendingActivityLifetime,
      );
    } else {
      await clearCurrentUserActivity(chatId);
    }
  }

  Future<void> clearCurrentUserActivity(String chatId) async {
    final cleanedChatId = chatId.trim();
    final currentUserId = _remoteCurrentUserId;

    _remoteActivityClearTimersByChatId.remove(cleanedChatId)?.cancel();

    if (!_remoteMode.usesRemote ||
        currentUserId == null ||
        currentUserId.isEmpty ||
        cleanedChatId.isEmpty) {
      return;
    }

    try {
      await _presenceRepository.clearConversationActivity(
        conversationId: cleanedChatId,
        userId: currentUserId,
      );
    } catch (error) {
      debugPrint('Messenger clear activity failed: $error');
    }
  }

  Future<void> _setCurrentUserActivity({
    required String chatId,
    required MessengerActivityState state,
    required Duration lifetime,
  }) async {
    final cleanedChatId = chatId.trim();
    final currentUserId = _remoteCurrentUserId;

    if (!_remoteMode.usesRemote ||
        currentUserId == null ||
        currentUserId.isEmpty ||
        cleanedChatId.isEmpty) {
      return;
    }

    _remoteActivityClearTimersByChatId.remove(cleanedChatId)?.cancel();

    try {
      await _presenceRepository.setConversationActivity(
        conversationId: cleanedChatId,
        userId: currentUserId,
        state: state,
        lifetime: lifetime,
      );

      _remoteActivityClearTimersByChatId[cleanedChatId] =
          Timer(lifetime, () {
        _remoteActivityClearTimersByChatId.remove(cleanedChatId);
        unawaited(clearCurrentUserActivity(cleanedChatId));
      });
    } catch (error) {
      debugPrint('Messenger set activity failed: $error');
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
    MessageModel? replyToMessage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (isChatBlocked(chatId)) return;

    final replyPreview = _buildReplyPreview(replyToMessage);

    _setTypingForChat(chatId, isTyping: false);

    final chat = chatById(chatId);
    final remoteUserId = _remoteCurrentUserId;

    final localMessageId =
        'local_${DateTime.now().microsecondsSinceEpoch}';

    final optimisticMessage = MessageModel(
      id: localMessageId,
      chatId: chatId,
      senderUserId: remoteUserId ?? MessengerMockData.currentUserId,
      text: trimmed,
      createdAt: DateTime.now(),
      isOwnMessage: true,
      deliveryStatus: MessageDeliveryStatus.sending,
      messageType: MessageType.text,
      replyToMessageId: replyPreview?.messageId,
      replyToText: replyPreview?.text,
      replyToSenderUserId: replyPreview?.senderUserId,
      replyToMessageType: replyPreview?.messageType,
    );

    _appendMessage(chatId, optimisticMessage);

    _updateChatPreview(
      chatId: chatId,
      previewText: trimmed,
      timestamp: optimisticMessage.createdAt,
      unreadCount: 0,
    );

    notifyListeners();

    final canUseRemote =
        _remoteMode.usesRemote &&
        remoteUserId != null &&
        chat != null &&
        chat.participantIds.length >= 2;

    if (canUseRemote) {
      unawaited(
        setCurrentUserSendingMessage(
          chatId: chatId,
          isSending: true,
        ),
      );

      try {
        await _repository.sendTextMessage(
          conversationId: chatId,
          senderUserId: remoteUserId,
          participantIds: chat.participantIds,
          text: trimmed,
        );

        _updateMessageStatus(
          chatId: chatId,
          messageId: localMessageId,
          status: MessageDeliveryStatus.sent,
        );

        notifyListeners();

        return;
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Messenger sendTextMessage failed: $error');
          debugPrint('Messenger sendTextMessage stack: $stackTrace');
        }

        _updateMessageStatus(
          chatId: chatId,
          messageId: localMessageId,
          status: MessageDeliveryStatus.failed,
        );

        notifyListeners();
        return;
      }
    }

    if (_remoteMode.isRemoteOnly) {
      _updateMessageStatus(
        chatId: chatId,
        messageId: localMessageId,
        status: MessageDeliveryStatus.failed,
      );

      notifyListeners();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 550));

    if (_isDisposed) return;

    _updateMessageStatus(
      chatId: chatId,
      messageId: localMessageId,
      status: MessageDeliveryStatus.sent,
    );

    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (_isDisposed) return;

    _updateMessageStatus(
      chatId: chatId,
      messageId: localMessageId,
      status: MessageDeliveryStatus.delivered,
    );

    notifyListeners();

    if (!_remoteMode.usesRemote) {
      _scheduleAutoReply(chatId);
    }
  }

  Future<int> sendTextToChats({
    required Iterable<String> chatIds,
    required String text,
  }) async {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) return 0;

    final uniqueChatIds = chatIds
        .map((chatId) => chatId.trim())
        .where((chatId) => chatId.isNotEmpty)
        .toSet()
        .toList(growable: false);

    var queuedCount = 0;

    for (final chatId in uniqueChatIds) {
      if (chatById(chatId) == null) continue;
      if (isChatBlocked(chatId)) continue;

      await sendMessage(
        chatId: chatId,
        text: cleanedText,
      );

      queuedCount += 1;
    }

    return queuedCount;
  }

  Future<void> sendLocalImageMessage({
    required String chatId,
    required String localImagePath,
    String mimeType = 'image/jpeg',
    int? fileSizeBytes,
    bool hasBlurEffect = false,
    Duration? photoViewTimer,
  }) async {
    if (isChatBlocked(chatId)) return;

    _setTypingForChat(chatId, isTyping: false);

    final senderUserId = _remoteCurrentUserId ?? MessengerMockData.currentUserId;

    final preparedUpload = _mediaUploadService.prepareImageUpload(
      conversationId: chatId,
      senderUserId: senderUserId,
      localImagePath: localImagePath,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      hasBlurEffect: hasBlurEffect,
      photoViewTimer: photoViewTimer,
    );

    final pendingMessage = _pendingMessageFactory.createQueuedImageMessage(
      preparedUpload: preparedUpload,
    );

    _appendMessage(chatId, pendingMessage);

    _updateChatPreview(
      chatId: chatId,
      previewText: _outgoingImageLoadingLabel(pendingMessage),
      timestamp: pendingMessage.createdAt,
      unreadCount: 0,
    );

    notifyListeners();

    await _uploadPreparedMedia(
      chatId: chatId,
      messageId: pendingMessage.id,
    );
  }

  Future<void> sendMockImageMessage({
    required String chatId,
    bool hasBlurEffect = false,
    Duration? photoViewTimer,
    String? customImageUrl,
  }) async {
    if (_remoteMode.isRemoteOnly) return;

    final imageUrl =
        customImageUrl ?? _mockImagePool[_random.nextInt(_mockImagePool.length)];

    await sendLocalImageMessage(
      chatId: chatId,
      localImagePath: imageUrl,
      mimeType: 'image/jpeg',
      hasBlurEffect: hasBlurEffect,
      photoViewTimer: photoViewTimer,
    );
  }

  Future<void> sendMockBlurredImageMessage({
    required String chatId,
  }) async {
    if (_remoteMode.isRemoteOnly) return;

    await sendMockImageMessage(
      chatId: chatId,
      hasBlurEffect: true,
    );
  }

  Future<void> sendMockTimedImageMessage({
    required String chatId,
    Duration? timer,
  }) async {
    if (_remoteMode.isRemoteOnly) return;

    await sendMockImageMessage(
      chatId: chatId,
      photoViewTimer:
          timer ?? _mockPhotoTimerPool[_random.nextInt(_mockPhotoTimerPool.length)],
    );
  }

  Future<void> sendMockBlurredTimedImageMessage({
    required String chatId,
    Duration? timer,
  }) async {
    if (_remoteMode.isRemoteOnly) return;

    await sendMockImageMessage(
      chatId: chatId,
      hasBlurEffect: true,
      photoViewTimer:
          timer ?? _mockPhotoTimerPool[_random.nextInt(_mockPhotoTimerPool.length)],
    );
  }

  Future<void> sendLocalAudioMessage({
    required String chatId,
    required String localAudioPath,
    required Duration audioDuration,
    String mimeType = 'audio/mpeg',
    int? fileSizeBytes,
  }) async {
    if (isChatBlocked(chatId)) return;

    _setTypingForChat(chatId, isTyping: false);

    final senderUserId = _remoteCurrentUserId ?? MessengerMockData.currentUserId;

    final preparedUpload = _mediaUploadService.prepareAudioUpload(
      conversationId: chatId,
      senderUserId: senderUserId,
      localAudioPath: localAudioPath,
      audioDuration: audioDuration,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
    );

    final pendingMessage = _pendingMessageFactory.createQueuedAudioMessage(
      preparedUpload: preparedUpload,
    );

    _appendMessage(chatId, pendingMessage);

    _updateChatPreview(
      chatId: chatId,
      previewText: 'Sprachnachricht wird vorbereitet ...',
      timestamp: pendingMessage.createdAt,
      unreadCount: 0,
    );

    notifyListeners();

    await _uploadPreparedMedia(
      chatId: chatId,
      messageId: pendingMessage.id,
    );
  }

  Future<void> sendMockAudioMessage({
    required String chatId,
  }) async {
    if (_remoteMode.isRemoteOnly) return;

    final now = DateTime.now();
    final duration =
        _mockAudioDurations[_random.nextInt(_mockAudioDurations.length)];

    await sendLocalAudioMessage(
      chatId: chatId,
      localAudioPath: 'mock://messenger/audio/${now.microsecondsSinceEpoch}',
      audioDuration: duration,
      mimeType: 'audio/mpeg',
    );
  }


  Future<void> sendLocalFileMessage({
    required String chatId,
    required String localFilePath,
    required String fileName,
    String mimeType = 'application/octet-stream',
    int? fileSizeBytes,
  }) async {
    if (isChatBlocked(chatId)) return;

    final cleanedFileName = fileName.trim().isEmpty ? 'Datei' : fileName.trim();

    _setTypingForChat(chatId, isTyping: false);

    final senderUserId = _remoteCurrentUserId ?? MessengerMockData.currentUserId;

    final preparedUpload = _mediaUploadService.prepareFileUpload(
      conversationId: chatId,
      senderUserId: senderUserId,
      localFilePath: localFilePath,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
    );

    final pendingMessage = _pendingMessageFactory.createQueuedFileMessage(
      preparedUpload: preparedUpload,
      fileName: cleanedFileName,
    );

    _appendMessage(chatId, pendingMessage);

    _updateChatPreview(
      chatId: chatId,
      previewText: 'Datei wird vorbereitet: $cleanedFileName',
      timestamp: pendingMessage.createdAt,
      unreadCount: 0,
    );

    notifyListeners();

    await _uploadPreparedMedia(chatId: chatId, messageId: pendingMessage.id);
  }

  Future<void> retryMediaMessage({
    required String chatId,
    required String messageId,
  }) async {
    final message = _messageById(chatId: chatId, messageId: messageId);
    if (message == null) return;

    if (!(message.isImageMessage || message.isAudioMessage || message.isFileMessage)) return;

    if (!message.isUploadFailed && !message.isMediaFailed) return;

    _replaceMessage(
      chatId: chatId,
      messageId: messageId,
      replacement: message.copyWith(
        mediaTransferState: MediaTransferState.loading,
        mediaUploadState: MediaUploadState.queued,
        deliveryStatus: MessageDeliveryStatus.sending,
        clearUploadFailureReason: true,
      ),
    );

    _updateChatPreview(
      chatId: chatId,
      previewText: message.isImageMessage
          ? _outgoingImageRetryLabel(message)
          : message.isAudioMessage
              ? 'Sprachnachricht wird erneut gesendet ...'
              : 'Datei wird erneut gesendet ...',
      timestamp: message.createdAt,
      unreadCount: 0,
    );

    notifyListeners();

    await _uploadPreparedMedia(
      chatId: chatId,
      messageId: messageId,
    );
  }

  Future<void> toggleAudioPlayback({
    required String chatId,
    required String messageId,
  }) async {
    final message = _messageById(chatId: chatId, messageId: messageId);
    if (message == null) return;
    if (!message.isAudioMessage) return;
    if (!message.isMediaReady || message.hasPendingUpload) return;

    final source = _audioSourceForMessage(message);
    if (source == null || source.isEmpty) {
      _applyAudioPlaybackFailure(messageId: message.id);
      return;
    }

    await _audioPlaybackService.toggle(
      messageId: message.id,
      source: source,
      fallbackDuration: message.audioDuration ?? Duration.zero,
    );
  }

  String? _audioSourceForMessage(MessageModel message) {
    final remoteUrl = message.imageUrl?.trim();
    if (remoteUrl != null && remoteUrl.isNotEmpty) return remoteUrl;

    final localPath = message.localMediaPath?.trim();
    if (localPath != null && localPath.isNotEmpty) return localPath;

    return null;
  }

  void _handleAudioPlaybackSnapshot(MessengerAudioPlaybackSnapshot snapshot) {
    if (_isDisposed) return;

    if (snapshot.hasError && snapshot.messageId != null) {
      _applyAudioPlaybackFailure(messageId: snapshot.messageId!);
      return;
    }

    bool changed = false;

    final updatedMessagesByChatId =
        Map<String, List<MessageModel>>.from(_state.messagesByChatId);

    for (final entry in _state.messagesByChatId.entries) {
      final updatedMessages = entry.value.map((message) {
        if (!message.isAudioMessage) return message;

        final isActive = snapshot.messageId == message.id;
        final nextIsPlaying = isActive && snapshot.isPlaying;
        final nextProgress = isActive ? snapshot.progress : 0.0;

        if (message.isAudioPlaying == nextIsPlaying &&
            message.safeAudioProgress == nextProgress) {
          return message;
        }

        changed = true;

        return message.copyWith(
          isAudioPlaying: nextIsPlaying,
          audioProgress: nextProgress,
        );
      }).toList(growable: false);

      updatedMessagesByChatId[entry.key] = updatedMessages;
    }

    if (!changed) return;

    _state = _state.copyWith(messagesByChatId: updatedMessagesByChatId);
    notifyListeners();
  }

  void _applyAudioPlaybackFailure({
    required String messageId,
  }) {
    bool changed = false;

    final updatedMessagesByChatId =
        Map<String, List<MessageModel>>.from(_state.messagesByChatId);

    for (final entry in _state.messagesByChatId.entries) {
      final updatedMessages = entry.value.map((message) {
        if (!message.isAudioMessage) return message;

        if (message.id != messageId) {
          if (!message.isAudioPlaying && message.safeAudioProgress == 0.0) {
            return message;
          }

          changed = true;

          return message.copyWith(
            isAudioPlaying: false,
            audioProgress: 0.0,
          );
        }

        changed = true;

        return message.copyWith(
          isAudioPlaying: false,
          audioProgress: 0.0,
          mediaTransferState: MediaTransferState.failed,
          uploadFailureReason: 'Audio konnte nicht abgespielt werden.',
        );
      }).toList(growable: false);

      updatedMessagesByChatId[entry.key] = updatedMessages;
    }

    if (!changed) return;

    _state = _state.copyWith(messagesByChatId: updatedMessagesByChatId);
    notifyListeners();
  }

  Future<bool> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    final cleanedChatId = chatId.trim();
    final cleanedMessageId = messageId.trim();
    final normalizedEmoji = emoji.trim();

    if (cleanedChatId.isEmpty ||
        cleanedMessageId.isEmpty ||
        normalizedEmoji.isEmpty) {
      return false;
    }

    final existingMessages =
        _state.messagesByChatId[cleanedChatId];

    if (existingMessages == null || existingMessages.isEmpty) {
      return false;
    }

    final currentUserId =
        _remoteCurrentUserId ?? MessengerMockData.currentUserId;

    if (currentUserId.trim().isEmpty) {
      return false;
    }

    final existingMessage = _messageById(
      chatId: cleanedChatId,
      messageId: cleanedMessageId,
    );

    if (existingMessage == null || existingMessage.isDeleted) {
      return false;
    }

    final previousMessages =
        List<MessageModel>.from(existingMessages);

    bool changed = false;

    final optimisticMessages = existingMessages.map((message) {
      if (message.id != cleanedMessageId) {
        return message;
      }

      final updatedReactions =
          Map<String, String>.from(message.reactions);

      final existingReaction =
          updatedReactions[currentUserId];

      if (existingReaction == normalizedEmoji) {
        updatedReactions.remove(currentUserId);
      } else {
        updatedReactions[currentUserId] =
            normalizedEmoji;
      }

      changed = true;

      return message.copyWith(
        reactions: Map<String, String>.unmodifiable(
          updatedReactions,
        ),
      );
    }).toList(growable: false);

    if (!changed) {
      return false;
    }

    _replaceMessagesForChat(
      chatId: cleanedChatId,
      messages: optimisticMessages,
    );

    notifyListeners();

    final remoteUserId = _remoteCurrentUserId;

    final canUseRemote =
        _remoteMode.usesRemote &&
        remoteUserId != null &&
        remoteUserId.trim().isNotEmpty &&
        _isRemoteConversationSyncActive &&
        !cleanedMessageId.startsWith('local_') &&
        !cleanedMessageId.startsWith('local_media_') &&
        !cleanedMessageId.startsWith('image_') &&
        !cleanedMessageId.startsWith('audio_');

    if (!canUseRemote) {
      return !_remoteMode.isRemoteOnly;
    }

    try {
      final remoteReactions =
          await _repository.toggleMessageReaction(
        conversationId: cleanedChatId,
        messageId: cleanedMessageId,
        currentUserId: remoteUserId,
        emoji: normalizedEmoji,
      );

      if (_isDisposed) {
        return true;
      }

      final currentMessage = _messageById(
        chatId: cleanedChatId,
        messageId: cleanedMessageId,
      );

      if (currentMessage == null) {
        return true;
      }

      _replaceMessage(
        chatId: cleanedChatId,
        messageId: cleanedMessageId,
        replacement: currentMessage.copyWith(
          reactions: Map<String, String>.unmodifiable(
            remoteReactions,
          ),
        ),
      );

      notifyListeners();

      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Messenger toggleReaction failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      if (_isDisposed) {
        return false;
      }

      _replaceMessagesForChat(
        chatId: cleanedChatId,
        messages: previousMessages,
      );

      notifyListeners();

      return false;
    }
  }

  bool canEditMessage(MessageModel message) {
    if (!message.isOwnMessage) return false;
    if (!message.isTextMessage) return false;
    if (message.isDeleted) return false;
    final currentText = message.text.trim();
    if (currentText.isEmpty) return false;
    if (currentText == 'Diese Nachricht wurde gelöscht') return false;
    if (message.id.trim().isEmpty) return false;
    if (message.id.startsWith('local_media_') ||
        message.id.startsWith('image_') ||
        message.id.startsWith('audio_')) {
      return false;
    }

    final age = DateTime.now().difference(message.createdAt);
    return age <= messageEditWindow;
  }

  Future<bool> editMessage({
    required String chatId,
    required String messageId,
    required String text,
  }) async {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) return false;

    final existingMessage = _messageById(
      chatId: chatId,
      messageId: messageId,
    );

    if (existingMessage == null) return false;
    if (!canEditMessage(existingMessage)) return false;
    if (existingMessage.text.trim() == cleanedText) return false;

    final editedAt = DateTime.now();
    final editedMessage = existingMessage.copyWith(
      text: cleanedText,
      isEdited: true,
      editedAt: editedAt,
    );

    _replaceMessage(
      chatId: chatId,
      messageId: messageId,
      replacement: editedMessage,
    );
    _refreshChatAfterMessageChange(chatId);
    notifyListeners();

    final remoteUserId = _remoteCurrentUserId;
    final canUseRemote = _remoteMode.usesRemote &&
        remoteUserId != null &&
        _isRemoteConversationSyncActive &&
        !messageId.startsWith('local_');

    if (!canUseRemote) return true;

    try {
      await _repository.editTextMessage(
        conversationId: chatId,
        messageId: messageId,
        currentUserId: remoteUserId,
        text: cleanedText,
        editWindow: messageEditWindow,
      );
      return true;
    } catch (error) {
      debugPrint('Messenger editMessage failed: $error');

      if (_isDisposed) return false;

      _replaceMessage(
        chatId: chatId,
        messageId: messageId,
        replacement: existingMessage,
      );
      _refreshChatAfterMessageChange(chatId);
      notifyListeners();
      return false;
    }
  }


  Future<bool> reportMessage({
    required String chatId,
    required String messageId,
    required String reason,
  }) async {
    final cleanedReason = reason.trim();
    if (cleanedReason.isEmpty) return false;

    final message = _messageById(chatId: chatId, messageId: messageId);
    if (message == null) return false;
    if (message.isOwnMessage) return false;
    if (message.id.trim().isEmpty) return false;
    if (message.chatId.trim().isEmpty) return false;

    final remoteUserId = _remoteCurrentUserId;
    final canUseRemote = _remoteMode.usesRemote &&
        remoteUserId != null &&
        remoteUserId.trim().isNotEmpty &&
        _isRemoteConversationSyncActive &&
        !messageId.startsWith('local_');

    if (!canUseRemote) return false;

    try {
      await _repository.reportMessage(
        conversationId: chatId,
        messageId: messageId,
        reporterUserId: remoteUserId,
        reason: cleanedReason,
      );
      return true;
    } catch (error) {
      debugPrint('Messenger reportMessage failed: $error');
      return false;
    }
  }

  Future<bool> reportConversation({
    required String chatId,
    required String reason,
  }) async {
    final cleanedChatId = chatId.trim();
    final cleanedReason = reason.trim();

    if (cleanedChatId.isEmpty || cleanedReason.isEmpty) return false;

    final remoteUserId = _remoteCurrentUserId;
    final chat = chatById(cleanedChatId);
    final otherUserId = _otherUserIdForDirectChat(chat);

    final canUseRemote = _remoteMode.usesRemote &&
        remoteUserId != null &&
        remoteUserId.trim().isNotEmpty &&
        _isRemoteConversationSyncActive &&
        chat != null &&
        otherUserId != null &&
        otherUserId.trim().isNotEmpty;

    if (!canUseRemote) return false;

    try {
      await _repository.reportConversation(
        conversationId: cleanedChatId,
        reporterUserId: remoteUserId,
        reportedUserId: otherUserId,
        reason: cleanedReason,
      );
      return true;
    } catch (error) {
      debugPrint('Messenger reportConversation failed: $error');
      return false;
    }
  }


  bool deleteMessageForMe({
    required String chatId,
    required String messageId,
  }) {
    final existing = _state.messagesByChatId[chatId];
    if (existing == null) return false;

    final updated = existing.where((m) => m.id != messageId).toList();
    if (updated.length == existing.length) return false;

    _replaceMessagesForChat(chatId: chatId, messages: updated);
    _refreshChatAfterMessageChange(chatId);
    notifyListeners();
    return true;
  }

  bool deleteMessageForEveryone({
    required String chatId,
    required String messageId,
  }) {
    final existing = _state.messagesByChatId[chatId];
    if (existing == null) return false;

    bool changed = false;

    final updated = existing.map((m) {
      if (m.id != messageId) return m;
      if (!m.isOwnMessage) return m;

      changed = true;

      return m.copyWith(
        text: 'Diese Nachricht wurde gelöscht',
        messageType: MessageType.text,
        clearImageUrl: true,
        clearThumbnailUrl: true,
        clearMediaStoragePath: true,
        clearLocalMediaPath: true,
        clearUploadId: true,
        clearUploadFailureReason: true,
        clearMimeType: true,
        clearFileSizeBytes: true,
        clearAudioDuration: true,
        clearAudioProgress: true,
        isAudioPlaying: false,
        mediaTransferState: MediaTransferState.none,
        mediaUploadState: MediaUploadState.none,
        hasBlurEffect: false,
        clearPhotoViewTimer: true,
      );
    }).toList();

    if (!changed) return false;

    _replaceMessagesForChat(chatId: chatId, messages: updated);
    _refreshChatAfterMessageChange(chatId);
    notifyListeners();
    return true;
  }

  void markChatAsRead(String chatId) {
    final remoteUserId = _remoteCurrentUserId;
    final chat = chatById(chatId);
    final hadUnreadMessages = (chat?.unreadCount ?? 0) > 0;

    bool changed = false;

    final updatedChats = _state.chats.map((chat) {
      if (chat.id != chatId || chat.unreadCount == 0) return chat;

      changed = true;

      final nextUnreadCountsByUserId =
          Map<String, int>.from(chat.unreadCountsByUserId);

      if (remoteUserId != null && remoteUserId.isNotEmpty) {
        nextUnreadCountsByUserId[remoteUserId] = 0;
      }

      return chat.copyWith(
        unreadCount: 0,
        unreadCountsByUserId: nextUnreadCountsByUserId,
      );
    }).toList();

    if (changed) {
      _state = _state.copyWith(chats: updatedChats);
      notifyListeners();
    }

    if (_remoteMode.usesRemote &&
        remoteUserId != null &&
        _isRemoteConversationSyncActive) {
      unawaited(
        _syncReadStateIfNeeded(
          chatId: chatId,
          currentUserId: remoteUserId,
          forceConversationUnreadReset: hadUnreadMessages,
        ),
      );
    }
  }


  Future<bool> markChatAsUnread(String chatId) async {
    final cleanedChatId = chatId.trim();
    final remoteUserId = _remoteCurrentUserId;

    if (cleanedChatId.isEmpty) {
      return false;
    }

    ChatModel? previousChat;
    bool changed = false;

    final updatedChats = _state.chats.map((chat) {
      if (chat.id != cleanedChatId) {
        return chat;
      }

      previousChat = chat;

      final nextUnreadCountsByUserId =
          Map<String, int>.from(chat.unreadCountsByUserId);

      final effectiveUserId =
          remoteUserId ?? MessengerMockData.currentUserId;

      final existingCount =
          nextUnreadCountsByUserId[effectiveUserId] ??
              chat.unreadCount;

      final nextCount = existingCount > 0 ? existingCount : 1;

      nextUnreadCountsByUserId[effectiveUserId] = nextCount;
      changed = true;

      return chat.copyWith(
        unreadCount: nextCount,
        unreadCountsByUserId:
            Map<String, int>.unmodifiable(
          nextUnreadCountsByUserId,
        ),
      );
    }).toList(growable: false);

    if (!changed) {
      return false;
    }

    _state = _state.copyWith(chats: updatedChats);
    notifyListeners();

    final canUseRemote =
        _remoteMode.usesRemote &&
        remoteUserId != null &&
        remoteUserId.trim().isNotEmpty &&
        _isRemoteConversationSyncActive;

    if (!canUseRemote) {
      return !_remoteMode.isRemoteOnly;
    }

    try {
      await _repository.markConversationAsUnread(
        conversationId: cleanedChatId,
        currentUserId: remoteUserId,
      );

      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Messenger markChatAsUnread failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      if (_isDisposed || previousChat == null) {
        return false;
      }

      final revertedChats = _state.chats.map((chat) {
        if (chat.id != cleanedChatId) {
          return chat;
        }

        return previousChat!;
      }).toList(growable: false);

      _state = _state.copyWith(chats: revertedChats);
      notifyListeners();

      return false;
    }
  }

  MessengerChatBackgroundPreset chatBackgroundPresetForChat(String chatId) {
    final chat = chatById(chatId.trim());
    final currentUserId = _remoteCurrentUserId ?? MessengerMockData.currentUserId;

    if (chat == null || currentUserId.trim().isEmpty) {
      return MessengerChatBackgroundPreset.standard;
    }

    return chat.chatBackgroundPresetForUser(currentUserId);
  }

  Future<bool> setChatBackgroundPreset({
    required String chatId,
    required MessengerChatBackgroundPreset preset,
  }) async {
    final cleanedChatId = chatId.trim();
    if (cleanedChatId.isEmpty) return false;

    final currentUserId = _remoteCurrentUserId ?? MessengerMockData.currentUserId;
    if (currentUserId.trim().isEmpty) return false;

    bool changed = false;
    ChatModel? previousChat;

    final updatedChats = _state.chats.map((chat) {
      if (chat.id != cleanedChatId) return chat;

      previousChat = chat;
      final nextMap = Map<String, String>.from(chat.chatBackgroundPresetsByUserId);
      nextMap[currentUserId] = preset.name;
      changed = true;

      return chat.copyWith(
        chatBackgroundPresetsByUserId: Map.unmodifiable(nextMap),
      );
    }).toList(growable: false);

    if (!changed) return false;

    _state = _state.copyWith(chats: updatedChats);
    notifyListeners();

    if (_remoteMode.usesRemote &&
        _remoteCurrentUserId != null &&
        _isRemoteConversationSyncActive) {
      try {
        await _repository.setChatBackgroundPreset(
          conversationId: cleanedChatId,
          currentUserId: currentUserId,
          preset: preset,
        );
      } catch (error) {
        debugPrint('Messenger setChatBackgroundPreset failed: $error');
        if (!_isDisposed && previousChat != null) {
          final revertedChats = _state.chats.map((chat) {
            if (chat.id != cleanedChatId) return chat;
            return previousChat!;
          }).toList(growable: false);
          _state = _state.copyWith(chats: revertedChats);
          notifyListeners();
        }
        return false;
      }
    }

    return true;
  }

  MessengerFriendshipStatus friendshipStatusForChat(String chatId) {
    final chat = chatById(chatId.trim());
    final currentUserId = _remoteCurrentUserId ?? MessengerMockData.currentUserId;

    if (chat == null || currentUserId.trim().isEmpty) {
      return MessengerFriendshipStatus.unknown;
    }

    return chat.friendshipStatusForUser(currentUserId);
  }

  Future<bool> setFriendshipStatusForChat({
    required String chatId,
    required MessengerFriendshipStatus status,
  }) async {
    final cleanedChatId = chatId.trim();
    if (cleanedChatId.isEmpty) return false;

    final currentUserId = _remoteCurrentUserId ?? MessengerMockData.currentUserId;
    if (currentUserId.trim().isEmpty) return false;

    bool changed = false;
    ChatModel? previousChat;

    final updatedChats = _state.chats.map((chat) {
      if (chat.id != cleanedChatId) return chat;

      previousChat = chat;
      final nextMap = Map<String, String>.from(chat.friendshipStatusesByUserId);
      nextMap[currentUserId] = status.name;
      changed = true;

      return chat.copyWith(
        friendshipStatusesByUserId: Map.unmodifiable(nextMap),
      );
    }).toList(growable: false);

    if (!changed) return false;

    _state = _state.copyWith(chats: updatedChats);
    notifyListeners();

    if (_remoteMode.usesRemote &&
        _remoteCurrentUserId != null &&
        _isRemoteConversationSyncActive) {
      try {
        await _repository.setFriendshipStatusForUser(
          conversationId: cleanedChatId,
          currentUserId: currentUserId,
          status: status,
        );
      } catch (error) {
        debugPrint('Messenger setFriendshipStatusForChat failed: $error');
        if (!_isDisposed && previousChat != null) {
          final revertedChats = _state.chats.map((chat) {
            if (chat.id != cleanedChatId) return chat;
            return previousChat!;
          }).toList(growable: false);
          _state = _state.copyWith(chats: revertedChats);
          notifyListeners();
        }
        return false;
      }
    }

    return true;
  }

  bool togglePinned(String chatId) {
    bool? updatedValue;

    final updatedChats = _state.chats.map((chat) {
      if (chat.id != chatId) return chat;

      final nextValue = !chat.isPinned;
      updatedValue = nextValue;

      final updatedPinnedUserIds = Set<String>.from(chat.pinnedUserIds);
      final remoteUserId = _remoteCurrentUserId;

      if (remoteUserId != null) {
        if (nextValue) {
          updatedPinnedUserIds.add(remoteUserId);
        } else {
          updatedPinnedUserIds.remove(remoteUserId);
        }
      }

      return chat.copyWith(
        isPinned: nextValue,
        pinnedUserIds: updatedPinnedUserIds,
      );
    }).toList();

    if (updatedValue == null) return false;

    final remoteUserId = _remoteCurrentUserId;

    if (_remoteMode.usesRemote &&
        remoteUserId != null &&
        _isRemoteConversationSyncActive) {
      unawaited(
        _repository.togglePinned(
          conversationId: chatId,
          currentUserId: remoteUserId,
          isPinned: updatedValue!,
        ),
      );
    }

    _state = _state.copyWith(chats: updatedChats);
    notifyListeners();
    return updatedValue!;
  }

  bool toggleMuted(String chatId) {
    bool? updatedValue;

    final updatedChats = _state.chats.map((chat) {
      if (chat.id != chatId) return chat;

      final nextValue = !chat.isMuted;
      updatedValue = nextValue;

      final updatedMutedUserIds = Set<String>.from(chat.mutedUserIds);
      final remoteUserId = _remoteCurrentUserId;

      if (remoteUserId != null) {
        if (nextValue) {
          updatedMutedUserIds.add(remoteUserId);
        } else {
          updatedMutedUserIds.remove(remoteUserId);
        }
      }

      return chat.copyWith(
        isMuted: nextValue,
        mutedUserIds: updatedMutedUserIds,
      );
    }).toList();

    if (updatedValue == null) return false;

    final remoteUserId = _remoteCurrentUserId;

    if (_remoteMode.usesRemote &&
        remoteUserId != null &&
        _isRemoteConversationSyncActive) {
      unawaited(
        _repository.toggleMuted(
          conversationId: chatId,
          currentUserId: remoteUserId,
          isMuted: updatedValue!,
        ),
      );
    }

    _state = _state.copyWith(chats: updatedChats);
    notifyListeners();
    return updatedValue!;
  }


  bool toggleArchived(String chatId) {
    bool? updatedValue;

    final updatedChats = _state.chats.map((chat) {
      if (chat.id != chatId) return chat;

      final nextValue = !chat.isArchived;
      updatedValue = nextValue;

      final updatedArchivedUserIds = Set<String>.from(chat.archivedUserIds);
      final remoteUserId = _remoteCurrentUserId;

      if (remoteUserId != null) {
        if (nextValue) {
          updatedArchivedUserIds.add(remoteUserId);
        } else {
          updatedArchivedUserIds.remove(remoteUserId);
        }
      }

      return chat.copyWith(
        isArchived: nextValue,
        archivedUserIds: updatedArchivedUserIds,
      );
    }).toList();

    if (updatedValue == null) return false;

    final remoteUserId = _remoteCurrentUserId;

    if (_remoteMode.usesRemote &&
        remoteUserId != null &&
        _isRemoteConversationSyncActive) {
      unawaited(
        _repository.toggleArchived(
          conversationId: chatId,
          currentUserId: remoteUserId,
          isArchived: updatedValue!,
        ),
      );
    }

    _state = _state.copyWith(chats: updatedChats);
    notifyListeners();
    return updatedValue!;
  }

  bool deleteChat(String chatId) {
    final index = _state.chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1) return false;

    final deletedChat = _state.chats[index];
    final deletedMessages = List<MessageModel>.from(
      _state.messagesByChatId[chatId] ?? const [],
    );

    final remoteUserId = _remoteCurrentUserId;
    final updatedDeletedForUserIds =
        Set<String>.from(deletedChat.deletedForUserIds);

    if (remoteUserId != null && remoteUserId.isNotEmpty) {
      updatedDeletedForUserIds.add(remoteUserId);
    }

    final softDeletedChat = deletedChat.copyWith(
      deletedForUserIds: updatedDeletedForUserIds,
      isDeletedForCurrentUser: true,
      isArchived: false,
    );

    final updatedChats = List<ChatModel>.from(_state.chats)..removeAt(index);

    final updatedMessagesByChatId =
        Map<String, List<MessageModel>>.from(_state.messagesByChatId)
          ..remove(chatId);

    final updatedOpenChatIds = Set<String>.from(_state.openChatIds)
      ..remove(chatId);

    final updatedTypingChatIds = Set<String>.from(_state.typingChatIds)
      ..remove(chatId);

    _typingTimersByChatId.remove(chatId)?.cancel();

    _state = _state.copyWith(
      chats: updatedChats,
      messagesByChatId: updatedMessagesByChatId,
      openChatIds: updatedOpenChatIds,
      typingChatIds: updatedTypingChatIds,
      lastDeletedChat: softDeletedChat,
      lastDeletedMessages: deletedMessages,
      lastDeletedIndex: index,
    );

    if (_remoteMode.usesRemote &&
        remoteUserId != null &&
        remoteUserId.isNotEmpty &&
        _isRemoteConversationSyncActive) {
      unawaited(
        _repository.setDeletedForCurrentUser(
          conversationId: chatId,
          currentUserId: remoteUserId,
          isDeleted: true,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  bool restoreLastDeletedChat() {
    final deletedChat = _state.lastDeletedChat;
    final deletedMessages = _state.lastDeletedMessages;
    final deletedIndex = _state.lastDeletedIndex;

    if (deletedChat == null ||
        deletedMessages == null ||
        deletedIndex == null) {
      return false;
    }

    final remoteUserId = _remoteCurrentUserId;
    final restoredDeletedForUserIds =
        Set<String>.from(deletedChat.deletedForUserIds);

    if (remoteUserId != null && remoteUserId.isNotEmpty) {
      restoredDeletedForUserIds.remove(remoteUserId);
    }

    final restoredChat = deletedChat.copyWith(
      deletedForUserIds: restoredDeletedForUserIds,
      isDeletedForCurrentUser: false,
    );

    final updatedChats = List<ChatModel>.from(_state.chats);
    final safeIndex = deletedIndex < 0
        ? 0
        : (deletedIndex > updatedChats.length ? updatedChats.length : deletedIndex);

    updatedChats.insert(safeIndex, restoredChat);

    final updatedMessagesByChatId =
        Map<String, List<MessageModel>>.from(_state.messagesByChatId);
    updatedMessagesByChatId[restoredChat.id] =
        List<MessageModel>.from(deletedMessages);

    _state = _state.copyWith(
      chats: updatedChats,
      messagesByChatId: updatedMessagesByChatId,
      clearLastDeleted: true,
    );

    if (_remoteMode.usesRemote &&
        remoteUserId != null &&
        remoteUserId.isNotEmpty &&
        _isRemoteConversationSyncActive) {
      unawaited(
        _repository.setDeletedForCurrentUser(
          conversationId: restoredChat.id,
          currentUserId: remoteUserId,
          isDeleted: false,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  Future<void> simulateRefresh() async {
    if (_remoteMode.isRemoteOnly) return;

    await Future<void>.delayed(const Duration(milliseconds: 850));

    final updatedChats = List<ChatModel>.from(_state.chats)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.lastMessageAt.compareTo(a.lastMessageAt);
      });

    _state = _state.copyWith(chats: updatedChats);
    notifyListeners();
  }

  Future<void> _syncReadStateIfNeeded({
    required String chatId,
    required String currentUserId,
    bool forceConversationUnreadReset = false,
  }) async {
    if (_isDisposed) return;

    final cleanedChatId = chatId.trim();
    final cleanedUserId = currentUserId.trim();

    if (cleanedChatId.isEmpty || cleanedUserId.isEmpty) return;
    if (!_remoteMode.usesRemote || !_isRemoteConversationSyncActive) return;
    if (!_state.openChatIds.contains(cleanedChatId)) return;

    final shouldSyncVisibleMessages =
        _hasUnreadRemoteMessagesForUser(cleanedChatId, cleanedUserId);

    if (!forceConversationUnreadReset && !shouldSyncVisibleMessages) {
      return;
    }

    final now = DateTime.now();
    final lastSyncAt = _lastReadSyncAtByChatId[cleanedChatId];

    if (!forceConversationUnreadReset &&
        !shouldSyncVisibleMessages &&
        lastSyncAt != null &&
        now.difference(lastSyncAt) < _readSyncDebounceDuration) {
      return;
    }

    if (_readSyncsInFlightByChatId.contains(cleanedChatId)) {
      return;
    }

    _lastReadSyncAtByChatId[cleanedChatId] = now;
    _readSyncsInFlightByChatId.add(cleanedChatId);

    try {
      if (forceConversationUnreadReset) {
        await _repository.markConversationAsRead(
          conversationId: cleanedChatId,
          currentUserId: cleanedUserId,
        );
      }

      if (shouldSyncVisibleMessages) {
        await _repository.markVisibleMessagesAsRead(
          conversationId: cleanedChatId,
          currentUserId: cleanedUserId,
        );
      }
    } catch (error) {
      debugPrint('Messenger read sync failed: $error');
    } finally {
      _readSyncsInFlightByChatId.remove(cleanedChatId);
    }
  }

  bool _hasUnreadRemoteMessagesForUser(String chatId, String currentUserId) {
    final messages = _state.messagesByChatId[chatId];

    if (messages == null || messages.isEmpty) return false;

    for (final message in messages) {
      if (message.senderUserId == currentUserId) continue;
      if (message.id.startsWith('local_') ||
          message.id.startsWith('local_media_') ||
          message.id.startsWith('image_') ||
          message.id.startsWith('audio_')) {
        continue;
      }

      if (!message.readByUserIds.contains(currentUserId)) {
        return true;
      }
    }

    return false;
  }

  _ReplyMessagePreview? _buildReplyPreview(MessageModel? message) {
    if (message == null) return null;

    final messageId = message.id.trim();
    if (messageId.isEmpty) return null;

    final senderUserId = message.senderUserId.trim();
    if (senderUserId.isEmpty) return null;

    final text = _replyPreviewTextForMessage(message).trim();
    if (text.isEmpty) return null;

    return _ReplyMessagePreview(
      messageId: messageId,
      text: text,
      senderUserId: senderUserId,
      messageType: message.messageType,
    );
  }

  String _replyPreviewTextForMessage(MessageModel message) {
    if (message.isDeleted) return 'Gelöschte Nachricht';

    if (message.isTextMessage) {
      final text = message.text.trim();
      if (text.isNotEmpty) return text;
      return 'Nachricht';
    }

    if (message.isImageMessage) {
      return message.photoMessageSummaryLabel;
    }

    if (message.isAudioMessage) {
      return 'Sprachnachricht';
    }

    return 'Nachricht';
  }

  void _appendMessage(String chatId, MessageModel message) {
    final existingMessages = List<MessageModel>.from(
      _state.messagesByChatId[chatId] ?? const [],
    )..add(message);

    _replaceMessagesForChat(chatId: chatId, messages: existingMessages);
  }

  void _replaceMessagesForChat({
    required String chatId,
    required List<MessageModel> messages,
  }) {
    final updatedMessagesByChatId =
        Map<String, List<MessageModel>>.from(_state.messagesByChatId);

    updatedMessagesByChatId[chatId] = List<MessageModel>.from(messages);

    _state = _state.copyWith(messagesByChatId: updatedMessagesByChatId);
  }

  void _replaceMessage({
    required String chatId,
    required String messageId,
    required MessageModel replacement,
  }) {
    final existingMessages = _state.messagesByChatId[chatId];
    if (existingMessages == null || existingMessages.isEmpty) return;

    bool changed = false;

    final updatedMessages = existingMessages.map((message) {
      if (message.id != messageId) return message;
      changed = true;
      return replacement;
    }).toList();

    if (!changed) return;

    _replaceMessagesForChat(chatId: chatId, messages: updatedMessages);
  }

  void _startRemoteMessageSync(String chatId) {
    if (_isDisposed) return;
    if (_remoteMessageSubscriptions.containsKey(chatId)) return;

    final remoteUserId = _remoteCurrentUserId;
    if (remoteUserId == null) return;

    final subscription = _repository
        .watchMessages(
          conversationId: chatId,
          currentUserId: remoteUserId,
        )
        .listen(
      (remoteMessages) {
        if (_isDisposed) return;

        final existingMessages =
            _state.messagesByChatId[chatId] ?? const <MessageModel>[];

        final reconciledMessages = _reconcileMessages(
          existingMessages: existingMessages,
          remoteMessages: remoteMessages,
        );

        final updatedMessagesByChatId =
            Map<String, List<MessageModel>>.from(_state.messagesByChatId);

        updatedMessagesByChatId[chatId] = reconciledMessages;

        _state = _state.copyWith(
          messagesByChatId: updatedMessagesByChatId,
        );

        notifyListeners();

        if (_state.openChatIds.contains(chatId)) {
          unawaited(
            _syncReadStateIfNeeded(
              chatId: chatId,
              currentUserId: remoteUserId,
            ),
          );
        }
      },
      onError: (error) {
        debugPrint('Messenger watchMessages failed: $error');
      },
    );

    _remoteMessageSubscriptions[chatId] = subscription;
  }

  Future<void> _stopRemoteMessageSync(String chatId) async {
    final subscription = _remoteMessageSubscriptions.remove(chatId);

    if (subscription != null) {
      await subscription.cancel();
    }
  }

  List<MessageModel> _reconcileMessages({
    required List<MessageModel> existingMessages,
    required List<MessageModel> remoteMessages,
  }) {
    if (remoteMessages.isEmpty) {
      final pendingLocalMessages = existingMessages
          .where(_shouldPreserveLocalMessageDuringRemoteSync)
          .toList();

      pendingLocalMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return pendingLocalMessages;
    }

    final reconciled = <MessageModel>[
      ...remoteMessages,
    ];

    for (final localMessage in existingMessages) {
      if (!_shouldPreserveLocalMessageDuringRemoteSync(localMessage)) {
        continue;
      }

      final hasRemoteEquivalent = remoteMessages.any(
        (remoteMessage) => _messagesAreLikelyEquivalent(
          localMessage: localMessage,
          remoteMessage: remoteMessage,
        ),
      );

      if (!hasRemoteEquivalent) {
        reconciled.add(localMessage);
      }
    }

    reconciled.sort((a, b) {
      final createdCompare = a.createdAt.compareTo(b.createdAt);
      if (createdCompare != 0) return createdCompare;
      return a.id.compareTo(b.id);
    });

    final deduplicated = <String, MessageModel>{};

    for (final message in reconciled) {
      final uploadId = message.uploadId?.trim();

      if (uploadId != null && uploadId.isNotEmpty) {
        final existing = deduplicated[uploadId];

        if (existing == null) {
          deduplicated[uploadId] = message;
          continue;
        }

        deduplicated[uploadId] = _preferRemoteOrCompletedMediaMessage(
          existing,
          message,
        );
        continue;
      }

      deduplicated[message.id] = message;
    }

    return deduplicated.values.toList(growable: false)
      ..sort((a, b) {
        final createdCompare = a.createdAt.compareTo(b.createdAt);
        if (createdCompare != 0) return createdCompare;
        return a.id.compareTo(b.id);
      });
  }

  MessageModel _preferRemoteOrCompletedMediaMessage(
    MessageModel first,
    MessageModel second,
  ) {
    if (_isRemoteMessage(second) && !_isRemoteMessage(first)) return second;
    if (_isRemoteMessage(first) && !_isRemoteMessage(second)) return first;

    if (second.isUploadComplete && !first.isUploadComplete) return second;
    if (first.isUploadComplete && !second.isUploadComplete) return first;

    if (second.isMediaReady && !first.isMediaReady) return second;
    if (first.isMediaReady && !second.isMediaReady) return first;

    if (second.createdAt.isAfter(first.createdAt)) return second;
    return first;
  }

  bool _isRemoteMessage(MessageModel message) {
    return !(message.id.startsWith('local_') ||
        message.id.startsWith('local_media_') ||
        message.id.startsWith('image_') ||
        message.id.startsWith('audio_'));
  }

  bool _shouldPreserveLocalMessageDuringRemoteSync(MessageModel message) {
    final isLocalOnly = message.id.startsWith('local_') ||
        message.id.startsWith('local_media_') ||
        message.id.startsWith('image_') ||
        message.id.startsWith('audio_');

    if (!isLocalOnly) return false;

    if (message.hasPendingUpload || message.isUploadFailed) {
      return true;
    }

    if (message.deliveryStatus == MessageDeliveryStatus.sending ||
        message.deliveryStatus == MessageDeliveryStatus.failed) {
      return true;
    }

    if (message.isMediaLoading || message.isMediaFailed) {
      return true;
    }

    if ((message.isImageMessage || message.isAudioMessage) &&
        !message.isUploadComplete) {
      return true;
    }

    return false;
  }

  bool _messagesAreLikelyEquivalent({
    required MessageModel localMessage,
    required MessageModel remoteMessage,
  }) {
    if (localMessage.senderUserId != remoteMessage.senderUserId) return false;
    if (localMessage.messageType != remoteMessage.messageType) return false;

    final localUploadId = localMessage.uploadId?.trim();
    final remoteUploadId = remoteMessage.uploadId?.trim();

    if (localUploadId != null &&
        localUploadId.isNotEmpty &&
        remoteUploadId != null &&
        remoteUploadId.isNotEmpty) {
      return localUploadId == remoteUploadId;
    }

    final localStoragePath = localMessage.mediaStoragePath?.trim();
    final remoteStoragePath = remoteMessage.mediaStoragePath?.trim();

    if (localStoragePath != null &&
        localStoragePath.isNotEmpty &&
        remoteStoragePath != null &&
        remoteStoragePath.isNotEmpty) {
      return localStoragePath == remoteStoragePath;
    }

    final timeDifference = localMessage.createdAt
        .difference(remoteMessage.createdAt)
        .abs()
        .inSeconds;

    if (timeDifference > 20) return false;

    if (localMessage.isTextMessage && remoteMessage.isTextMessage) {
      return localMessage.text.trim() == remoteMessage.text.trim();
    }

    if (localMessage.isImageMessage && remoteMessage.isImageMessage) {
      final localImageUrl = localMessage.imageUrl?.trim();
      final remoteImageUrl = remoteMessage.imageUrl?.trim();

      if (localImageUrl != null &&
          localImageUrl.isNotEmpty &&
          remoteImageUrl != null &&
          remoteImageUrl.isNotEmpty) {
        return localImageUrl == remoteImageUrl;
      }

      return localMessage.uploadId == remoteMessage.uploadId;
    }

    if (localMessage.isAudioMessage && remoteMessage.isAudioMessage) {
      if (localMessage.uploadId != null && remoteMessage.uploadId != null) {
        return localMessage.uploadId == remoteMessage.uploadId;
      }

      return localMessage.audioDuration == remoteMessage.audioDuration;
    }

    if (localMessage.isFileMessage && remoteMessage.isFileMessage) {
      if (localMessage.uploadId != null && remoteMessage.uploadId != null) {
        return localMessage.uploadId == remoteMessage.uploadId;
      }
      return localMessage.fileMessageName == remoteMessage.fileMessageName;
    }

    return false;
  }

  Future<void> _uploadPreparedMedia({
    required String chatId,
    required String messageId,
  }) async {
    unawaited(
      setCurrentUserUploadingMedia(
        chatId: chatId,
        isUploading: true,
      ),
    );
    final message = _messageById(chatId: chatId, messageId: messageId);
    if (message == null) return;

    if (!(message.isImageMessage || message.isAudioMessage || message.isFileMessage)) return;

    final uploadId = message.uploadId?.trim();
    final uploadGuardKey =
        uploadId == null || uploadId.isEmpty ? messageId : uploadId;

    if (_mediaUploadIdsInFlight.contains(uploadGuardKey)) return;

    _mediaUploadIdsInFlight.add(uploadGuardKey);

    try {
      final uploadingMessage = message.isImageMessage
          ? _pendingMessageFactory.createUploadingImageMessage(message: message)
          : message.isAudioMessage
              ? _pendingMessageFactory.createUploadingAudioMessage(message: message)
              : _pendingMessageFactory.createUploadingFileMessage(message: message);

      _replaceMessage(
        chatId: chatId,
        messageId: messageId,
        replacement: uploadingMessage,
      );

      _updateChatPreview(
        chatId: chatId,
        previewText: message.isImageMessage
            ? _outgoingImageLoadingLabel(message)
            : message.isAudioMessage
                ? 'Sprachnachricht wird hochgeladen ...'
                : 'Datei wird hochgeladen ...',
        timestamp: message.createdAt,
        unreadCount: 0,
      );

      notifyListeners();

      final latestMessage = _messageById(chatId: chatId, messageId: messageId);
      if (latestMessage == null) return;

      if (!latestMessage.hasPendingUpload) return;

      final uploadResult = await _uploadMediaOrUseDevelopmentFallback(
        latestMessage,
      );

      if (_isDisposed) return;

      final refreshedMessage = _messageById(
        chatId: chatId,
        messageId: messageId,
      );

      if (refreshedMessage == null) return;

      final uploadedMessage = refreshedMessage.isImageMessage
          ? _pendingMessageFactory.createUploadedImageMessage(
              message: refreshedMessage,
              remoteImageUrl: uploadResult.downloadUrl,
              thumbnailUrl: uploadResult.thumbnailUrl,
            )
          : refreshedMessage.isAudioMessage
              ? _pendingMessageFactory.createUploadedAudioMessage(
                  message: refreshedMessage,
                  remoteAudioUrl: uploadResult.downloadUrl,
                )
              : _pendingMessageFactory.createUploadedFileMessage(
                  message: refreshedMessage,
                  remoteFileUrl: uploadResult.downloadUrl,
                );

      final completedMessage = uploadedMessage.copyWith(
        mediaStoragePath: uploadResult.storagePath,
        mimeType: uploadResult.mimeType,
        fileSizeBytes: uploadResult.fileSizeBytes,
      );

      _replaceMessage(
        chatId: chatId,
        messageId: messageId,
        replacement: completedMessage,
      );

      _updateChatPreview(
        chatId: chatId,
        previewText: completedMessage.isImageMessage
            ? _outgoingImageSuccessLabel(completedMessage)
            : completedMessage.isAudioMessage
                ? 'Sprachnachricht gesendet'
                : 'Datei gesendet: ${completedMessage.fileMessageName}',
        timestamp: completedMessage.createdAt,
        unreadCount: 0,
      );

      notifyListeners();

      final latestUploadedMessage = _messageById(
        chatId: chatId,
        messageId: messageId,
      );

      if (latestUploadedMessage != null) {
        await _sendUploadedMediaMessageToRemoteIfPossible(latestUploadedMessage);
      }
    } catch (error) {
      debugPrint('Messenger media upload failed: $error');

      if (_isDisposed) return;

      final latestMessage = _messageById(chatId: chatId, messageId: messageId);
      if (latestMessage == null) return;

      final failedMessage = latestMessage.isImageMessage
          ? _pendingMessageFactory.createFailedImageMessage(
              message: latestMessage,
              failureReason: 'Upload fehlgeschlagen.',
            )
          : latestMessage.isAudioMessage
              ? _pendingMessageFactory.createFailedAudioMessage(
                  message: latestMessage,
                  failureReason: 'Upload fehlgeschlagen.',
                )
              : _pendingMessageFactory.createFailedFileMessage(
                  message: latestMessage,
                  failureReason: 'Upload fehlgeschlagen.',
                );

      _replaceMessage(
        chatId: chatId,
        messageId: messageId,
        replacement: failedMessage,
      );

      _updateChatPreview(
        chatId: chatId,
        previewText: latestMessage.isImageMessage
            ? 'Foto fehlgeschlagen'
            : latestMessage.isAudioMessage
                ? 'Sprachnachricht fehlgeschlagen'
                : 'Datei fehlgeschlagen',
        timestamp: latestMessage.createdAt,
        unreadCount: 0,
      );

      notifyListeners();
    } finally {
      _mediaUploadIdsInFlight.remove(uploadGuardKey);
    }
  }

  Future<MessengerStorageUploadResult> _uploadMediaOrUseDevelopmentFallback(
    MessageModel message,
  ) async {
    final localPath = message.localMediaPath?.trim();

    if (_remoteMode.isRemoteOnly &&
        localPath != null &&
        localPath.startsWith('mock://')) {
      throw StateError('Mock-Medien sind im Remote-only Messenger deaktiviert.');
    }

    if (localPath != null && localPath.startsWith('mock://')) {
      await Future<void>.delayed(
        Duration(milliseconds: 500 + _random.nextInt(500)),
      );

      return MessengerStorageUploadResult(
        downloadUrl: _mockRemoteMediaUrlForMessage(message),
        storagePath: message.mediaStoragePath ?? 'mock_storage/${message.id}',
        mimeType: message.mimeType ?? _fallbackMimeTypeForMessage(message),
        fileSizeBytes: message.fileSizeBytes,
      );
    }

    final preparedUpload = _preparedUploadFromMessage(message);

    return _storageService.uploadPreparedMedia(
      preparedUpload: preparedUpload,
    );
  }

  MessengerPreparedMediaUpload _preparedUploadFromMessage(
    MessageModel message,
  ) {
    final uploadId = message.uploadId?.trim();
    final localMediaPath = message.localMediaPath?.trim();
    final storagePath = message.mediaStoragePath?.trim();
    final mimeType = message.mimeType?.trim();

    if (uploadId == null || uploadId.isEmpty) {
      throw StateError('Media Upload hat keine gültige Upload-ID.');
    }

    if (localMediaPath == null || localMediaPath.isEmpty) {
      throw StateError('Media Upload hat keinen lokalen Medienpfad.');
    }

    if (storagePath == null || storagePath.isEmpty) {
      throw StateError('Media Upload hat keinen Storage-Pfad.');
    }

    if (mimeType == null || mimeType.isEmpty) {
      throw StateError('Media Upload hat keinen MIME-Type.');
    }

    if (message.isAudioMessage &&
        (message.audioDuration == null ||
            message.audioDuration!.inMilliseconds <= 0)) {
      throw StateError('Audio Upload hat keine gültige Dauer.');
    }

    return MessengerPreparedMediaUpload(
      uploadId: uploadId,
      messageId: message.id,
      conversationId: message.chatId,
      senderUserId: message.senderUserId,
      localMediaPath: localMediaPath,
      storagePath: storagePath,
      messageType: message.messageType,
      mimeType: mimeType,
      fileSizeBytes: message.fileSizeBytes,
      audioDuration: message.audioDuration,
      hasBlurEffect: message.hasBlurEffect,
      photoViewTimer: message.photoViewTimer,
      createdAt: message.createdAt,
    );
  }

  String _fallbackMimeTypeForMessage(MessageModel message) {
    if (message.isImageMessage) return 'image/jpeg';
    if (message.isAudioMessage) return 'audio/mpeg';
    if (message.isFileMessage) return 'application/octet-stream';
    return 'application/octet-stream';
  }

  Future<void> _sendUploadedMediaMessageToRemoteIfPossible(
    MessageModel uploadedMessage,
  ) async {
    final remoteUserId = _remoteCurrentUserId;
    final chat = chatById(uploadedMessage.chatId);

    final canUseRemote =
        _remoteMode.usesRemote &&
        remoteUserId != null &&
        chat != null &&
        chat.participantIds.length >= 2;

    if (!canUseRemote) return;

    if (!uploadedMessage.isImageMessage &&
        !uploadedMessage.isAudioMessage &&
        !uploadedMessage.isFileMessage) {
      return;
    }

    final mediaUrl = uploadedMessage.imageUrl?.trim();
    final storagePath = uploadedMessage.mediaStoragePath?.trim();

    if (mediaUrl == null ||
        mediaUrl.isEmpty ||
        storagePath == null ||
        storagePath.isEmpty) {
      return;
    }

    try {
      await _repository.sendMediaMessage(
        conversationId: uploadedMessage.chatId,
        senderUserId: remoteUserId,
        participantIds: chat.participantIds,
        messageType: uploadedMessage.messageType,
        mediaUrl: mediaUrl,
        mediaStoragePath: storagePath,
        thumbnailUrl: uploadedMessage.thumbnailUrl,
        mimeType: uploadedMessage.mimeType,
        fileSizeBytes: uploadedMessage.fileSizeBytes,
        audioDuration: uploadedMessage.audioDuration,
        hasBlurEffect: uploadedMessage.hasBlurEffect,
        photoViewTimer: uploadedMessage.photoViewTimer,
        uploadId: uploadedMessage.uploadId,
        fileName: uploadedMessage.isFileMessage ? uploadedMessage.fileMessageName : null,
      );
    } catch (error) {
      debugPrint('Messenger sendMediaMessage failed: $error');

      final failedMessage = uploadedMessage.isImageMessage
          ? _pendingMessageFactory.createFailedImageMessage(
              message: uploadedMessage,
              failureReason: 'Remote-Sync fehlgeschlagen.',
            )
          : uploadedMessage.isAudioMessage
              ? _pendingMessageFactory.createFailedAudioMessage(
                  message: uploadedMessage,
                  failureReason: 'Remote-Sync fehlgeschlagen.',
                )
              : _pendingMessageFactory.createFailedFileMessage(
                  message: uploadedMessage,
                  failureReason: 'Remote-Sync fehlgeschlagen.',
                );

      _replaceMessage(
        chatId: uploadedMessage.chatId,
        messageId: uploadedMessage.id,
        replacement: failedMessage,
      );

      _updateChatPreview(
        chatId: uploadedMessage.chatId,
        previewText: uploadedMessage.isImageMessage
            ? 'Foto fehlgeschlagen'
            : uploadedMessage.isAudioMessage
                ? 'Sprachnachricht fehlgeschlagen'
                : 'Datei fehlgeschlagen',
        timestamp: uploadedMessage.createdAt,
        unreadCount: 0,
      );

      notifyListeners();
    }
  }

  String _mockRemoteMediaUrlForMessage(MessageModel message) {
    final uploadId = message.uploadId?.trim();
    final safeUploadId = uploadId == null || uploadId.isEmpty
        ? message.id
        : uploadId;

    if (message.isImageMessage) {
      return 'mock://messenger/uploaded/image/$safeUploadId';
    }

    if (message.isAudioMessage) {
      return 'mock://messenger/uploaded/audio/$safeUploadId';
    }

    return 'mock://messenger/uploaded/file/$safeUploadId';
  }

  void _scheduleAutoReply(String chatId) {
    if (_remoteMode.usesRemote) return;
    if (!_state.messagesByChatId.containsKey(chatId)) return;

    final chat = chatById(chatId);
    if (chat == null || chat.participants.isEmpty) return;

    final participant = chat.participants.first;

    _setParticipantOnlineState(
      participant.userId,
      isOnline: true,
    );

    final typingDuration = Duration(milliseconds: 900 + _random.nextInt(900));

    _setTypingForChat(chatId, isTyping: true, autoClearAfter: typingDuration);

    Future<void>.delayed(typingDuration, () {
      if (_isDisposed) return;
      if (!_state.messagesByChatId.containsKey(chatId)) return;

      final refreshedChat = chatById(chatId);
      if (refreshedChat == null || refreshedChat.participants.isEmpty) {
        _setTypingForChat(chatId, isTyping: false);
        return;
      }

      final refreshedParticipant = refreshedChat.participants.first;
      final replyText = _autoReplyPool[_random.nextInt(_autoReplyPool.length)];
      final now = DateTime.now();

      final incomingMessage = MessageModel(
        id: 'incoming_${now.microsecondsSinceEpoch}',
        chatId: chatId,
        senderUserId: refreshedParticipant.userId,
        text: replyText,
        createdAt: now,
        isOwnMessage: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
        messageType: MessageType.text,
      );

      _setTypingForChat(chatId, isTyping: false);
      _appendMessage(chatId, incomingMessage);

      _setParticipantOnlineState(
        refreshedParticipant.userId,
        isOnline: true,
      );

      final currentUnread = refreshedChat.unreadCount;
      final isChatOpen = _state.openChatIds.contains(chatId);

      _updateChatPreview(
        chatId: chatId,
        previewText: replyText,
        timestamp: now,
        unreadCount: isChatOpen ? 0 : currentUnread + 1,
      );

      notifyListeners();
    });
  }



  void _startRemotePresenceHeartbeat(String userId) {
    final cleanedUserId = userId.trim();

    _remotePresenceHeartbeatTimer?.cancel();
    _remotePresenceHeartbeatTimer = null;

    if (cleanedUserId.isEmpty ||
        !_remoteMode.usesRemote ||
        _isDisposed) {
      return;
    }

    _remotePresenceHeartbeatTimer = Timer.periodic(
      _presenceHeartbeatInterval,
      (_) {
        if (_isDisposed ||
            !_remoteMode.usesRemote ||
            _remoteCurrentUserId != cleanedUserId) {
          _stopRemotePresenceHeartbeat();
          return;
        }

        unawaited(
          _presenceRepository.touchLastActive(
            userId: cleanedUserId,
            keepOnline: true,
          ),
        );
      },
    );
  }

  void _stopRemotePresenceHeartbeat() {
    _remotePresenceHeartbeatTimer?.cancel();
    _remotePresenceHeartbeatTimer = null;
  }

  void _syncRemotePresenceForChats(List<ChatModel> remoteChats) {
    if (_isDisposed || !_remoteMode.usesRemote) return;

    final currentUserId = _remoteCurrentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final requiredUserIds = <String>{};
    final requiredChatIds = <String>{};

    for (final chat in remoteChats) {
      final otherUserId = _otherUserIdForDirectChat(chat);
      if (otherUserId == null || otherUserId.isEmpty) continue;

      requiredUserIds.add(otherUserId);
      requiredChatIds.add(chat.id);

      _remotePresenceSubscriptionsByUserId.putIfAbsent(
        otherUserId,
        () => _presenceRepository
            .watchUserPresence(userId: otherUserId)
            .listen(
          (snapshot) {
            if (_isDisposed) return;
            _setParticipantOnlineState(
              snapshot.userId,
              isOnline: snapshot.isOnline,
              lastActiveAt: snapshot.lastActiveAt,
            );
            notifyListeners();
          },
          onError: (Object error) {
            debugPrint('Messenger presence stream failed: $error');
          },
        ),
      );

      _remoteActivitySubscriptionsByChatId.putIfAbsent(
        chat.id,
        () => _presenceRepository
            .watchConversationActivity(
              conversationId: chat.id,
              userId: otherUserId,
            )
            .listen(
          (snapshot) {
            if (_isDisposed) return;
            _applyRemoteConversationActivity(snapshot);
          },
          onError: (Object error) {
            debugPrint('Messenger activity stream failed: $error');
          },
        ),
      );
    }

    final staleUsers = _remotePresenceSubscriptionsByUserId.keys
        .where((id) => !requiredUserIds.contains(id))
        .toList(growable: false);

    for (final id in staleUsers) {
      unawaited(_remotePresenceSubscriptionsByUserId.remove(id)?.cancel());
    }

    final staleChats = _remoteActivitySubscriptionsByChatId.keys
        .where((id) => !requiredChatIds.contains(id))
        .toList(growable: false);

    for (final id in staleChats) {
      unawaited(_remoteActivitySubscriptionsByChatId.remove(id)?.cancel());
      _remoteActivityStateByChatId.remove(id);
    }
  }

  void _applyRemoteConversationActivity(
    MessengerConversationActivitySnapshot snapshot,
  ) {
    final chatId = snapshot.conversationId.trim();
    if (chatId.isEmpty) return;

    final state =
        snapshot.isActive ? snapshot.state : MessengerActivityState.idle;

    if (state == MessengerActivityState.idle) {
      _remoteActivityStateByChatId.remove(chatId);
    } else {
      _remoteActivityStateByChatId[chatId] = state;
    }

    final typing = Set<String>.from(_state.typingChatIds);

    if (state == MessengerActivityState.typing) {
      typing.add(chatId);
    } else {
      typing.remove(chatId);
    }

    _state = _state.copyWith(typingChatIds: typing);
    notifyListeners();
  }

  Future<void> _stopAllRemotePresenceSyncs() async {
    final presence =
        _remotePresenceSubscriptionsByUserId.values.toList(growable: false);
    final activity =
        _remoteActivitySubscriptionsByChatId.values.toList(growable: false);

    _remotePresenceSubscriptionsByUserId.clear();
    _remoteActivitySubscriptionsByChatId.clear();
    _remoteActivityStateByChatId.clear();

    for (final subscription in presence) {
      await subscription.cancel();
    }

    for (final subscription in activity) {
      await subscription.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final currentUserId = _remoteCurrentUserId;

    if (_isDisposed ||
        !_remoteMode.usesRemote ||
        currentUserId == null ||
        currentUserId.isEmpty) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_presenceRepository.markOnline(userId: currentUserId));
        _startRemotePresenceHeartbeat(currentUserId);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopRemotePresenceHeartbeat();
        unawaited(_presenceRepository.markOffline(userId: currentUserId));
        unawaited(
          _presenceRepository.clearAllConversationActivityForUser(
            userId: currentUserId,
            conversationIds: _state.openChatIds,
          ),
        );
        break;
    }
  }

  void _setTypingForChat(
    String chatId, {
    required bool isTyping,
    Duration? autoClearAfter,
  }) {
    _typingTimersByChatId.remove(chatId)?.cancel();

    final updatedTypingChatIds = Set<String>.from(_state.typingChatIds);

    if (isTyping) {
      updatedTypingChatIds.add(chatId);
    } else {
      updatedTypingChatIds.remove(chatId);
    }

    if (setEquals(updatedTypingChatIds, _state.typingChatIds)) return;

    _state = _state.copyWith(typingChatIds: updatedTypingChatIds);
    notifyListeners();

    if (isTyping && autoClearAfter != null) {
      _typingTimersByChatId[chatId] = Timer(autoClearAfter, () {
        _typingTimersByChatId.remove(chatId);
        _setTypingForChat(chatId, isTyping: false);
      });
    }
  }

  void _initializePresenceState() {
    if (_remoteMode.isRemoteOnly) return;

    final updatedLastActiveByUserId =
        Map<String, DateTime>.from(_state.lastActiveByUserId);

    for (final chat in _state.chats) {
      for (final participant in chat.participants) {
        updatedLastActiveByUserId.putIfAbsent(
          participant.userId,
          () => DateTime.now().subtract(
            Duration(minutes: 2 + _random.nextInt(18)),
          ),
        );
      }
    }

    for (final participant in _suggestedContacts) {
      updatedLastActiveByUserId.putIfAbsent(
        participant.userId,
        () => DateTime.now().subtract(
          Duration(minutes: 1 + _random.nextInt(24)),
        ),
      );
    }

    _state = _state.copyWith(lastActiveByUserId: updatedLastActiveByUserId);
  }

  void _startPresenceSimulation() {
    if (_remoteMode.isRemoteOnly) return;

    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_remoteMode.isRemoteOnly) return;
      if (_state.chats.isEmpty) return;

      final availableChats =
          _state.chats.where((chat) => chat.participants.isNotEmpty).toList();

      if (availableChats.isEmpty) return;

      final randomChat = availableChats[_random.nextInt(availableChats.length)];
      final participant = randomChat.participants.first;
      final nextOnlineState = !participant.isOnline;

      _setParticipantOnlineState(
        participant.userId,
        isOnline: nextOnlineState,
      );

      notifyListeners();
    });
  }

  void _stopPresenceSimulation() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  void _restoreMockOnlyStateIfNeeded() {
    final existingChatIds = _state.chats.map((chat) => chat.id).toSet();
    final missingMockChats = MessengerMockData.chats
        .where((chat) => !existingChatIds.contains(chat.id))
        .toList(growable: false);

    if (missingMockChats.isEmpty) return;

    final updatedChats = <ChatModel>[
      ..._state.chats,
      ...missingMockChats,
    ];

    final updatedMessagesByChatId =
        Map<String, List<MessageModel>>.from(_state.messagesByChatId);

    for (final entry in MessengerMockData.messagesByChatId.entries) {
      updatedMessagesByChatId.putIfAbsent(
        entry.key,
        () => List<MessageModel>.from(entry.value),
      );
    }

    _state = _state.copyWith(
      chats: updatedChats,
      messagesByChatId: updatedMessagesByChatId,
    );
  }

  void _clearUserScopedState() {
    for (final timer in _typingTimersByChatId.values) {
      timer.cancel();
    }

    for (final timer
        in _remoteActivityClearTimersByChatId.values) {
      timer.cancel();
    }

    _typingTimersByChatId.clear();
    _remoteActivityClearTimersByChatId.clear();
    _lastReadSyncAtByChatId.clear();
    _readSyncsInFlightByChatId.clear();
    _mediaUploadIdsInFlight.clear();
    _blockStateByChatId.clear();
    _blockStateLoadsInFlight.clear();
    _remoteActivityStateByChatId.clear();
    _olderMessageLoadsInFlight.clear();
    _olderMessagesExhaustedChatIds.clear();

    _state = MessengerState.initial(
      chats: const <ChatModel>[],
      messagesByChatId:
          const <String, List<MessageModel>>{},
    );

    notifyListeners();
  }

  void _removeMockOnlyState() {
    final mockChatIds = MessengerMockData.chats.map((chat) => chat.id).toSet();

    final updatedMessagesByChatId =
        Map<String, List<MessageModel>>.from(_state.messagesByChatId)
          ..removeWhere((chatId, _) => mockChatIds.contains(chatId));

    final updatedOpenChatIds = Set<String>.from(_state.openChatIds)
      ..removeWhere((chatId) => mockChatIds.contains(chatId));

    final updatedTypingChatIds = Set<String>.from(_state.typingChatIds)
      ..removeWhere((chatId) => mockChatIds.contains(chatId));

    for (final chatId in mockChatIds) {
      _typingTimersByChatId.remove(chatId)?.cancel();
    }

    final updatedChats = _state.chats
        .where((chat) => !mockChatIds.contains(chat.id))
        .toList(growable: false);

    _state = _state.copyWith(
      chats: updatedChats,
      messagesByChatId: updatedMessagesByChatId,
      openChatIds: updatedOpenChatIds,
      typingChatIds: updatedTypingChatIds,
    );
  }

  void _setParticipantOnlineState(
    String userId, {
    required bool isOnline,
    DateTime? lastActiveAt,
  }) {
    final updatedLastActiveByUserId =
        Map<String, DateTime>.from(_state.lastActiveByUserId);

    if (lastActiveAt != null) {
      updatedLastActiveByUserId[userId] = lastActiveAt;
    } else if (!isOnline) {
      updatedLastActiveByUserId[userId] = DateTime.now();
    }

    final updatedChats = _state.chats.map((chat) {
      final updatedParticipants = chat.participants.map((participant) {
        if (participant.userId != userId) return participant;
        return participant.copyWith(isOnline: isOnline);
      }).toList();

      return chat.copyWith(participants: updatedParticipants);
    }).toList();

    _state = _state.copyWith(
      chats: updatedChats,
      lastActiveByUserId: updatedLastActiveByUserId,
    );
  }

  void _updateChatPreview({
    required String chatId,
    required String previewText,
    required DateTime timestamp,
    required int unreadCount,
  }) {
    bool changed = false;

    final updatedChats = _state.chats.map((chat) {
      if (chat.id != chatId) return chat;

      changed = true;
      final updatedArchivedUserIds = Set<String>.from(chat.archivedUserIds)
        ..removeAll(chat.participantIds);
      final updatedDeletedForUserIds = Set<String>.from(chat.deletedForUserIds)
        ..removeAll(chat.participantIds);

      return chat.copyWith(
        lastMessagePreview: previewText,
        lastMessageAt: timestamp,
        unreadCount: unreadCount,
        archivedUserIds: updatedArchivedUserIds,
        deletedForUserIds: updatedDeletedForUserIds,
        isArchived: false,
        isDeletedForCurrentUser: false,
      );
    }).toList();

    if (!changed) return;

    _state = _state.copyWith(chats: updatedChats);
  }

  void _updateMessageStatus({
    required String chatId,
    required String messageId,
    required MessageDeliveryStatus status,
  }) {
    final existingMessages = _state.messagesByChatId[chatId];
    if (existingMessages == null || existingMessages.isEmpty) return;

    bool changed = false;

    final updatedMessages = existingMessages.map((message) {
      if (message.id != messageId) return message;

      changed = true;
      return message.copyWith(deliveryStatus: status);
    }).toList();

    if (!changed) return;

    _replaceMessagesForChat(chatId: chatId, messages: updatedMessages);
  }

  MessageModel? _messageById({
    required String chatId,
    required String messageId,
  }) {
    final messages = _state.messagesByChatId[chatId];
    if (messages == null) return null;

    for (final message in messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  void _refreshChatAfterMessageChange(String chatId) {
    final messages = messagesForChat(chatId);
    final latest = messages.isNotEmpty ? messages.last : null;
    final existingChat = chatById(chatId);

    if (existingChat == null) return;

    if (latest == null) {
      _updateChatPreview(
        chatId: chatId,
        previewText: 'Noch keine Nachrichten',
        timestamp: existingChat.lastMessageAt,
        unreadCount: existingChat.unreadCount,
      );
      return;
    }

    _updateChatPreview(
      chatId: chatId,
      previewText: conversationPreviewText(existingChat),
      timestamp: latest.createdAt,
      unreadCount: existingChat.unreadCount,
    );
  }

  String _imagePreviewLabel(MessageModel message) {
    if (!message.isImageMessage) return '📷 Foto';

    if (message.hasBlurEffect && message.hasPhotoViewTimer) {
      return '📷 Foto • Unscharf • ${message.photoViewTimer!.inSeconds}s';
    }

    if (message.hasBlurEffect) return '📷 Foto • Unscharf';

    if (message.hasPhotoViewTimer) {
      return '📷 Foto • ${message.photoViewTimer!.inSeconds}s';
    }

    return '📷 Foto';
  }

  String _outgoingImageLoadingLabel(MessageModel message) {
    if (!message.isImageMessage) return 'Foto wird gesendet ...';

    if (message.hasBlurEffect && message.hasPhotoViewTimer) {
      return 'Unscharfes Timer-Foto wird gesendet ...';
    }

    if (message.hasBlurEffect) return 'Unscharfes Foto wird gesendet ...';

    if (message.hasPhotoViewTimer) return 'Timer-Foto wird gesendet ...';

    return 'Foto wird gesendet ...';
  }

  String _outgoingImageSuccessLabel(MessageModel message) {
    if (!message.isImageMessage) return 'Foto gesendet';

    if (message.hasBlurEffect && message.hasPhotoViewTimer) {
      return 'Unscharfes Timer-Foto gesendet';
    }

    if (message.hasBlurEffect) return 'Unscharfes Foto gesendet';

    if (message.hasPhotoViewTimer) {
      return 'Timer-Foto gesendet';
    }

    return 'Foto gesendet';
  }

  String? _otherUserIdForDirectChat(ChatModel? chat) {
    final currentUserId = _remoteCurrentUserId?.trim();
    if (chat == null || currentUserId == null || currentUserId.isEmpty) {
      return null;
    }

    for (final userId in chat.participantIds) {
      final cleanedUserId = userId.trim();
      if (cleanedUserId.isNotEmpty && cleanedUserId != currentUserId) {
        return cleanedUserId;
      }
    }

    for (final participant in chat.participants) {
      final cleanedUserId = participant.userId.trim();
      if (cleanedUserId.isNotEmpty && cleanedUserId != currentUserId) {
        return cleanedUserId;
      }
    }

    return null;
  }

  String _outgoingImageRetryLabel(MessageModel message) {
    if (!message.isImageMessage) return 'Foto wird erneut gesendet ...';

    if (message.hasBlurEffect && message.hasPhotoViewTimer) {
      return 'Unscharfes Timer-Foto wird erneut gesendet ...';
    }

    if (message.hasBlurEffect) {
      return 'Unscharfes Foto wird erneut gesendet ...';
    }

    if (message.hasPhotoViewTimer) {
      return 'Timer-Foto wird erneut gesendet ...';
    }

    return 'Foto wird erneut gesendet ...';
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    final currentUserId = _remoteCurrentUserId;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      unawaited(_presenceRepository.markOffline(userId: currentUserId));
    }

    _presenceTimer?.cancel();
    _presenceTimer = null;
    _stopRemotePresenceHeartbeat();

    for (final timer in _typingTimersByChatId.values) {
      timer.cancel();
    }
    _typingTimersByChatId.clear();
    _olderMessageLoadsInFlight.clear();
    _olderMessagesExhaustedChatIds.clear();

    for (final timer in _remoteActivityClearTimersByChatId.values) {
      timer.cancel();
    }
    _remoteActivityClearTimersByChatId.clear();
    _lastReadSyncAtByChatId.clear();
    _readSyncsInFlightByChatId.clear();
    _mediaUploadIdsInFlight.clear();
    _blockStateByChatId.clear();
    _blockStateLoadsInFlight.clear();

    unawaited(_stopRemoteConversationSync());
    unawaited(_stopAllRemoteMessageSyncs());
    unawaited(_stopAllRemotePresenceSyncs());

    super.dispose();
  }
}