// Pfad: lib/features/profile/application/profile_posts_controller.dart

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile_post_repository.dart';
import '../data/profile_post_storage_repository.dart';
import '../domain/profile_post_model.dart';

enum ProfilePostsLoadState {
  initial,
  loading,
  loaded,
  error,
}

class ProfilePostsController extends ChangeNotifier {
  ProfilePostsController({
    ProfilePostRepository? repository,
    ProfilePostStorageRepository? storageRepository,
  })  : _repository = repository ?? ProfilePostRepository(),
        _storageRepository =
            storageRepository ?? ProfilePostStorageRepository();

  final ProfilePostRepository _repository;
  final ProfilePostStorageRepository _storageRepository;

  ProfilePostsLoadState _state = ProfilePostsLoadState.initial;
  List<ProfilePostModel> _posts = const <ProfilePostModel>[];
  String? _errorMessage;
  bool _disposed = false;
  bool _isCreating = false;

  ProfilePostsLoadState get state => _state;
  List<ProfilePostModel> get posts => _posts;
  String? get errorMessage => _errorMessage;
  bool get isCreating => _isCreating;

  bool get isLoading =>
      _state == ProfilePostsLoadState.initial ||
      _state == ProfilePostsLoadState.loading;

  Future<void> load({
    required String profileUserId,
    required String currentUserId,
    required bool areFriends,
  }) async {
    _posts = const <ProfilePostModel>[];
    _errorMessage = null;
    _setState(ProfilePostsLoadState.loading);

    try {
      _posts = await _repository.fetchProfilePosts(
        profileUserId: profileUserId,
        currentUserId: currentUserId,
        areFriends: areFriends,
        limit: 20,
      );
      _setState(ProfilePostsLoadState.loaded);
    } catch (error, stackTrace) {
      debugPrint(
        'ProfilePostsController: Beiträge konnten nicht geladen werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _posts = const <ProfilePostModel>[];
      _errorMessage = 'Beiträge konnten nicht geladen werden.';
      _setState(ProfilePostsLoadState.error);
    }
  }

  Future<bool> createTextPost({
    required String currentUserId,
    required String username,
    required String userAvatarUrl,
    required String text,
    required ProfilePostVisibility visibility,
  }) async {
    if (_isCreating) return false;

    _isCreating = true;
    _errorMessage = null;
    _notify();

    try {
      final createdPost = await _repository.createTextPost(
        currentUserId: currentUserId,
        username: username,
        userAvatarUrl: userAvatarUrl,
        text: text,
        visibility: visibility,
      );

      _prependPost(createdPost);
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'ProfilePostsController: Beitrag konnte nicht erstellt werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = _messageForCreateError(error);
      return false;
    } finally {
      _isCreating = false;
      _notify();
    }
  }

  Future<bool> createImagePost({
    required String currentUserId,
    required String username,
    required String userAvatarUrl,
    required String text,
    required XFile imageFile,
    required ProfilePostVisibility visibility,
  }) async {
    if (_isCreating) return false;

    _isCreating = true;
    _errorMessage = null;
    _notify();

    final postId = _repository.createPostId();
    ProfilePostImageUploadResult? uploadedImage;

    try {
      uploadedImage = await _storageRepository.uploadPostImage(
        userId: currentUserId,
        postId: postId,
        imageFile: imageFile,
      );

      final createdPost = await _repository.createImagePost(
        postId: postId,
        currentUserId: currentUserId,
        username: username,
        userAvatarUrl: userAvatarUrl,
        text: text,
        imageUrl: uploadedImage.downloadUrl,
        imageStoragePath: uploadedImage.storagePath,
        visibility: visibility,
      );

      _prependPost(createdPost);
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'ProfilePostsController: Bildbeitrag konnte nicht erstellt werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      if (uploadedImage != null) {
        try {
          await _storageRepository.deletePostImageByStoragePath(
            storagePath: uploadedImage.storagePath,
          );
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint(
            'ProfilePostsController: Hochgeladenes Beitragsbild '
            'konnte nach Fehler nicht entfernt werden.',
          );
          debugPrint('$cleanupError');
          debugPrintStack(stackTrace: cleanupStackTrace);
        }
      }

      _errorMessage = _messageForCreateError(error);
      return false;
    } finally {
      _isCreating = false;
      _notify();
    }
  }

  void _prependPost(ProfilePostModel createdPost) {
    _posts = List<ProfilePostModel>.unmodifiable(
      <ProfilePostModel>[
        createdPost,
        ..._posts.where((post) => post.id != createdPost.id),
      ],
    );

    _state = ProfilePostsLoadState.loaded;
  }

  String _messageForCreateError(Object error) {
    final value = error.toString();

    if (value.contains('profile-post-empty-text')) {
      return 'Schreibe zuerst etwas.';
    }

    if (value.contains('profile-post-text-too-long')) {
      return 'Dein Beitrag darf maximal 420 Zeichen enthalten.';
    }

    if (value.contains('profile-post-image-empty')) {
      return 'Das ausgewählte Bild ist leer.';
    }

    if (value.contains('profile-post-image-too-large')) {
      return 'Das Bild darf maximal 10 MB groß sein.';
    }

    if (value.contains('profile-post-image-unsupported')) {
      return 'Dieses Bildformat wird nicht unterstützt. '
          'Erlaubt sind JPEG, PNG und WebP.';
    }

    if (value.contains('profile-post-missing-image')) {
      return 'Das Bild konnte nicht für den Beitrag übernommen werden.';
    }

    if (value.contains('profile-post-missing-user-id') ||
        value.contains('profile-post-missing-username') ||
        value.contains('profile-post-missing-post-id')) {
      return 'Dein Profil konnte nicht eindeutig zugeordnet werden.';
    }

    return 'Dein Beitrag konnte gerade nicht veröffentlicht werden.';
  }

  void _setState(ProfilePostsLoadState nextState) {
    if (_disposed) return;
    _state = nextState;
    notifyListeners();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
