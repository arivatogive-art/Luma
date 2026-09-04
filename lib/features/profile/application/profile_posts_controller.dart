// Pfad: lib/features/profile/application/profile_posts_controller.dart

import 'package:flutter/foundation.dart';

import '../data/profile_post_repository.dart';
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
  }) : _repository = repository ?? ProfilePostRepository();

  final ProfilePostRepository _repository;

  ProfilePostsLoadState _state = ProfilePostsLoadState.initial;
  List<ProfilePostModel> _posts = const <ProfilePostModel>[];
  String? _errorMessage;
  bool _disposed = false;

  ProfilePostsLoadState get state => _state;
  List<ProfilePostModel> get posts => _posts;
  String? get errorMessage => _errorMessage;

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
      debugPrint('ProfilePostsController: Beiträge konnten nicht geladen werden.');
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _posts = const <ProfilePostModel>[];
      _errorMessage = 'Beiträge konnten nicht geladen werden.';
      _setState(ProfilePostsLoadState.error);
    }
  }

  void _setState(ProfilePostsLoadState nextState) {
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
