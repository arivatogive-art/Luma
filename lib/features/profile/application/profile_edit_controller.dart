// Pfad: lib/features/profile/application/profile_edit_controller.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

enum ProfileEditSaveState {
  idle,
  saving,
  success,
  error,
}

class ProfileEditController extends ChangeNotifier {
  ProfileEditController({
    ProfileRepository? repository,
    FirebaseAuth? firebaseAuth,
  })  : _repository = repository ?? ProfileRepository(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ProfileRepository _repository;
  final FirebaseAuth _firebaseAuth;

  ProfileEditSaveState _state = ProfileEditSaveState.idle;
  String? _errorMessage;
  bool _disposed = false;

  ProfileEditSaveState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _state == ProfileEditSaveState.saving;

  Future<bool> save({
    required ProfileModel profile,
    required String displayName,
    required String username,
    required String bio,
    required String location,
    required String work,
    required String education,
    required String website,
  }) async {
    final authUser = _firebaseAuth.currentUser;
    final currentUserId = authUser?.uid.trim() ?? '';
    final profileUserId = profile.uid.trim();

    if (currentUserId.isEmpty ||
        profileUserId.isEmpty ||
        currentUserId != profileUserId) {
      _errorMessage =
          'Dieses Profil kann mit dem aktuellen Konto nicht bearbeitet werden.';
      _setState(ProfileEditSaveState.error);
      return false;
    }

    final cleanedDisplayName = displayName.trim();
    final cleanedUsername =
        username.trim().replaceFirst(RegExp(r'^@+'), '');

    if (cleanedDisplayName.length < 2) {
      _errorMessage =
          'Der Anzeigename muss mindestens 2 Zeichen lang sein.';
      _setState(ProfileEditSaveState.error);
      return false;
    }

    if (cleanedDisplayName.length > 80) {
      _errorMessage =
          'Der Anzeigename darf höchstens 80 Zeichen lang sein.';
      _setState(ProfileEditSaveState.error);
      return false;
    }

    if (cleanedUsername.length < 3) {
      _errorMessage =
          'Der Benutzername muss mindestens 3 Zeichen lang sein.';
      _setState(ProfileEditSaveState.error);
      return false;
    }

    if (cleanedUsername.length > 40) {
      _errorMessage =
          'Der Benutzername darf höchstens 40 Zeichen lang sein.';
      _setState(ProfileEditSaveState.error);
      return false;
    }

    if (!RegExp(r'^[A-Za-z0-9._]+$').hasMatch(cleanedUsername)) {
      _errorMessage =
          'Der Benutzername darf nur Buchstaben, Zahlen, Punkte und Unterstriche enthalten.';
      _setState(ProfileEditSaveState.error);
      return false;
    }

    if (bio.trim().length > 240) {
      _errorMessage =
          'Die Bio darf höchstens 240 Zeichen lang sein.';
      _setState(ProfileEditSaveState.error);
      return false;
    }

    if (website.trim().length > 240) {
      _errorMessage =
          'Die Webseite ist zu lang.';
      _setState(ProfileEditSaveState.error);
      return false;
    }

    _errorMessage = null;
    _setState(ProfileEditSaveState.saving);

    try {
      await _repository.updateProfile(
        uid: profileUserId,
        displayName: cleanedDisplayName,
        username: cleanedUsername,
        bio: bio,
        location: location,
        work: work,
        education: education,
        website: website,
      );

      _setState(ProfileEditSaveState.success);
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'ProfileEditController: Profil konnte nicht gespeichert werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage =
          'Die Änderungen konnten nicht gespeichert werden.';
      _setState(ProfileEditSaveState.error);
      return false;
    }
  }

  void resetState() {
    _errorMessage = null;
    _setState(ProfileEditSaveState.idle);
  }

  void _setState(ProfileEditSaveState nextState) {
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
