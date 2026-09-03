// Pfad: lib/application/messenger_media_upload_service.dart
//
// Kompatibilitätsfassung für den wiederhergestellten historischen Luma-Messenger.
// Ergänzt Bild-, Audio- und Datei-Uploads mit den produktiven Luma-Storage-Pfaden.

import '../domain/models/message_model.dart';
import 'messenger_storage_service.dart';

export 'messenger_storage_service.dart' show MessengerPreparedMediaUpload;

class MessengerMediaUploadService {
  const MessengerMediaUploadService();

  MessengerPreparedMediaUpload prepareImageUpload({
    required String conversationId,
    required String senderUserId,
    required String localImagePath,
    String mimeType = 'image/jpeg',
    int? fileSizeBytes,
    bool hasBlurEffect = false,
    Duration? photoViewTimer,
  }) {
    final now = DateTime.now();
    final uploadId = 'img_${now.microsecondsSinceEpoch}';
    final messageId = 'local_media_$uploadId';
    final cleanConversationId = conversationId.trim();
    final cleanSenderUserId = senderUserId.trim();
    final extension = _imageExtension(mimeType);

    return MessengerPreparedMediaUpload(
      uploadId: uploadId,
      messageId: messageId,
      conversationId: cleanConversationId,
      senderUserId: cleanSenderUserId,
      localMediaPath: localImagePath.trim(),
      storagePath:
          'messenger_media/$cleanConversationId/images/$cleanSenderUserId/$uploadId.$extension',
      messageType: MessageType.image,
      mimeType: mimeType.trim().isEmpty ? 'image/jpeg' : mimeType.trim(),
      fileSizeBytes: fileSizeBytes,
      hasBlurEffect: hasBlurEffect,
      photoViewTimer: photoViewTimer,
      createdAt: now,
    );
  }

  MessengerPreparedMediaUpload prepareAudioUpload({
    required String conversationId,
    required String senderUserId,
    required String localAudioPath,
    required Duration audioDuration,
    String mimeType = 'audio/mpeg',
    int? fileSizeBytes,
  }) {
    final now = DateTime.now();
    final uploadId = 'audio_${now.microsecondsSinceEpoch}';
    final messageId = 'local_media_$uploadId';
    final cleanConversationId = conversationId.trim();
    final cleanSenderUserId = senderUserId.trim();
    final extension = _audioExtension(mimeType);

    return MessengerPreparedMediaUpload(
      uploadId: uploadId,
      messageId: messageId,
      conversationId: cleanConversationId,
      senderUserId: cleanSenderUserId,
      localMediaPath: localAudioPath.trim(),
      storagePath:
          'messenger_media/$cleanConversationId/audio/$cleanSenderUserId/$uploadId.$extension',
      messageType: MessageType.audio,
      mimeType: mimeType.trim().isEmpty ? 'audio/mpeg' : mimeType.trim(),
      fileSizeBytes: fileSizeBytes,
      audioDuration: audioDuration,
      createdAt: now,
    );
  }

  MessengerPreparedMediaUpload prepareFileUpload({
    required String conversationId,
    required String senderUserId,
    required String localFilePath,
    String mimeType = 'application/octet-stream',
    int? fileSizeBytes,
  }) {
    final now = DateTime.now();
    final uploadId = 'file_${now.microsecondsSinceEpoch}';
    final messageId = 'local_media_$uploadId';
    final cleanConversationId = conversationId.trim();
    final cleanSenderUserId = senderUserId.trim();
    final cleanLocalFilePath = localFilePath.trim();
    final extension = _fileExtensionFromPath(cleanLocalFilePath);

    return MessengerPreparedMediaUpload(
      uploadId: uploadId,
      messageId: messageId,
      conversationId: cleanConversationId,
      senderUserId: cleanSenderUserId,
      localMediaPath: cleanLocalFilePath,
      storagePath:
          'messenger_media/$cleanConversationId/files/$cleanSenderUserId/$uploadId.$extension',
      messageType: MessageType.file,
      mimeType: mimeType.trim().isEmpty
          ? 'application/octet-stream'
          : mimeType.trim(),
      fileSizeBytes: fileSizeBytes,
      createdAt: now,
    );
  }

  String _imageExtension(String mimeType) {
    switch (mimeType.trim().toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }

  String _audioExtension(String mimeType) {
    switch (mimeType.trim().toLowerCase()) {
      case 'audio/aac':
        return 'aac';
      case 'audio/wav':
      case 'audio/x-wav':
        return 'wav';
      case 'audio/webm':
        return 'webm';
      case 'audio/mp4':
        return 'm4a';
      default:
        return 'mp3';
    }
  }

  String _fileExtensionFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex <= 0 || dotIndex >= fileName.length - 1) {
      return 'bin';
    }

    final extension = fileName.substring(dotIndex + 1).toLowerCase();
    final allowed = <String>{
      'pdf',
      'txt',
      'csv',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'zip',
    };

    return allowed.contains(extension) ? extension : 'bin';
  }
}

extension MessengerPreparedMediaUploadMessageX on MessengerPreparedMediaUpload {
  MessageModel toPendingMessage() {
    return MessageModel(
      id: messageId,
      chatId: conversationId,
      senderUserId: senderUserId,
      text: '',
      createdAt: createdAt,
      isOwnMessage: true,
      deliveryStatus: MessageDeliveryStatus.sending,
      messageType: messageType,
      localMediaPath: localMediaPath,
      mediaStoragePath: storagePath,
      uploadId: uploadId,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      hasBlurEffect: hasBlurEffect,
      photoViewTimer: photoViewTimer,
      audioDuration: audioDuration,
      mediaTransferState: MediaTransferState.loading,
      mediaUploadState: MediaUploadState.queued,
    );
  }
}
