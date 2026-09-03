// Pfad: lib/application/messenger_storage_service.dart

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/models/message_model.dart';

@immutable
class MessengerPreparedMediaUpload {
  final String uploadId;
  final String messageId;
  final String conversationId;
  final String senderUserId;
  final String localMediaPath;
  final String storagePath;
  final MessageType messageType;
  final String mimeType;
  final int? fileSizeBytes;
  final Duration? audioDuration;
  final bool hasBlurEffect;
  final Duration? photoViewTimer;
  final DateTime createdAt;

  const MessengerPreparedMediaUpload({
    required this.uploadId,
    required this.messageId,
    required this.conversationId,
    required this.senderUserId,
    required this.localMediaPath,
    required this.storagePath,
    required this.messageType,
    required this.mimeType,
    this.fileSizeBytes,
    this.audioDuration,
    this.hasBlurEffect = false,
    this.photoViewTimer,
    required this.createdAt,
  });

  bool get isImage => messageType == MessageType.image;
  bool get isAudio => messageType == MessageType.audio;
  bool get isFile => messageType == MessageType.file;
}

@immutable
class MessengerStorageUploadResult {
  final String downloadUrl;
  final String storagePath;
  final String? thumbnailUrl;
  final String mimeType;
  final int? fileSizeBytes;

  const MessengerStorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    this.thumbnailUrl,
    required this.mimeType,
    this.fileSizeBytes,
  });
}

class MessengerStorageService {
  final FirebaseStorage _storage;

  MessengerStorageService({
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

  static const int _maxImageBytes = 15 * 1024 * 1024;
  static const int _maxAudioBytes = 50 * 1024 * 1024;
  static const int _maxFileBytes = 50 * 1024 * 1024;

  Future<MessengerStorageUploadResult> uploadPreparedMedia({
    required MessengerPreparedMediaUpload preparedUpload,
  }) async {
    _validatePreparedUpload(preparedUpload);

    final bytes = await _readLocalMediaBytes(preparedUpload.localMediaPath);
    final actualFileSizeBytes = bytes.length;

    _validateFileSize(
      preparedUpload: preparedUpload,
      actualFileSizeBytes: actualFileSizeBytes,
    );

    final metadata = SettableMetadata(
      contentType: preparedUpload.mimeType,
      customMetadata: <String, String>{
        'uploadId': preparedUpload.uploadId,
        'messageId': preparedUpload.messageId,
        'conversationId': preparedUpload.conversationId,
        'senderUserId': preparedUpload.senderUserId,
        'messageType': preparedUpload.messageType.name,
        'createdAt': preparedUpload.createdAt.toIso8601String(),
        'hasBlurEffect': preparedUpload.hasBlurEffect.toString(),
        if (preparedUpload.photoViewTimer != null)
          'photoViewTimerSeconds':
              preparedUpload.photoViewTimer!.inSeconds.toString(),
        if (preparedUpload.audioDuration != null)
          'audioDurationMilliseconds':
              preparedUpload.audioDuration!.inMilliseconds.toString(),
      },
    );

    final reference = _storage.ref().child(preparedUpload.storagePath);
    final uploadTask = reference.putData(bytes, metadata);
    final snapshot = await uploadTask.whenComplete(() {});

    final downloadUrl = await snapshot.ref.getDownloadURL();

    return MessengerStorageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: preparedUpload.storagePath,
      mimeType: preparedUpload.mimeType,
      fileSizeBytes: actualFileSizeBytes,
    );
  }

  Future<void> deleteMediaByStoragePath(String? storagePath) async {
    final cleanedPath = storagePath?.trim();
    if (cleanedPath == null || cleanedPath.isEmpty) return;
    await _storage.ref().child(cleanedPath).delete();
  }

  bool canUploadMessage(MessageModel message) {
    if (!(message.isImageMessage ||
        message.isAudioMessage ||
        message.isFileMessage)) {
      return false;
    }

    if (!message.hasLocalMediaPath) return false;
    if (!message.hasMediaStoragePath) return false;
    if (!message.hasMimeType) return false;

    final localMediaPath = message.localMediaPath?.trim();
    if (localMediaPath == null || localMediaPath.isEmpty) return false;
    if (localMediaPath.startsWith('mock://')) return false;

    return true;
  }

  Future<Uint8List> _readLocalMediaBytes(String localMediaPath) async {
    final cleanedPath = localMediaPath.trim();

    if (cleanedPath.isEmpty) {
      throw StateError('Der lokale Medienpfad ist leer.');
    }

    if (cleanedPath.startsWith('mock://')) {
      throw StateError(
        'Mock-Medien dürfen nicht in Firebase Storage hochgeladen werden.',
      );
    }

    final file = XFile(cleanedPath);
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('Die lokale Mediendatei ist leer.');
    }

    return bytes;
  }

  void _validatePreparedUpload(MessengerPreparedMediaUpload preparedUpload) {
    if (preparedUpload.uploadId.trim().isEmpty) {
      throw StateError('Upload-ID fehlt.');
    }
    if (preparedUpload.messageId.trim().isEmpty) {
      throw StateError('Message-ID fehlt.');
    }
    if (preparedUpload.conversationId.trim().isEmpty) {
      throw StateError('Conversation-ID fehlt.');
    }
    if (preparedUpload.senderUserId.trim().isEmpty) {
      throw StateError('Sender-ID fehlt.');
    }
    if (preparedUpload.localMediaPath.trim().isEmpty) {
      throw StateError('Lokaler Medienpfad fehlt.');
    }
    if (preparedUpload.storagePath.trim().isEmpty) {
      throw StateError('Storage-Pfad fehlt.');
    }
    if (preparedUpload.mimeType.trim().isEmpty) {
      throw StateError('MIME-Type fehlt.');
    }

    if (!preparedUpload.isImage &&
        !preparedUpload.isAudio &&
        !preparedUpload.isFile) {
      throw StateError('Nicht unterstützter Messenger-Upload.');
    }

    final mimeType = preparedUpload.mimeType.toLowerCase();

    if (preparedUpload.isImage && !mimeType.startsWith('image/')) {
      throw StateError('Bild-Upload hat keinen gültigen Bild-MIME-Type.');
    }

    if (preparedUpload.isAudio && !mimeType.startsWith('audio/')) {
      throw StateError('Audio-Upload hat keinen gültigen Audio-MIME-Type.');
    }

    if (preparedUpload.isFile && !_isAllowedFileMimeType(mimeType)) {
      throw StateError('Dieser Dateityp wird im Messenger nicht unterstützt.');
    }
  }

  bool _isAllowedFileMimeType(String mimeType) {
    return const <String>{
      'application/pdf',
      'text/plain',
      'text/csv',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/zip',
      'application/x-zip-compressed',
    }.contains(mimeType);
  }

  void _validateFileSize({
    required MessengerPreparedMediaUpload preparedUpload,
    required int actualFileSizeBytes,
  }) {
    if (actualFileSizeBytes <= 0) {
      throw StateError('Die Mediendatei ist leer.');
    }

    final maxBytes = preparedUpload.isImage
        ? _maxImageBytes
        : preparedUpload.isAudio
            ? _maxAudioBytes
            : _maxFileBytes;

    if (actualFileSizeBytes > maxBytes) {
      final maxMb = (maxBytes / (1024 * 1024)).round();
      throw StateError(
        'Die Datei ist zu groß. Maximal erlaubt: $maxMb MB.',
      );
    }
  }
}
