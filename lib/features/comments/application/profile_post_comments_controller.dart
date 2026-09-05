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
  bool _isSending = false;
  String? _sendErrorMessage;
  String? _replyingToCommentId;
  bool _disposed = false;

  ProfilePostCommentsLoadState get state => _state;
  List<ProfilePostCommentModel> get comments => _comments;
  String? get errorMessage => _errorMessage;
  bool get isSending => _isSending;
  String? get sendErrorMessage => _sendErrorMessage;
  String? get replyingToCommentId => _replyingToCommentId;

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

  Future<bool> createComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String authorAvatarUrl,
    required String text,
  }) {
    return _send(
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      text: text,
      parentCommentId: null,
    );
  }

  Future<bool> createReply({
    required String postId,
    required String parentCommentId,
    required String authorId,
    required String authorName,
    required String authorAvatarUrl,
    required String text,
  }) {
    return _send(
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      text: text,
      parentCommentId: parentCommentId,
    );
  }

  Future<bool> _send({
    required String postId,
    required String authorId,
    required String authorName,
    required String authorAvatarUrl,
    required String text,
    required String? parentCommentId,
  }) async {
    if (_isSending) return false;

    final cleanedText = text.trim();

    if (cleanedText.isEmpty) {
      _sendErrorMessage = parentCommentId == null
          ? 'Schreibe zuerst einen Kommentar.'
          : 'Schreibe zuerst eine Antwort.';
      _notify();
      return false;
    }

    if (cleanedText.length > 500) {
      _sendErrorMessage = parentCommentId == null
          ? 'Ein Kommentar darf höchstens 500 Zeichen haben.'
          : 'Eine Antwort darf höchstens 500 Zeichen haben.';
      _notify();
      return false;
    }

    _isSending = true;
    _replyingToCommentId = parentCommentId?.trim();
    _sendErrorMessage = null;
    _notify();

    try {
      if (parentCommentId == null) {
        await _repository.createComment(
          postId: postId,
          authorId: authorId,
          authorName: authorName,
          authorAvatarUrl: authorAvatarUrl,
          text: cleanedText,
        );
      } else {
        await _repository.createReply(
          postId: postId,
          parentCommentId: parentCommentId,
          authorId: authorId,
          authorName: authorName,
          authorAvatarUrl: authorAvatarUrl,
          text: cleanedText,
        );
      }

      await _reloadAfterCreate(postId: postId);
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        parentCommentId == null
            ? 'ProfilePostCommentsController: Kommentar konnte nicht gesendet werden.'
            : 'ProfilePostCommentsController: Antwort konnte nicht gesendet werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _sendErrorMessage = parentCommentId == null
          ? 'Kommentar konnte nicht gesendet werden.'
          : 'Antwort konnte nicht gesendet werden.';
      return false;
    } finally {
      _isSending = false;
      _replyingToCommentId = null;
      _notify();
    }
  }

  Future<void> _reloadAfterCreate({
    required String postId,
  }) async {
    try {
      _comments = await _repository.fetchComments(
        postId: postId,
        limit: 100,
      );
      _errorMessage = null;
      _state = ProfilePostCommentsLoadState.loaded;
    } catch (error, stackTrace) {
      debugPrint(
        'ProfilePostCommentsController: Kommentar wurde gespeichert, '
        'aber die Liste konnte nicht neu geladen werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = 'Kommentare konnten nicht neu geladen werden.';
      _state = ProfilePostCommentsLoadState.error;
    }

    _notify();
  }

  void clearSendError() {
    if (_sendErrorMessage == null) return;
    _sendErrorMessage = null;
    _notify();
  }

  void _setState(ProfilePostCommentsLoadState nextState) {
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
