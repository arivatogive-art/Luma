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
  bool _isDeleting = false;
  String? _deletingPostId;
  bool _isEditing = false;
  String? _editingPostId;

  ProfilePostsLoadState get state => _state;
  List<ProfilePostModel> get posts => _posts;
  String? get errorMessage => _errorMessage;
  bool get isCreating => _isCreating;
  bool get isDeleting => _isDeleting;
  String? get deletingPostId => _deletingPostId;
  bool get isEditing => _isEditing;
  String? get editingPostId => _editingPostId;

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

  Future<bool> updatePost({
    required String currentUserId,
    required ProfilePostModel post,
    required String text,
    required ProfilePostVisibility visibility,
  }) async {
    if (_isEditing || _isDeleting) return false;

    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedPostId = post.id.trim();

    if (cleanedCurrentUserId.isEmpty || cleanedPostId.isEmpty) {
      _errorMessage = 'Der Beitrag konnte nicht eindeutig zugeordnet werden.';
      _notify();
      return false;
    }

    _isEditing = true;
    _editingPostId = cleanedPostId;
    _errorMessage = null;
    _notify();

    try {
      final updatedPost = await _repository.updatePost(
        postId: cleanedPostId,
        currentUserId: cleanedCurrentUserId,
        text: text,
        visibility: visibility,
      );

      _replacePost(updatedPost);
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'ProfilePostsController: Beitrag konnte nicht bearbeitet werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = _messageForEditError(error);
      return false;
    } finally {
      _isEditing = false;
      _editingPostId = null;
      _notify();
    }
  }

  Future<bool> deletePost({
    required String currentUserId,
    required ProfilePostModel post,
  }) async {
    if (_isDeleting) return false;

    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedPostId = post.id.trim();

    if (cleanedCurrentUserId.isEmpty || cleanedPostId.isEmpty) {
      _errorMessage = 'Der Beitrag konnte nicht eindeutig zugeordnet werden.';
      _notify();
      return false;
    }

    _isDeleting = true;
    _deletingPostId = cleanedPostId;
    _errorMessage = null;
    _notify();

    ProfilePostDeleteResult deleteResult;

    try {
      deleteResult = await _repository.deletePost(
        postId: cleanedPostId,
        currentUserId: cleanedCurrentUserId,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'ProfilePostsController: Beitrag konnte nicht gelöscht werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = _messageForDeleteError(error);
      _isDeleting = false;
      _deletingPostId = null;
      _notify();
      return false;
    }

    _removePost(cleanedPostId);

    final storagePath = deleteResult.imageStoragePath.trim();
    if (storagePath.isNotEmpty) {
      try {
        await _storageRepository.deletePostImageByStoragePath(
          storagePath: storagePath,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'ProfilePostsController: Beitragsbild konnte nach dem '
          'Löschen des Beitrags nicht aus Storage entfernt werden.',
        );
        debugPrint('$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _isDeleting = false;
    _deletingPostId = null;
    _notify();
    return true;
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

  void _replacePost(ProfilePostModel updatedPost) {
    _posts = List<ProfilePostModel>.unmodifiable(
      _posts.map(
        (post) => post.id == updatedPost.id ? updatedPost : post,
      ),
    );
    _state = ProfilePostsLoadState.loaded;
    _notify();
  }

  void _removePost(String postId) {
    _posts = List<ProfilePostModel>.unmodifiable(
      _posts.where((post) => post.id != postId),
    );
    _state = ProfilePostsLoadState.loaded;
    _notify();
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

  String _messageForEditError(Object error) {
    final value = error.toString();

    if (value.contains('profile-post-edit-not-owner')) {
      return 'Du kannst nur deine eigenen Beiträge bearbeiten.';
    }

    if (value.contains('profile-post-edit-repost-unsupported')) {
      return 'Geteilte Beiträge können hier noch nicht bearbeitet werden.';
    }

    if (value.contains('profile-post-text-too-long')) {
      return 'Dein Beitrag darf maximal 420 Zeichen enthalten.';
    }

    if (value.contains('profile-post-empty-content')) {
      return 'Ein Beitrag ohne Text oder Medien kann nicht gespeichert werden.';
    }

    if (value.contains('profile-post-not-found')) {
      return 'Dieser Beitrag ist nicht mehr verfügbar.';
    }

    if (value.contains('profile-post-missing-user-id') ||
        value.contains('profile-post-missing-post-id')) {
      return 'Der Beitrag konnte nicht eindeutig zugeordnet werden.';
    }

    return 'Der Beitrag konnte gerade nicht gespeichert werden.';
  }

  String _messageForDeleteError(Object error) {
    final value = error.toString();

    if (value.contains('profile-post-delete-not-owner')) {
      return 'Du kannst nur deine eigenen Beiträge löschen.';
    }

    if (value.contains('profile-post-missing-user-id') ||
        value.contains('profile-post-missing-post-id')) {
      return 'Der Beitrag konnte nicht eindeutig zugeordnet werden.';
    }

    return 'Der Beitrag konnte gerade nicht gelöscht werden.';
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
