// Pfad: lib/features/profile/application/profile_friendship_controller.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/profile_friendship_repository.dart';
import '../domain/profile_friendship_model.dart';

enum ProfileFriendshipLoadState {
  initial,
  loading,
  loaded,
  error,
}

class ProfileFriendshipController extends ChangeNotifier {
  ProfileFriendshipController({
    ProfileFriendshipRepository? repository,
    FirebaseAuth? firebaseAuth,
  })  : _repository = repository ?? ProfileFriendshipRepository(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ProfileFriendshipRepository _repository;
  final FirebaseAuth _firebaseAuth;

  ProfileFriendshipLoadState _state =
      ProfileFriendshipLoadState.initial;

  ProfileFriendshipModel _relationship =
      const ProfileFriendshipModel.notFriends();

  List<String> _friendUserIds = const <String>[];
  String? _errorMessage;
  bool _disposed = false;

  ProfileFriendshipLoadState get state => _state;
  ProfileFriendshipModel get relationship => _relationship;
  List<String> get friendUserIds => _friendUserIds;
  String? get errorMessage => _errorMessage;

  int get friendsCount => _friendUserIds.length;

  Future<void> loadForProfile({
    required String viewedUserId,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    final cleanedViewedUserId = viewedUserId.trim();

    _errorMessage = null;
    _friendUserIds = const <String>[];

    if (currentUser == null || cleanedViewedUserId.isEmpty) {
      _relationship = const ProfileFriendshipModel.notFriends();
      _setState(ProfileFriendshipLoadState.loaded);
      return;
    }

    _setState(ProfileFriendshipLoadState.loading);

    try {
      final relationshipFuture = _repository.fetchRelationship(
        currentUserId: currentUser.uid,
        viewedUserId: cleanedViewedUserId,
      );

      final friendIdsFuture = _repository.fetchAcceptedFriendUserIds(
        userId: cleanedViewedUserId,
      );

      final results = await Future.wait<Object>([
        relationshipFuture,
        friendIdsFuture,
      ]);

      _relationship = results[0] as ProfileFriendshipModel;
      _friendUserIds =
          List<String>.unmodifiable(results[1] as List<String>);

      _setState(ProfileFriendshipLoadState.loaded);
    } catch (error, stackTrace) {
      debugPrint(
        'ProfileFriendshipController: '
        'Freundschaftsdaten konnten nicht geladen werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _relationship = const ProfileFriendshipModel.notFriends();
      _friendUserIds = const <String>[];
      _errorMessage =
          'Freundschaftsdaten konnten nicht geladen werden.';

      _setState(ProfileFriendshipLoadState.error);
    }
  }

  Future<void> reload({
    required String viewedUserId,
  }) {
    return loadForProfile(viewedUserId: viewedUserId);
  }

  void _setState(ProfileFriendshipLoadState nextState) {
    if (_disposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
