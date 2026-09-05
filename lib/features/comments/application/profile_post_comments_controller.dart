// Pfad: lib/features/comments/application/profile_post_comments_controller.dart

import 'package:flutter/foundation.dart';

import '../data/profile_post_comments_repository.dart';
import '../domain/profile_post_comment_model.dart';

enum ProfilePostCommentsLoadState {
  initial,
  loading,
  loaded,
  error,
}

class ProfilePostCommentsController extends ChangeNotifier {
  ProfilePostCommentsController({
    ProfilePostCommentsRepository? repository,
  }) : _repository = repository ?? ProfilePostCommentsRepository();

  final ProfilePostCommentsRepository _repository;

  ProfilePostCommentsLoadState _state = ProfilePostCommentsLoadState.initial;
  List<ProfilePostCommentModel> _comments =
      const <ProfilePostCommentModel>[];
  String? _errorMessage;
  bool _disposed = false;

  ProfilePostCommentsLoadState get state => _state;
  List<ProfilePostCommentModel> get comments => _comments;
  String? get errorMessage => _errorMessage;

  bool get isLoading =>
      _state == ProfilePostCommentsLoadState.initial ||
      _state == ProfilePostCommentsLoadState.loading;

  List<ProfilePostCommentModel> get rootComments {
    if (_comments.isEmpty) {
      return const <ProfilePostCommentModel>[];
    }

    final visibleIds = _comments.map((comment) => comment.id).toSet();

    return List<ProfilePostCommentModel>.unmodifiable(
      _comments.where((comment) {
        final parentId = comment.parentCommentId?.trim() ?? '';

        return parentId.isEmpty || !visibleIds.contains(parentId);
      }),
    );
  }

  List<ProfilePostCommentModel> repliesFor(String parentCommentId) {
    final cleanedParentId = parentCommentId.trim();

    if (cleanedParentId.isEmpty) {
      return const <ProfilePostCommentModel>[];
    }

    return List<ProfilePostCommentModel>.unmodifiable(
      _comments.where(
        (comment) => comment.parentCommentId?.trim() == cleanedParentId,
      ),
    );
  }

  Future<void> load({
    required String postId,
  }) async {
    _comments = const <ProfilePostCommentModel>[];
    _errorMessage = null;
    _setState(ProfilePostCommentsLoadState.loading);

    try {
      _comments = await _repository.fetchComments(
        postId: postId,
        limit: 100,
      );

      _setState(ProfilePostCommentsLoadState.loaded);
    } catch (error, stackTrace) {
      debugPrint(
        'ProfilePostCommentsController: Kommentare konnten nicht geladen werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _comments = const <ProfilePostCommentModel>[];
      _errorMessage = 'Kommentare konnten nicht geladen werden.';
      _setState(ProfilePostCommentsLoadState.error);
    }
  }

  Future<void> reload({
    required String postId,
  }) {
    return load(postId: postId);
  }

  void _setState(ProfilePostCommentsLoadState nextState) {
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
