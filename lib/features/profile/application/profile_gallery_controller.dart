// Pfad: lib/features/profile/application/profile_gallery_controller.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile_photo_repository.dart';
import '../domain/profile_photo_model.dart';

enum ProfileGalleryOperation {
  idle,
  uploading,
  deleting,
  error,
}

class ProfileGalleryController extends ChangeNotifier {
  ProfileGalleryController({
    ProfilePhotoRepository? repository,
    FirebaseAuth? firebaseAuth,
  })  : _repository = repository ?? ProfilePhotoRepository(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ProfilePhotoRepository _repository;
  final FirebaseAuth _firebaseAuth;

  ProfileGalleryOperation _operation =
      ProfileGalleryOperation.idle;
  String? _errorMessage;
  bool _disposed = false;

  ProfileGalleryOperation get operation => _operation;
  String? get errorMessage => _errorMessage;

  bool get isBusy =>
      _operation == ProfileGalleryOperation.uploading ||
      _operation == ProfileGalleryOperation.deleting;

  Future<bool> upload({
    required String profileUserId,
    required XFile file,
    String caption = '',
  }) async {
    final uid = _firebaseAuth.currentUser?.uid.trim() ?? '';
    final cleanedProfileUserId = profileUserId.trim();

    if (uid.isEmpty ||
        cleanedProfileUserId.isEmpty ||
        uid != cleanedProfileUserId ||
        isBusy) {
      return false;
    }

    _errorMessage = null;
    _setOperation(ProfileGalleryOperation.uploading);

    try {
      await _repository.uploadProfilePhoto(
        userId: uid,
        imageFile: file,
        caption: caption,
      );

      _setOperation(ProfileGalleryOperation.idle);
      return true;
    } catch (error, stackTrace) {
      debugPrint('ProfileGalleryController upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = _galleryErrorMessage(error);
      _setOperation(ProfileGalleryOperation.error);
      return false;
    }
  }

  Future<bool> delete({
    required String profileUserId,
    required ProfilePhotoModel photo,
  }) async {
    final uid = _firebaseAuth.currentUser?.uid.trim() ?? '';
    final cleanedProfileUserId = profileUserId.trim();

    if (uid.isEmpty ||
        cleanedProfileUserId.isEmpty ||
        uid != cleanedProfileUserId ||
        isBusy) {
      return false;
    }

    _errorMessage = null;
    _setOperation(ProfileGalleryOperation.deleting);

    try {
      await _repository.deleteProfilePhoto(
        userId: uid,
        photo: photo,
      );

      _setOperation(ProfileGalleryOperation.idle);
      return true;
    } catch (error, stackTrace) {
      debugPrint('ProfileGalleryController delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = 'Das Foto konnte nicht entfernt werden.';
      _setOperation(ProfileGalleryOperation.error);
      return false;
    }
  }

  String _galleryErrorMessage(Object error) {
    if (error is StateError) {
      final message = error.message.toString().trim();
      if (message.isNotEmpty) return message;
    }

    return 'Das Foto konnte nicht hinzugefügt werden.';
  }

  void _setOperation(ProfileGalleryOperation next) {
    if (_disposed) return;
    _operation = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
