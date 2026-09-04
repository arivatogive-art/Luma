// Pfad: lib/features/profile/application/profile_photos_controller.dart

import 'package:flutter/foundation.dart';

import '../data/profile_photo_repository.dart';
import '../domain/profile_photo_model.dart';

enum ProfilePhotosLoadState {
  initial,
  loading,
  loaded,
  hidden,
  error,
}

class ProfilePhotosController extends ChangeNotifier {
  ProfilePhotosController({
    ProfilePhotoRepository? repository,
  }) : _repository = repository ?? ProfilePhotoRepository();

  final ProfilePhotoRepository _repository;

  ProfilePhotosLoadState _state = ProfilePhotosLoadState.initial;
  List<ProfilePhotoModel> _photos = const <ProfilePhotoModel>[];
  String? _errorMessage;
  String _loadedUserId = '';
  bool _disposed = false;

  ProfilePhotosLoadState get state => _state;
  List<ProfilePhotoModel> get photos => _photos;
  String? get errorMessage => _errorMessage;
  String get loadedUserId => _loadedUserId;

  bool get isLoading =>
      _state == ProfilePhotosLoadState.initial ||
      _state == ProfilePhotosLoadState.loading;

  Future<void> load({
    required String userId,
    required bool canView,
  }) async {
    final cleanedUserId = userId.trim();
    _loadedUserId = cleanedUserId;
    _errorMessage = null;

    if (cleanedUserId.isEmpty) {
      _photos = const <ProfilePhotoModel>[];
      _setState(ProfilePhotosLoadState.loaded);
      return;
    }

    if (!canView) {
      _photos = const <ProfilePhotoModel>[];
      _setState(ProfilePhotosLoadState.hidden);
      return;
    }

    _photos = const <ProfilePhotoModel>[];
    _setState(ProfilePhotosLoadState.loading);

    try {
      _photos = await _repository.fetchProfilePhotos(
        userId: cleanedUserId,
        limit: 12,
      );
      _setState(ProfilePhotosLoadState.loaded);
    } catch (error, stackTrace) {
      debugPrint('ProfilePhotosController: Fotos konnten nicht geladen werden.');
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _photos = const <ProfilePhotoModel>[];
      _errorMessage = 'Fotos konnten nicht geladen werden.';
      _setState(ProfilePhotosLoadState.error);
    }
  }

  void _setState(ProfilePhotosLoadState nextState) {
    if (_disposed) return;
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
