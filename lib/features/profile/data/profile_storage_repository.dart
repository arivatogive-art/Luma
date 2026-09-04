// Pfad: lib/features/profile/data/profile_storage_repository.dart

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileStorageRepository {
  ProfileStorageRepository({
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadAvatar({
    required String userId,
    required XFile imageFile,
  }) {
    return _uploadProfileImage(
      userId: userId,
      imageFile: imageFile,
      storagePath: 'profile_media/${userId.trim()}/avatar/image.jpg',
    );
  }

  Future<String> uploadCover({
    required String userId,
    required XFile imageFile,
  }) {
    return _uploadProfileImage(
      userId: userId,
      imageFile: imageFile,
      storagePath: 'profile_media/${userId.trim()}/cover/image.jpg',
    );
  }

  Future<void> deleteAvatar({
    required String userId,
  }) {
    return _deleteSafely(
      'profile_media/${userId.trim()}/avatar/image.jpg',
    );
  }

  Future<void> deleteCover({
    required String userId,
  }) {
    return _deleteSafely(
      'profile_media/${userId.trim()}/cover/image.jpg',
    );
  }

  Future<String> _uploadProfileImage({
    required String userId,
    required XFile imageFile,
    required String storagePath,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User ID darf nicht leer sein.',
      );
    }

    final bytes = await imageFile.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('Die ausgewählte Bilddatei ist leer.');
    }

    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError(
        'Das Bild ist größer als 10 MB.',
      );
    }

    final reference = _storage.ref(storagePath);

    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: <String, String>{
          'userId': cleanedUserId,
          'purpose': storagePath.contains('/avatar/')
              ? 'profileAvatar'
              : 'profileCover',
        },
      ),
    );

    return reference.getDownloadURL();
  }

  Future<void> _deleteSafely(String storagePath) async {
    if (storagePath.trim().isEmpty) return;

    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }
      rethrow;
    }
  }
}
