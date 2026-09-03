// Pfad: lib/application/user_profile_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/user_profile_repository.dart';
import '../domain/models/luma_user_profile_model.dart';
import 'user_profile_state.dart';

class UserProfileController extends ChangeNotifier {
  UserProfileState _state = const UserProfileState.initial();

  UserProfileState get state => _state;

  final UserProfileRepository _repository;
  final String _userId;

  StreamSubscription<LumaUserProfileModel?>? _profileSubscription;
  bool _isDisposed = false;

  UserProfileController({
    required String userId,
    UserProfileRepository? repository,
  })  : _userId = userId.trim(),
        _repository = repository ?? UserProfileRepository();

  String get userId => _userId;
  bool get hasProfile => _state.hasProfile;
  LumaUserProfileModel? get profile => _state.profile;

  Future<void> initialize({
    String? fallbackDisplayName,
    String? fallbackUsername,
    String? fallbackEmail,
    String? fallbackPhoneNumber,
    String? fallbackAvatarUrl,
  }) async {
    if (_state.isInitialized) {
      await _repairExistingProfileIfNeeded(
        fallbackDisplayName: fallbackDisplayName,
        fallbackUsername: fallbackUsername,
        fallbackEmail: fallbackEmail,
        fallbackPhoneNumber: fallbackPhoneNumber,
        fallbackAvatarUrl: fallbackAvatarUrl,
      );
      return;
    }

    if (_userId.isEmpty) {
      _setState(
        _state.copyWith(
          isInitialized: true,
          errorMessage: 'Die Profil-ID ist ungültig.',
        ),
      );
      return;
    }

    _setState(_state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final profile = await _repository.createProfileIfMissing(
        userId: _userId,
        displayName: fallbackDisplayName,
        username: fallbackUsername,
        email: fallbackEmail,
        phoneNumber: fallbackPhoneNumber,
        avatarUrl: fallbackAvatarUrl,
      );

      await _repository.repairOwnSearchFields(userId: _userId);
      if (_isDisposed) return;

      _setState(
        _state.copyWith(
          isLoading: false,
          isInitialized: true,
          profile: profile,
          clearErrorMessage: true,
        ),
      );

      _startProfileSubscription();
    } catch (error, stackTrace) {
      debugPrint('User profile initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_isDisposed) return;

      _setState(
        _state.copyWith(
          isLoading: false,
          isInitialized: true,
          errorMessage: 'Das Benutzerprofil konnte nicht geladen werden.',
        ),
      );
    }
  }

  Future<void> _repairExistingProfileIfNeeded({
    String? fallbackDisplayName,
    String? fallbackUsername,
    String? fallbackEmail,
    String? fallbackPhoneNumber,
    String? fallbackAvatarUrl,
  }) async {
    if (_userId.isEmpty) return;

    try {
      final profile = await _repository.createProfileIfMissing(
        userId: _userId,
        displayName: fallbackDisplayName,
        username: fallbackUsername,
        email: fallbackEmail,
        phoneNumber: fallbackPhoneNumber,
        avatarUrl: fallbackAvatarUrl,
      );

      await _repository.repairOwnSearchFields(userId: _userId);
      if (_isDisposed) return;

      _setState(
        _state.copyWith(
          profile: profile,
          clearErrorMessage: true,
        ),
      );

      if (_profileSubscription == null) {
        _startProfileSubscription();
      }
    } catch (error, stackTrace) {
      debugPrint('User profile repair failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> reloadProfile() async {
    if (_userId.isEmpty) return;

    _setState(_state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      await _repository.repairOwnSearchFields(userId: _userId);
      final profile = await _repository.fetchProfile(userId: _userId);
      if (_isDisposed) return;

      _setState(
        _state.copyWith(
          isLoading: false,
          profile: profile,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'Das Benutzerprofil konnte nicht aktualisiert werden.',
        ),
      );
    }
  }

  Future<bool> saveProfile(LumaUserProfileModel profile) async {
    if (_userId.isEmpty) return false;

    _setState(_state.copyWith(isSaving: true, clearErrorMessage: true));

    try {
      final normalizedProfile = profile.copyWith(id: _userId);
      await _repository.saveProfile(profile: normalizedProfile);
      await _repository.repairOwnSearchFields(userId: _userId);

      if (_isDisposed) return false;

      final updatedProfile = await _repository.fetchProfile(userId: _userId);
      if (_isDisposed) return false;

      _setState(
        _state.copyWith(
          isSaving: false,
          profile: updatedProfile ?? normalizedProfile,
          clearErrorMessage: true,
        ),
      );

      return true;
    } catch (_) {
      if (_isDisposed) return false;
      _setState(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'Das Benutzerprofil konnte nicht gespeichert werden.',
        ),
      );
      return false;
    }
  }

  void _startProfileSubscription() {
    unawaited(_profileSubscription?.cancel());

    _profileSubscription =
        _repository.watchProfile(userId: _userId).listen((profile) {
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          profile: profile,
          clearErrorMessage: true,
        ),
      );
    });
  }

  void _setState(UserProfileState next) {
    if (_isDisposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_profileSubscription?.cancel());
    _profileSubscription = null;
    super.dispose();
  }
}
