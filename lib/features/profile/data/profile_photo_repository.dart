// Pfad: lib/features/profile/data/profile_photo_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/profile_photo_model.dart';

class ProfilePhotoRepository {
  ProfilePhotoRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _photosRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('profilePhotos');
  }

  Future<List<ProfilePhotoModel>> fetchProfilePhotos({
    required String userId,
    int limit = 60,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) {
      return const <ProfilePhotoModel>[];
    }

    final safeLimit = limit.clamp(1, 120).toInt();

    final snapshot = await _photosRef(cleanedUserId)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return snapshot.docs
        .map(
          (document) => ProfilePhotoModel.fromFirestore(
            id: document.id,
            userId: cleanedUserId,
            data: document.data(),
          ),
        )
        .where((photo) => photo.hasImage)
        .toList(growable: false);
  }

  Stream<List<ProfilePhotoModel>> watchProfilePhotos({
    required String userId,
    int limit = 60,
  }) {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return Stream<List<ProfilePhotoModel>>.value(
        const <ProfilePhotoModel>[],
      );
    }

    final safeLimit = limit.clamp(1, 120).toInt();

    return _photosRef(cleanedUserId)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => ProfilePhotoModel.fromFirestore(
                  id: document.id,
                  userId: cleanedUserId,
                  data: document.data(),
                ),
              )
              .where((photo) => photo.hasImage)
              .toList(growable: false),
        );
  }

  Future<ProfilePhotoModel> uploadProfilePhoto({
    required String userId,
    required XFile imageFile,
    String caption = '',
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
      throw StateError('Das Bild ist größer als 10 MB.');
    }

    final contentType = _detectImageContentType(bytes);
    if (contentType == null) {
      throw StateError(
        'Dieses Bildformat wird nicht unterstützt. '
        'Erlaubt sind JPEG, PNG und WebP.',
      );
    }

    final documentRef = _photosRef(cleanedUserId).doc();
    final photoId = documentRef.id;

    final storagePath =
        'profile_media/$cleanedUserId/gallery/$photoId/image.jpg';

    final storageRef = _storage.ref(storagePath);

    try {
      await storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          customMetadata: <String, String>{
            'userId': cleanedUserId,
            'photoId': photoId,
            'purpose': 'profileGallery',
          },
        ),
      );

      final imageUrl = await storageRef.getDownloadURL();
      final now = DateTime.now();

      final photo = ProfilePhotoModel(
        id: photoId,
        userId: cleanedUserId,
        imageUrl: imageUrl,
        storagePath: storagePath,
        type: ProfilePhotoType.upload,
        caption: caption.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await documentRef.set(photo.toFirestore());

      return photo;
    } catch (_) {
      try {
        await storageRef.delete();
      } on FirebaseException catch (cleanupError) {
        if (cleanupError.code != 'object-not-found') {
          // Der ursprüngliche Fehler bleibt maßgeblich.
        }
      }

      rethrow;
    }
  }

  Future<void> deleteProfilePhoto({
    required String userId,
    required ProfilePhotoModel photo,
  }) async {
    final cleanedUserId = userId.trim();
    final cleanedPhotoId = photo.id.trim();

    if (cleanedUserId.isEmpty || cleanedPhotoId.isEmpty) {
      return;
    }

    if (photo.userId.trim().isNotEmpty &&
        photo.userId.trim() != cleanedUserId) {
      throw StateError(
        'Dieses Foto gehört nicht zum aktuellen Profil.',
      );
    }

    await _photosRef(cleanedUserId).doc(cleanedPhotoId).delete();

    final storagePath = photo.storagePath.trim();
    if (storagePath.isEmpty) return;

    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return;

      // Der Firestore-Eintrag ist bereits gelöscht. Ein Fehler beim
      // anschließenden Storage-Cleanup darf deshalb den erfolgreichen
      // Löschvorgang im Profil nicht wieder als fehlgeschlagen melden.
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
