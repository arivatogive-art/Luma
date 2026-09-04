// Pfad: lib/features/profile/application/profile_media_controller.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile_repository.dart';
import '../data/profile_storage_repository.dart';

enum ProfileMediaOperation {
  idle,
  uploadingAvatar,
  uploadingCover,
  removingAvatar,
  removingCover,
  success,
  error,
}

class ProfileMediaController extends ChangeNotifier {
  ProfileMediaController({
    ProfileStorageRepository? storageRepository,
    ProfileRepository? profileRepository,
    FirebaseAuth? firebaseAuth,
  })  : _storageRepository =
            storageRepository ?? ProfileStorageRepository(),
        _profileRepository =
            profileRepository ?? ProfileRepository(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ProfileStorageRepository _storageRepository;
  final ProfileRepository _profileRepository;
  final FirebaseAuth _firebaseAuth;

  ProfileMediaOperation _operation = ProfileMediaOperation.idle;
  String? _errorMessage;
  bool _disposed = false;

  ProfileMediaOperation get operation => _operation;
  String? get errorMessage => _errorMessage;

  bool get isBusy =>
      _operation == ProfileMediaOperation.uploadingAvatar ||
      _operation == ProfileMediaOperation.uploadingCover ||
      _operation == ProfileMediaOperation.removingAvatar ||
      _operation == ProfileMediaOperation.removingCover;

  Future<bool> uploadAvatar(XFile file) async {
    final uid = _currentUid;
    if (uid.isEmpty || isBusy) return false;

    _errorMessage = null;
    _setOperation(ProfileMediaOperation.uploadingAvatar);

    try {
      final url = await _storageRepository.uploadAvatar(
        userId: uid,
        imageFile: file,
      );

      await _profileRepository.updateAvatarUrl(
        uid: uid,
        avatarUrl: url,
      );

      _setOperation(ProfileMediaOperation.success);
      return true;
    } catch (error, stackTrace) {
      debugPrint('ProfileMediaController avatar upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Profilbild konnte nicht gespeichert werden.';
      _setOperation(ProfileMediaOperation.error);
      return false;
    }
  }

  Future<bool> uploadCover(XFile file) async {
    final uid = _currentUid;
    if (uid.isEmpty || isBusy) return false;

    _errorMessage = null;
    _setOperation(ProfileMediaOperation.uploadingCover);

    try {
      final url = await _storageRepository.uploadCover(
        userId: uid,
        imageFile: file,
      );

      await _profileRepository.updateCoverUrl(
        uid: uid,
        coverUrl: url,
      );

      _setOperation(ProfileMediaOperation.success);
      return true;
    } catch (error, stackTrace) {
      debugPrint('ProfileMediaController cover upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Titelbild konnte nicht gespeichert werden.';
      _setOperation(ProfileMediaOperation.error);
      return false;
    }
  }

  Future<bool> removeAvatar() async {
    final uid = _currentUid;
    if (uid.isEmpty || isBusy) return false;

    _errorMessage = null;
    _setOperation(ProfileMediaOperation.removingAvatar);

    try {
      await _profileRepository.updateAvatarUrl(
        uid: uid,
        avatarUrl: '',
      );

      await _storageRepository.deleteAvatar(
        userId: uid,
      );

      _setOperation(ProfileMediaOperation.success);
      return true;
    } catch (error, stackTrace) {
      debugPrint('ProfileMediaController avatar remove failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Profilbild konnte nicht entfernt werden.';
      _setOperation(ProfileMediaOperation.error);
      return false;
    }
  }

  Future<bool> removeCover() async {
    final uid = _currentUid;
    if (uid.isEmpty || isBusy) return false;

    _errorMessage = null;
    _setOperation(ProfileMediaOperation.removingCover);

    try {
      await _profileRepository.updateCoverUrl(
        uid: uid,
        coverUrl: '',
      );

      await _storageRepository.deleteCover(
        userId: uid,
      );

      _setOperation(ProfileMediaOperation.success);
      return true;
    } catch (error, stackTrace) {
      debugPrint('ProfileMediaController cover remove failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Titelbild konnte nicht entfernt werden.';
      _setOperation(ProfileMediaOperation.error);
      return false;
    }
  }

  String get _currentUid =>
      _firebaseAuth.currentUser?.uid.trim() ?? '';

  void reset() {
    _errorMessage = null;
    _setOperation(ProfileMediaOperation.idle);
  }

  void _setOperation(ProfileMediaOperation next) {
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
