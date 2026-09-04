// Pfad: lib/features/profile/application/profile_controller.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

enum ProfileLoadState {
  initial,
  loading,
  loaded,
  notFound,
  error,
}

class ProfileController extends ChangeNotifier {
  ProfileController({
    ProfileRepository? repository,
    FirebaseAuth? firebaseAuth,
  })  : _repository = repository ?? ProfileRepository(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ProfileRepository _repository;
  final FirebaseAuth _firebaseAuth;

  ProfileLoadState _state = ProfileLoadState.initial;
  ProfileModel? _profile;
  String? _errorMessage;
  String _loadedUserId = '';
  bool _disposed = false;

  ProfileLoadState get state => _state;
  ProfileModel? get profile => _profile;
  String? get errorMessage => _errorMessage;
  String get loadedUserId => _loadedUserId;

  String get currentUserId => _firebaseAuth.currentUser?.uid.trim() ?? '';

  bool get isOwnProfile {
    final currentUid = currentUserId;
    return currentUid.isNotEmpty &&
        _loadedUserId.isNotEmpty &&
        currentUid == _loadedUserId;
  }

  Future<void> loadCurrentProfile() {
    return loadProfile();
  }

  Future<void> loadProfile({
    String? userId,
  }) async {
    final authUser = _firebaseAuth.currentUser;
    final requestedUserId = userId?.trim() ?? '';
    final targetUserId = requestedUserId.isNotEmpty
        ? requestedUserId
        : authUser?.uid.trim() ?? '';

    if (targetUserId.isEmpty) {
      _profile = null;
      _loadedUserId = '';
      _errorMessage = null;
      _setState(ProfileLoadState.notFound);
      return;
    }

    _profile = null;
    _loadedUserId = targetUserId;
    _errorMessage = null;
    _setState(ProfileLoadState.loading);

    try {
      final loadedProfile = await _repository.fetchProfile(
        uid: targetUserId,
      );

      if (loadedProfile == null) {
        _profile = null;
        _setState(ProfileLoadState.notFound);
        return;
      }

      final isSelf = authUser != null && authUser.uid.trim() == targetUserId;

      _profile = isSelf
          ? _withAuthFallbacks(
              profile: loadedProfile,
              user: authUser,
            )
          : loadedProfile;

      _setState(ProfileLoadState.loaded);
    } catch (error, stackTrace) {
      debugPrint(
        'ProfileController: Profil konnte nicht geladen werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _profile = null;
      _errorMessage = 'Das Profil konnte nicht geladen werden.';
      _setState(ProfileLoadState.error);
    }
  }

  Future<void> reload() {
    final targetUserId = _loadedUserId.trim();

    if (targetUserId.isEmpty) {
      return loadCurrentProfile();
    }

    return loadProfile(userId: targetUserId);
  }

  ProfileModel _withAuthFallbacks({
    required ProfileModel profile,
    required User user,
  }) {
    final firestoreAvatarUrl = profile.profileImageUrl.trim();
    final authAvatarUrl = user.photoURL?.trim() ?? '';

    if (firestoreAvatarUrl.isNotEmpty || authAvatarUrl.isEmpty) {
      return profile;
    }

    return ProfileModel(
      uid: profile.uid,
      displayName: profile.displayName,
      username: profile.username,
      bio: profile.bio,
      profileImageUrl: authAvatarUrl,
      coverImageUrl: profile.coverImageUrl,
      isVerified: profile.isVerified,
      location: profile.location,
      work: profile.work,
      education: profile.education,
      website: profile.website,
    );
  }

  void _setState(ProfileLoadState nextState) {
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
