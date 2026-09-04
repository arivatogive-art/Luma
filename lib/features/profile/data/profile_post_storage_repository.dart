// Pfad: lib/features/profile/data/profile_post_storage_repository.dart

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePostImageUploadResult {
  const ProfilePostImageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}

class ProfilePostStorageRepository {
  ProfilePostStorageRepository({
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

  static const int _maxImageBytes = 10 * 1024 * 1024;

  final FirebaseStorage _storage;

  Future<ProfilePostImageUploadResult> uploadPostImage({
    required String userId,
    required String postId,
    required XFile imageFile,
  }) async {
    final cleanedUserId = userId.trim();
    final cleanedPostId = postId.trim();

    if (cleanedUserId.isEmpty) {
      throw StateError('profile-post-missing-user-id');
    }

    if (cleanedPostId.isEmpty) {
      throw StateError('profile-post-missing-post-id');
    }

    final bytes = await imageFile.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('profile-post-image-empty');
    }

    if (bytes.length > _maxImageBytes) {
      throw StateError('profile-post-image-too-large');
    }

    final contentType = _detectImageContentType(bytes);
    if (contentType == null) {
      throw StateError('profile-post-image-unsupported');
    }

    final storagePath =
        'feed_images/$cleanedUserId/$cleanedPostId/image.jpg';
    final reference = _storage.ref(storagePath);

    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          'userId': cleanedUserId,
          'postId': cleanedPostId,
          'purpose': 'feedPostImage',
        },
      ),
    );

    final downloadUrl = await reference.getDownloadURL();

    return ProfilePostImageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
    );
  }

  Future<void> deletePostImage({
    required String userId,
    required String postId,
  }) {
    final cleanedUserId = userId.trim();
    final cleanedPostId = postId.trim();

    if (cleanedUserId.isEmpty || cleanedPostId.isEmpty) {
      return Future<void>.value();
    }

    return deletePostImageByStoragePath(
      storagePath:
          'feed_images/$cleanedUserId/$cleanedPostId/image.jpg',
    );
  }

  Future<void> deletePostImageByStoragePath({
    required String storagePath,
  }) async {
    final cleanedStoragePath = storagePath.trim();
    if (cleanedStoragePath.isEmpty) return;

    try {
      await _storage.ref(cleanedStoragePath).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }
      rethrow;
    }
  }

  String? _detectImageContentType(List<int> bytes) {
    if (_isJpeg(bytes)) return 'image/jpeg';
    if (_isPng(bytes)) return 'image/png';
    if (_isWebP(bytes)) return 'image/webp';
    return null;
  }

  bool _isJpeg(List<int> bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  bool _isPng(List<int> bytes) {
    const signature = <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ];

    if (bytes.length < signature.length) return false;

    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }

    return true;
  }

  bool _isWebP(List<int> bytes) {
    if (bytes.length < 12) return false;

    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }
}
