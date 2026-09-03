import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

enum MessageType {
  text,
  image,
  audio,
  file,
}

enum MediaTransferState {
  none,
  loading,
  success,
  failed,
}

enum MediaUploadState {
  none,
  queued,
  uploading,
  uploaded,
  failed,
}

@immutable
class MessageModel {
  final String id;
  final String chatId;
  final String senderUserId;
  final String text;
  final DateTime createdAt;
  final bool isOwnMessage;
  final MessageDeliveryStatus deliveryStatus;
  final bool isEdited;

  final MessageType messageType;

  final String? imageUrl;
  final String? thumbnailUrl;
  final String? mediaStoragePath;
  final String? localMediaPath;
  final String? uploadId;
  final String? uploadFailureReason;
  final String? mimeType;
  final int? fileSizeBytes;

  final bool hasBlurEffect;
  final Duration? photoViewTimer;

  final Duration? audioDuration;
  final double? audioProgress;
  final bool isAudioPlaying;

  final MediaTransferState mediaTransferState;
  final MediaUploadState mediaUploadState;

  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? deletedByUserId;
  final Set<String> deliveredToUserIds;
  final Set<String> readByUserIds;

  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderUserId;
  final MessageType? replyToMessageType;

  final Map<String, String> reactions;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderUserId,
    required this.text,
    required this.createdAt,
    required this.isOwnMessage,
    this.deliveryStatus = MessageDeliveryStatus.sent,
    this.isEdited = false,
    this.messageType = MessageType.text,
    this.imageUrl,
    this.thumbnailUrl,
    this.mediaStoragePath,
    this.localMediaPath,
    this.uploadId,
    this.uploadFailureReason,
    this.mimeType,
    this.fileSizeBytes,
    this.hasBlurEffect = false,
    this.photoViewTimer,
    this.audioDuration,
    this.audioProgress,
    this.isAudioPlaying = false,
    this.mediaTransferState = MediaTransferState.none,
    this.mediaUploadState = MediaUploadState.none,
    this.editedAt,
    this.deletedAt,
    this.deletedByUserId,
    this.deliveredToUserIds = const <String>{},
    this.readByUserIds = const <String>{},
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderUserId,
    this.replyToMessageType,
    this.reactions = const <String, String>{},
  });

  factory MessageModel.fromMap({
    required String id,
    required String chatId,
    required Map<String, dynamic> map,
    required String currentUserId,
  }) {
    final senderUserId = _readString(map['senderUserId']);

    return MessageModel(
      id: id.trim(),
      chatId: chatId.trim(),
      senderUserId: senderUserId,
      text: _readString(map['text']),
      createdAt: _readDateTime(map['createdAt']),
      isOwnMessage: senderUserId == currentUserId.trim(),
      deliveryStatus: _readDeliveryStatus(map['deliveryStatus']),
      isEdited: _readBool(map['isEdited']),
      messageType: _readMessageType(map['messageType']),
      imageUrl: _readNullableString(map['imageUrl']),
      thumbnailUrl: _readNullableString(map['thumbnailUrl']),
      mediaStoragePath: _readNullableString(map['mediaStoragePath']),
      localMediaPath: _readNullableString(map['localMediaPath']),
      uploadId: _readNullableString(map['uploadId']),
      uploadFailureReason: _readNullableString(map['uploadFailureReason']),
      mimeType: _readNullableString(map['mimeType']),
      fileSizeBytes: _readNullablePositiveInt(map['fileSizeBytes']),
      hasBlurEffect: _readBool(map['hasBlurEffect']),
      photoViewTimer: _readDurationFromSeconds(map['photoViewTimerSeconds']),
      audioDuration: _readDurationFromMilliseconds(
        map['audioDurationMilliseconds'],
      ),
      audioProgress: _readNullableDouble(map['audioProgress']),
      isAudioPlaying: false,
      mediaTransferState: _readMediaTransferState(map['mediaTransferState']),
      mediaUploadState: _readMediaUploadState(map['mediaUploadState']),
      editedAt: _readNullableDateTime(map['editedAt']),
      deletedAt: _readNullableDateTime(map['deletedAt']),
      deletedByUserId: _readNullableString(map['deletedByUserId']),
      deliveredToUserIds: _readStringSet(map['deliveredToUserIds']),
      readByUserIds: _readStringSet(map['readByUserIds']),
      replyToMessageId: _readNullableString(map['replyToMessageId']),
      replyToText: _readNullableString(map['replyToText']),
      replyToSenderUserId: _readNullableString(map['replyToSenderUserId']),
      replyToMessageType: _readNullableReplyMessageType(
        map['replyToMessageType'],
      ),
      reactions: _readReactionMap(map['reactions']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'chatId': chatId.trim(),
      'senderUserId': senderUserId.trim(),
      'text': text.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveryStatus': deliveryStatus.name,
      'isEdited': isEdited,
      'messageType': messageType.name,
      'hasBlurEffect': hasBlurEffect,
      'mediaTransferState': mediaTransferState.name,
      'mediaUploadState': mediaUploadState.name,
      'deliveredToUserIds': _stableStringList(deliveredToUserIds),
      'readByUserIds': _stableStringList(readByUserIds),
    };

    final cleanImageUrl = _cleanNullableString(imageUrl);
    if (cleanImageUrl != null) {
      map['imageUrl'] = cleanImageUrl;
    }

    final cleanThumbnailUrl = _cleanNullableString(thumbnailUrl);
    if (cleanThumbnailUrl != null) {
      map['thumbnailUrl'] = cleanThumbnailUrl;
    }

    final cleanMediaStoragePath = _cleanNullableString(mediaStoragePath);
    if (cleanMediaStoragePath != null) {
      map['mediaStoragePath'] = cleanMediaStoragePath;
    }

    final cleanLocalMediaPath = _cleanNullableString(localMediaPath);
    if (cleanLocalMediaPath != null) {
      map['localMediaPath'] = cleanLocalMediaPath;
    }

    final cleanUploadId = _cleanNullableString(uploadId);
    if (cleanUploadId != null) {
      map['uploadId'] = cleanUploadId;
    }

    final cleanUploadFailureReason = _cleanNullableString(uploadFailureReason);
    if (cleanUploadFailureReason != null) {
      map['uploadFailureReason'] = cleanUploadFailureReason;
    }

    final cleanMimeType = _cleanNullableString(mimeType);
    if (cleanMimeType != null) {
      map['mimeType'] = cleanMimeType;
    }

    if (fileSizeBytes != null && fileSizeBytes! > 0) {
      map['fileSizeBytes'] = fileSizeBytes;
    }

    if (photoViewTimer != null && photoViewTimer!.inSeconds > 0) {
      map['photoViewTimerSeconds'] = photoViewTimer!.inSeconds;
    }

    if (audioDuration != null && audioDuration!.inMilliseconds > 0) {
      map['audioDurationMilliseconds'] = audioDuration!.inMilliseconds;
    }

    if (audioProgress != null) {
      map['audioProgress'] = safeAudioProgress;
    }

    if (editedAt != null) {
      map['editedAt'] = Timestamp.fromDate(editedAt!);
    }

    if (deletedAt != null) {
      map['deletedAt'] = Timestamp.fromDate(deletedAt!);
    }


    final cleanReplyToMessageId = _cleanNullableString(replyToMessageId);
    if (cleanReplyToMessageId != null) {
      map['replyToMessageId'] = cleanReplyToMessageId;
    }

    final cleanReplyToText = _cleanNullableString(replyToText);
    if (cleanReplyToText != null) {
      map['replyToText'] = cleanReplyToText;
    }

    final cleanReplyToSenderUserId =
        _cleanNullableString(replyToSenderUserId);

    if (cleanReplyToSenderUserId != null) {
      map['replyToSenderUserId'] = cleanReplyToSenderUserId;
    }

    if (replyToMessageType != null) {
      map['replyToMessageType'] = replyToMessageType!.name;
    }

    if (reactions.isNotEmpty) {
      map['reactions'] = _stableReactionMap(reactions);
    }

    final cleanDeletedByUserId = _cleanNullableString(deletedByUserId);
    if (cleanDeletedByUserId != null) {
      map['deletedByUserId'] = cleanDeletedByUserId;
    }

    return map;
  }

  bool get hasText => text.trim().isNotEmpty;

  bool get hasReactions => reactions.isNotEmpty;

  bool get isTextMessage => messageType == MessageType.text;
  bool get isImageMessage => messageType == MessageType.image;
  bool get isAudioMessage => messageType == MessageType.audio;
  bool get isFileMessage => messageType == MessageType.file;

  bool get isDeleted => deletedAt != null;

  bool get hasUsableFileUrl {
    final value = imageUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasUsableImageUrl {
    final value = imageUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasUsableThumbnailUrl {
    final value = thumbnailUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasMediaStoragePath {
    final value = mediaStoragePath?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasLocalMediaPath {
    final value = localMediaPath?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasUploadId {
    final value = uploadId?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasMimeType {
    final value = mimeType?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasFileSize {
    final value = fileSizeBytes;
    return value != null && value > 0;
  }

  bool get hasUploadFailureReason {
    final value = uploadFailureReason?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasUsableAudioDuration {
    final value = audioDuration;
    return value != null && value.inMilliseconds > 0;
  }

  bool get hasPhotoViewTimer {
    final value = photoViewTimer;
    return value != null && value.inSeconds > 0;
  }

  bool get isBlurredPhotoMessage => isImageMessage && hasBlurEffect;

  bool get isTimedPhotoMessage => isImageMessage && hasPhotoViewTimer;

  bool get isEnhancedPhotoMessage =>
      isImageMessage && (hasBlurEffect || hasPhotoViewTimer);

  String get photoMessageSummaryLabel {
    if (!isImageMessage) return 'Foto';

    if (hasBlurEffect && hasPhotoViewTimer) {
      return 'Foto • Unscharf • ${photoViewTimer!.inSeconds}s';
    }

    if (hasBlurEffect) return 'Foto • Unscharf';

    if (hasPhotoViewTimer) {
      return 'Foto • ${photoViewTimer!.inSeconds}s';
    }

    return 'Foto';
  }

  String get fileMessageName {
    final value = text.trim();
    return value.isEmpty ? 'Datei' : value;
  }

  String get fileMessageSummaryLabel {
    final name = fileMessageName;
    final size = formattedFileSize;
    if (size.isEmpty) return name;
    return '$name • $size';
  }

  String get formattedFileSize {
    final bytes = fileSizeBytes;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb < 10 ? 1 : 0)} GB';
  }

  double get safeAudioProgress {
    final value = audioProgress ?? 0.0;

    if (value.isNaN || value.isInfinite) return 0.0;
    if (value < 0) return 0.0;
    if (value > 1) return 1.0;

    return value;
  }

  bool get canRenderAsImageMessage => isImageMessage;

  bool get canRenderAsAudioMessage => isAudioMessage && hasUsableAudioDuration;

  bool get canRenderAsFileMessage => isFileMessage && hasUsableFileUrl;

  bool get isMediaLoading => mediaTransferState == MediaTransferState.loading;
  bool get isMediaFailed => mediaTransferState == MediaTransferState.failed;
  bool get isMediaReady =>
      mediaTransferState == MediaTransferState.success ||
      mediaTransferState == MediaTransferState.none;

  bool get isUploadQueued => mediaUploadState == MediaUploadState.queued;
  bool get isUploading => mediaUploadState == MediaUploadState.uploading;
  bool get isUploadFailed => mediaUploadState == MediaUploadState.failed;
  bool get isUploadComplete => mediaUploadState == MediaUploadState.uploaded;
  bool get hasPendingUpload => isUploadQueued || isUploading;

  bool get isLocalOnlyMediaMessage {
    if (!(isImageMessage || isAudioMessage || isFileMessage)) return false;
    if (!hasLocalMediaPath) return false;
    return hasPendingUpload || isUploadFailed;
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderUserId,
    String? text,
    DateTime? createdAt,
    bool? isOwnMessage,
    MessageDeliveryStatus? deliveryStatus,
    bool? isEdited,
    MessageType? messageType,
    String? imageUrl,
    bool clearImageUrl = false,
    String? thumbnailUrl,
    bool clearThumbnailUrl = false,
    String? mediaStoragePath,
    bool clearMediaStoragePath = false,
    String? localMediaPath,
    bool clearLocalMediaPath = false,
    String? uploadId,
    bool clearUploadId = false,
    String? uploadFailureReason,
    bool clearUploadFailureReason = false,
    String? mimeType,
    bool clearMimeType = false,
    int? fileSizeBytes,
    bool clearFileSizeBytes = false,
    bool? hasBlurEffect,
    Duration? photoViewTimer,
    bool clearPhotoViewTimer = false,
    Duration? audioDuration,
    bool clearAudioDuration = false,
    double? audioProgress,
    bool clearAudioProgress = false,
    bool? isAudioPlaying,
    MediaTransferState? mediaTransferState,
    MediaUploadState? mediaUploadState,
    DateTime? editedAt,
    bool clearEditedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? deletedByUserId,
    bool clearDeletedByUserId = false,
    Set<String>? deliveredToUserIds,
    Set<String>? readByUserIds,
    String? replyToMessageId,
    bool clearReplyToMessageId = false,
    String? replyToText,
    bool clearReplyToText = false,
    String? replyToSenderUserId,
    bool clearReplyToSenderUserId = false,
    MessageType? replyToMessageType,
    bool clearReplyToMessageType = false,
    Map<String, String>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderUserId: senderUserId ?? this.senderUserId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isOwnMessage: isOwnMessage ?? this.isOwnMessage,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isEdited: isEdited ?? this.isEdited,
      messageType: messageType ?? this.messageType,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      thumbnailUrl:
          clearThumbnailUrl ? null : (thumbnailUrl ?? this.thumbnailUrl),
      mediaStoragePath: clearMediaStoragePath
          ? null
          : (mediaStoragePath ?? this.mediaStoragePath),
      localMediaPath:
          clearLocalMediaPath ? null : (localMediaPath ?? this.localMediaPath),
      uploadId: clearUploadId ? null : (uploadId ?? this.uploadId),
      uploadFailureReason: clearUploadFailureReason
          ? null
          : (uploadFailureReason ?? this.uploadFailureReason),
      mimeType: clearMimeType ? null : (mimeType ?? this.mimeType),
      fileSizeBytes:
          clearFileSizeBytes ? null : (fileSizeBytes ?? this.fileSizeBytes),
      hasBlurEffect: hasBlurEffect ?? this.hasBlurEffect,
      photoViewTimer:
          clearPhotoViewTimer ? null : (photoViewTimer ?? this.photoViewTimer),
      audioDuration:
          clearAudioDuration ? null : (audioDuration ?? this.audioDuration),
      audioProgress:
          clearAudioProgress ? null : (audioProgress ?? this.audioProgress),
      isAudioPlaying: isAudioPlaying ?? this.isAudioPlaying,
      mediaTransferState: mediaTransferState ?? this.mediaTransferState,
      mediaUploadState: mediaUploadState ?? this.mediaUploadState,
      editedAt: clearEditedAt ? null : (editedAt ?? this.editedAt),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deletedByUserId: clearDeletedByUserId
          ? null
          : (deletedByUserId ?? this.deletedByUserId),
      deliveredToUserIds: deliveredToUserIds ?? this.deliveredToUserIds,
      readByUserIds: readByUserIds ?? this.readByUserIds,
      replyToMessageId: clearReplyToMessageId
          ? null
          : (replyToMessageId ?? this.replyToMessageId),
      replyToText: clearReplyToText
          ? null
          : (replyToText ?? this.replyToText),
      replyToSenderUserId: clearReplyToSenderUserId
          ? null
          : (replyToSenderUserId ?? this.replyToSenderUserId),
      replyToMessageType: clearReplyToMessageType
          ? null
          : (replyToMessageType ?? this.replyToMessageType),
      reactions: reactions ?? this.reactions,
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static String? _readNullableString(dynamic value) {
    return _cleanNullableString(value);
  }

  static String? _cleanNullableString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    return false;
  }

  static double? _readNullableDouble(dynamic value) {
    if (value is! num) return null;

    final parsed = value.toDouble();
    if (parsed.isNaN || parsed.isInfinite) return null;
    if (parsed < 0) return 0.0;
    if (parsed > 1) return 1.0;

    return parsed;
  }

  static int? _readNullablePositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    return null;
  }

  static DateTime _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _readNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Duration? _readDurationFromSeconds(dynamic value) {
    if (value is int && value > 0) return Duration(seconds: value);
    if (value is num && value > 0) return Duration(seconds: value.toInt());
    return null;
  }

  static Duration? _readDurationFromMilliseconds(dynamic value) {
    if (value is int && value > 0) return Duration(milliseconds: value);
    if (value is num && value > 0) {
      return Duration(milliseconds: value.toInt());
    }
    return null;
  }


  static Map<String, String> _readReactionMap(dynamic value) {
    if (value is! Map) return const <String, String>{};

    final result = <String, String>{};

    for (final entry in value.entries) {
      final key = _cleanNullableString(entry.key);
      final reaction = _cleanNullableString(entry.value);

      if (key == null || reaction == null) continue;

      result[key] = reaction;
    }

    return Map.unmodifiable(result);
  }

  static Map<String, String> _stableReactionMap(
    Map<String, String> reactions,
  ) {
    final sortedKeys = reactions.keys.toList()..sort();

    final stable = <String, String>{};

    for (final key in sortedKeys) {
      final value = reactions[key];

      if (value == null) continue;

      stable[key] = value;
    }

    return Map.unmodifiable(stable);
  }

  static Set<String> _readStringSet(dynamic value) {
    if (value is! List) return const <String>{};

    final cleaned = value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();

    return Set.unmodifiable(cleaned);
  }

  static List<String> _stableStringList(Set<String> values) {
    final cleaned = values
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);

    cleaned.sort();
    return List.unmodifiable(cleaned);
  }

  static MessageDeliveryStatus _readDeliveryStatus(dynamic value) {
    if (value is String) {
      for (final status in MessageDeliveryStatus.values) {
        if (status.name == value) return status;
      }
    }

    return MessageDeliveryStatus.sent;
  }

  static MessageType _readMessageType(dynamic value) {
    if (value is String) {
      for (final type in MessageType.values) {
        if (type.name == value) return type;
      }
    }

    return MessageType.text;
  }


  static MessageType? _readNullableReplyMessageType(dynamic value) {
    if (value is String) {
      for (final type in MessageType.values) {
        if (type.name == value) return type;
      }
    }

    return null;
  }

  static MediaTransferState _readMediaTransferState(dynamic value) {
    if (value is String) {
      for (final state in MediaTransferState.values) {
        if (state.name == value) return state;
      }
    }

    return MediaTransferState.none;
  }

  static MediaUploadState _readMediaUploadState(dynamic value) {
    if (value is String) {
      for (final state in MediaUploadState.values) {
        if (state.name == value) return state;
      }
    }

    return MediaUploadState.none;
  }

  static int _stableStringSetHash(Set<String> values) {
    final sorted = values
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return Object.hashAll(sorted);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MessageModel &&
        other.id == id &&
        other.chatId == chatId &&
        other.senderUserId == senderUserId &&
        other.text == text &&
        other.createdAt == createdAt &&
        other.isOwnMessage == isOwnMessage &&
        other.deliveryStatus == deliveryStatus &&
        other.isEdited == isEdited &&
        other.messageType == messageType &&
        other.imageUrl == imageUrl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.mediaStoragePath == mediaStoragePath &&
        other.localMediaPath == localMediaPath &&
        other.uploadId == uploadId &&
        other.uploadFailureReason == uploadFailureReason &&
        other.mimeType == mimeType &&
        other.fileSizeBytes == fileSizeBytes &&
        other.hasBlurEffect == hasBlurEffect &&
        other.photoViewTimer == photoViewTimer &&
        other.audioDuration == audioDuration &&
        other.audioProgress == audioProgress &&
        other.isAudioPlaying == isAudioPlaying &&
        other.mediaTransferState == mediaTransferState &&
        other.mediaUploadState == mediaUploadState &&
        other.editedAt == editedAt &&
        other.deletedAt == deletedAt &&
        other.deletedByUserId == deletedByUserId &&
        other.replyToMessageId == replyToMessageId &&
        other.replyToText == replyToText &&
        other.replyToSenderUserId == replyToSenderUserId &&
        other.replyToMessageType == replyToMessageType &&
        mapEquals(other.reactions, reactions) &&
        setEquals(other.deliveredToUserIds, deliveredToUserIds) &&
        setEquals(other.readByUserIds, readByUserIds);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      chatId,
      senderUserId,
      text,
      createdAt,
      isOwnMessage,
      deliveryStatus,
      isEdited,
      messageType,
      imageUrl,
      thumbnailUrl,
      mediaStoragePath,
      localMediaPath,
      uploadId,
      uploadFailureReason,
      mimeType,
      fileSizeBytes,
      hasBlurEffect,
      photoViewTimer,
      audioDuration,
      audioProgress,
      isAudioPlaying,
      mediaTransferState,
      mediaUploadState,
      editedAt,
      deletedAt,
      deletedByUserId,
      Object.hashAll(
        reactions.entries.map(
          (entry) => Object.hash(entry.key, entry.value),
        ),
      ),
      _stableStringSetHash(deliveredToUserIds),
      _stableStringSetHash(readByUserIds),
    ]);
  }
}
