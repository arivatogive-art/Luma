// Pfad: lib/application/messenger_media_pending_message_factory.dart

import '../domain/models/message_model.dart';
import 'messenger_media_upload_service.dart';

class MessengerMediaPendingMessageFactory {
  const MessengerMediaPendingMessageFactory();

  MessageModel createQueuedImageMessage({
    required MessengerPreparedMediaUpload preparedUpload,
  }) {
    return preparedUpload.toPendingMessage().copyWith(
          mediaTransferState: MediaTransferState.loading,
          mediaUploadState: MediaUploadState.queued,
          deliveryStatus: MessageDeliveryStatus.sending,
        );
  }

  MessageModel createUploadingImageMessage({
    required MessageModel message,
  }) {
    return message.copyWith(
      mediaTransferState: MediaTransferState.loading,
      mediaUploadState: MediaUploadState.uploading,
      deliveryStatus: MessageDeliveryStatus.sending,
      clearUploadFailureReason: true,
    );
  }

  MessageModel createUploadedImageMessage({
    required MessageModel message,
    required String remoteImageUrl,
    String? thumbnailUrl,
  }) {
    return message.copyWith(
      imageUrl: remoteImageUrl.trim(),
      thumbnailUrl: thumbnailUrl,
      mediaTransferState: MediaTransferState.success,
      mediaUploadState: MediaUploadState.uploaded,
      deliveryStatus: MessageDeliveryStatus.sent,
      clearUploadFailureReason: true,
    );
  }

  MessageModel createFailedImageMessage({
    required MessageModel message,
    required String failureReason,
  }) {
    return message.copyWith(
      mediaTransferState: MediaTransferState.failed,
      mediaUploadState: MediaUploadState.failed,
      deliveryStatus: MessageDeliveryStatus.failed,
      uploadFailureReason: failureReason.trim(),
    );
  }

  MessageModel createQueuedAudioMessage({
    required MessengerPreparedMediaUpload preparedUpload,
  }) {
    return preparedUpload.toPendingMessage().copyWith(
          mediaTransferState: MediaTransferState.loading,
          mediaUploadState: MediaUploadState.queued,
          deliveryStatus: MessageDeliveryStatus.sending,
        );
  }

  MessageModel createUploadingAudioMessage({
    required MessageModel message,
  }) {
    return message.copyWith(
      mediaTransferState: MediaTransferState.loading,
      mediaUploadState: MediaUploadState.uploading,
      deliveryStatus: MessageDeliveryStatus.sending,
      clearUploadFailureReason: true,
    );
  }

  MessageModel createUploadedAudioMessage({
    required MessageModel message,
    required String remoteAudioUrl,
  }) {
    return message.copyWith(
      imageUrl: remoteAudioUrl.trim(),
      mediaTransferState: MediaTransferState.success,
      mediaUploadState: MediaUploadState.uploaded,
      deliveryStatus: MessageDeliveryStatus.sent,
      clearUploadFailureReason: true,
    );
  }

  MessageModel createFailedAudioMessage({
    required MessageModel message,
    required String failureReason,
  }) {
    return message.copyWith(
      mediaTransferState: MediaTransferState.failed,
      mediaUploadState: MediaUploadState.failed,
      deliveryStatus: MessageDeliveryStatus.failed,
      uploadFailureReason: failureReason.trim(),
    );
  }

  MessageModel createQueuedFileMessage({
    required MessengerPreparedMediaUpload preparedUpload,
    required String fileName,
  }) {
    final cleanFileName = fileName.trim().isEmpty ? 'Datei' : fileName.trim();

    return preparedUpload.toPendingMessage().copyWith(
          text: cleanFileName,
          mediaTransferState: MediaTransferState.loading,
          mediaUploadState: MediaUploadState.queued,
          deliveryStatus: MessageDeliveryStatus.sending,
        );
  }

  MessageModel createUploadingFileMessage({
    required MessageModel message,
  }) {
    return message.copyWith(
      mediaTransferState: MediaTransferState.loading,
      mediaUploadState: MediaUploadState.uploading,
      deliveryStatus: MessageDeliveryStatus.sending,
      clearUploadFailureReason: true,
    );
  }

  MessageModel createUploadedFileMessage({
    required MessageModel message,
    required String remoteFileUrl,
  }) {
    return message.copyWith(
      imageUrl: remoteFileUrl.trim(),
      mediaTransferState: MediaTransferState.success,
      mediaUploadState: MediaUploadState.uploaded,
      deliveryStatus: MessageDeliveryStatus.sent,
      clearUploadFailureReason: true,
    );
  }

  MessageModel createFailedFileMessage({
    required MessageModel message,
    required String failureReason,
  }) {
    return message.copyWith(
      mediaTransferState: MediaTransferState.failed,
      mediaUploadState: MediaUploadState.failed,
      deliveryStatus: MessageDeliveryStatus.failed,
      uploadFailureReason: failureReason.trim(),
    );
  }
}
