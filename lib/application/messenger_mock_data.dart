import '../domain/models/chat_model.dart';
import '../domain/models/message_model.dart';

class MessengerMockData {
  MessengerMockData._();

  static const String currentUserId = 'user_me';

  static final List<ChatModel> chats = [
    ChatModel(
      id: 'chat_001',
      participants: const [
        ChatParticipantModel(
          userId: 'user_lina',
          displayName: 'Lina Hartmann',
          avatarUrl: '',
          isOnline: true,
        ),
      ],
      lastMessagePreview: 'Klingt gut. Ich schaue es mir heute Abend an.',
      lastMessageAt: DateTime(2026, 4, 22, 19, 42),
      unreadCount: 2,
      isPinned: true,
    ),
    ChatModel(
      id: 'chat_002',
      participants: const [
        ChatParticipantModel(
          userId: 'user_noah',
          displayName: 'Noah Becker',
          avatarUrl: '',
          isOnline: false,
        ),
      ],
      lastMessagePreview: 'Danke dir. Das Design wirkt deutlich ruhiger.',
      lastMessageAt: DateTime(2026, 4, 22, 16, 19),
      unreadCount: 0,
    ),
    ChatModel(
      id: 'chat_003',
      participants: const [
        ChatParticipantModel(
          userId: 'user_sophia',
          displayName: 'Sophia Wagner',
          avatarUrl: '',
          isOnline: true,
        ),
      ],
      lastMessagePreview:
          'Wir sollten den Messenger erst im Mock sauber fertig machen.',
      lastMessageAt: DateTime(2026, 4, 21, 21, 8),
      unreadCount: 1,
      isMuted: true,
    ),
    ChatModel(
      id: 'chat_004',
      participants: const [
        ChatParticipantModel(
          userId: 'user_elias',
          displayName: 'Elias König',
          avatarUrl: '',
          isOnline: false,
        ),
      ],
      lastMessagePreview: 'Morgen sende ich dir die nächsten Screens.',
      lastMessageAt: DateTime(2026, 4, 21, 11, 27),
      unreadCount: 0,
    ),
    ChatModel(
      id: 'chat_005',
      participants: const [
        ChatParticipantModel(
          userId: 'user_mila',
          displayName: 'Mila Schneider',
          avatarUrl: '',
          isOnline: true,
        ),
      ],
      lastMessagePreview: 'Das Fundament steht. Jetzt kann man sauber erweitern.',
      lastMessageAt: DateTime(2026, 4, 20, 23, 17),
      unreadCount: 4,
    ),
  ];

  static final Map<String, List<MessageModel>> messagesByChatId = {
    'chat_001': [
      MessageModel(
        id: 'msg_001',
        chatId: 'chat_001',
        senderUserId: 'user_lina',
        text: 'Hast du die neue Messenger-Struktur schon gesehen?',
        createdAt: DateTime(2026, 4, 22, 19, 31),
        isOwnMessage: false,
      ),
      MessageModel(
        id: 'msg_002',
        chatId: 'chat_001',
        senderUserId: currentUserId,
        text:
            'Ja, ich will aber von Anfang an direkt sichtbare Ergebnisse haben.',
        createdAt: DateTime(2026, 4, 22, 19, 35),
        isOwnMessage: true,
      ),
      MessageModel(
        id: 'msg_003',
        chatId: 'chat_001',
        senderUserId: 'user_lina',
        text: 'Klingt gut. Ich schaue es mir heute Abend an.',
        createdAt: DateTime(2026, 4, 22, 19, 42),
        isOwnMessage: false,
      ),
    ],
    'chat_002': [
      MessageModel(
        id: 'msg_004',
        chatId: 'chat_002',
        senderUserId: currentUserId,
        text: 'Wie wirkt das neue Layout auf dich?',
        createdAt: DateTime(2026, 4, 22, 16, 10),
        isOwnMessage: true,
      ),
      MessageModel(
        id: 'msg_005',
        chatId: 'chat_002',
        senderUserId: 'user_noah',
        text: 'Danke dir. Das Design wirkt deutlich ruhiger.',
        createdAt: DateTime(2026, 4, 22, 16, 18),
        isOwnMessage: false,
      ),
      MessageModel(
        id: 'msg_005_media_image',
        chatId: 'chat_002',
        senderUserId: 'user_noah',
        text: '',
        createdAt: DateTime(2026, 4, 22, 16, 19),
        isOwnMessage: false,
        messageType: MessageType.image,
        imageUrl: 'mock://messenger/image/layout_preview_01',
        mediaTransferState: MediaTransferState.success,
      ),
    ],
    'chat_003': [
      MessageModel(
        id: 'msg_006',
        chatId: 'chat_003',
        senderUserId: 'user_sophia',
        text: 'Bitte jetzt nicht direkt Firebase einbauen.',
        createdAt: DateTime(2026, 4, 21, 20, 56),
        isOwnMessage: false,
      ),
      MessageModel(
        id: 'msg_007',
        chatId: 'chat_003',
        senderUserId: currentUserId,
        text: 'Nein, erst Models, Mock-Daten und sichtbare Ergebnisse.',
        createdAt: DateTime(2026, 4, 21, 21, 1),
        isOwnMessage: true,
      ),
      MessageModel(
        id: 'msg_008',
        chatId: 'chat_003',
        senderUserId: 'user_sophia',
        text: 'Wir sollten den Messenger erst im Mock sauber fertig machen.',
        createdAt: DateTime(2026, 4, 21, 21, 6),
        isOwnMessage: false,
      ),
      MessageModel(
        id: 'msg_008_media_audio',
        chatId: 'chat_003',
        senderUserId: 'user_sophia',
        text: '',
        createdAt: DateTime(2026, 4, 21, 21, 8),
        isOwnMessage: false,
        messageType: MessageType.audio,
        audioDuration: Duration(seconds: 18),
        audioProgress: 0.32,
        isAudioPlaying: false,
        mediaTransferState: MediaTransferState.success,
      ),
    ],
    'chat_004': [
      MessageModel(
        id: 'msg_009',
        chatId: 'chat_004',
        senderUserId: 'user_elias',
        text: 'Ich bereite die nächsten Ansichten vor.',
        createdAt: DateTime(2026, 4, 21, 11, 12),
        isOwnMessage: false,
      ),
      MessageModel(
        id: 'msg_010',
        chatId: 'chat_004',
        senderUserId: 'user_elias',
        text: 'Morgen sende ich dir die nächsten Screens.',
        createdAt: DateTime(2026, 4, 21, 11, 27),
        isOwnMessage: false,
      ),
    ],
    'chat_005': [
      MessageModel(
        id: 'msg_011',
        chatId: 'chat_005',
        senderUserId: currentUserId,
        text: 'Jetzt sieht man endlich früh, ob die Struktur sauber ist.',
        createdAt: DateTime(2026, 4, 20, 23, 5),
        isOwnMessage: true,
      ),
      MessageModel(
        id: 'msg_012',
        chatId: 'chat_005',
        senderUserId: 'user_mila',
        text: 'Das Fundament steht. Jetzt kann man sauber erweitern.',
        createdAt: DateTime(2026, 4, 20, 23, 14),
        isOwnMessage: false,
      ),
      MessageModel(
        id: 'msg_012_media_image_own',
        chatId: 'chat_005',
        senderUserId: currentUserId,
        text: '',
        createdAt: DateTime(2026, 4, 20, 23, 16),
        isOwnMessage: true,
        messageType: MessageType.image,
        imageUrl: 'mock://messenger/image/moodboard_01',
        deliveryStatus: MessageDeliveryStatus.delivered,
        mediaTransferState: MediaTransferState.success,
      ),
      MessageModel(
        id: 'msg_012_media_audio_own',
        chatId: 'chat_005',
        senderUserId: currentUserId,
        text: '',
        createdAt: DateTime(2026, 4, 20, 23, 17),
        isOwnMessage: true,
        messageType: MessageType.audio,
        audioDuration: Duration(seconds: 9),
        audioProgress: 0.68,
        isAudioPlaying: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
        mediaTransferState: MediaTransferState.success,
      ),
    ],
  };
}