// Pfad: lib/application/user_identity_controller.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/luma_user_profile_model.dart';
import 'messenger_controller.dart';
import 'messenger_remote_mode.dart';
import 'remembered_login_account_storage_service.dart';
import 'user_identity_state.dart';
import 'user_profile_controller.dart';

class UserIdentityController extends ChangeNotifier {
  UserIdentityController._internal({
    FirebaseAuth? firebaseAuth,
    RememberedLoginAccountStorageService? rememberedLoginAccountStorageService,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _rememberedLoginAccountStorageService =
            rememberedLoginAccountStorageService ??
                const RememberedLoginAccountStorageService();

  static final UserIdentityController instance =
      UserIdentityController._internal();

  UserIdentityState _state = const UserIdentityState.initial();

  UserIdentityState get state => _state;

  final FirebaseAuth _firebaseAuth;
  final RememberedLoginAccountStorageService
      _rememberedLoginAccountStorageService;

  StreamSubscription<User?>? _authSubscription;

  UserProfileController? _profileController;

  VoidCallback? _profileListener;

  bool _isDisposed = false;

  bool get isAuthenticated => _state.isAuthenticated;

  String? get currentUserId => _state.userId;

  LumaUserProfileModel? get currentProfile => _state.profile;

  Future<void> initialize() async {
    if (_authSubscription == null) {
      _authSubscription = _firebaseAuth.authStateChanges().listen(
        _handleAuthUser,
        onError: (_) {
          if (_isDisposed) return;

          _setState(
            _state.copyWith(
              isLoading: false,
              isInitialized: true,
              errorMessage:
                  'Die Benutzeridentität konnte nicht synchronisiert werden.',
            ),
          );
        },
      );
    }

    await syncCurrentAuthUser();
  }

  Future<void> syncCurrentAuthUser() async {
    if (_isDisposed) return;

    _setState(
      _state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
      ),
    );

    await _handleAuthUser(
      _firebaseAuth.currentUser,
    );
  }

  Future<void> _handleAuthUser(
    User? authUser,
  ) async {
    if (_isDisposed) return;

    final currentAuthUser = authUser;
    final userId = currentAuthUser?.uid.trim();

    if (currentAuthUser == null || userId == null || userId.isEmpty) {
      await MessengerController.instance.configureRemoteMode(
        mode: MessengerRemoteMode.remoteOnly,
      );

      await _clearProfileController();

      if (_isDisposed) return;

      _setState(
        _state.copyWith(
          isInitialized: true,
          isLoading: false,
          isAuthenticated: false,
          clearUserId: true,
          clearProfile: true,
          clearErrorMessage: true,
        ),
      );

      return;
    }

    await MessengerController.instance.configureRemoteMode(
      mode: MessengerRemoteMode.remoteOnly,
      currentUserId: userId,
    );

    final displayName = currentAuthUser.displayName?.trim();
    final email = currentAuthUser.email?.trim();
    final phoneNumber = currentAuthUser.phoneNumber?.trim();
    final avatarUrl = currentAuthUser.photoURL?.trim();

    final fallbackName = displayName != null && displayName.isNotEmpty
        ? displayName
        : email != null && email.isNotEmpty
            ? email.split('@').first
            : 'Luma Nutzer';

    await _attachProfileController(
      userId: userId,
      fallbackDisplayName: fallbackName,
      fallbackEmail: email != null && email.isNotEmpty ? email : null,
      fallbackPhoneNumber:
          phoneNumber != null && phoneNumber.isNotEmpty ? phoneNumber : null,
      fallbackAvatarUrl:
          avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null,
    );
  }

  Future<void> _attachProfileController({
    required String userId,
    required String fallbackDisplayName,
    String? fallbackEmail,
    String? fallbackPhoneNumber,
    String? fallbackAvatarUrl,
  }) async {
    final existingController = _profileController;

    if (existingController != null && existingController.userId == userId) {
      await existingController.initialize(
        fallbackDisplayName: fallbackDisplayName,
        fallbackEmail: fallbackEmail,
        fallbackPhoneNumber: fallbackPhoneNumber,
        fallbackAvatarUrl: fallbackAvatarUrl,
      );

      await existingController.reloadProfile();

      if (_isDisposed) return;

      final profileState = existingController.state;

      _rememberProfileSafely(profileState.profile);

      _setState(
        _state.copyWith(
          isInitialized: true,
          isLoading: profileState.isLoading,
          isAuthenticated: true,
          userId: userId,
          profile: profileState.profile,
          errorMessage: profileState.errorMessage,
        ),
      );

      return;
    }

    await _clearProfileController();

    if (_isDisposed) return;

    final controller = UserProfileController(
      userId: userId,
    );

    _profileController = controller;

    _profileListener = () {
      if (_isDisposed) return;

      final profileState = controller.state;

      _rememberProfileSafely(profileState.profile);

      _setState(
        _state.copyWith(
          isInitialized: true,
          isLoading: profileState.isLoading,
          isAuthenticated: true,
          userId: userId,
          profile: profileState.profile,
          errorMessage: profileState.errorMessage,
        ),
      );
    };

    controller.addListener(
      _profileListener!,
    );

    await controller.initialize(
      fallbackDisplayName: fallbackDisplayName,
      fallbackEmail: fallbackEmail,
      fallbackPhoneNumber: fallbackPhoneNumber,
      fallbackAvatarUrl: fallbackAvatarUrl,
    );

    if (_isDisposed) return;

    final profileState = controller.state;

    _rememberProfileSafely(profileState.profile);

    _setState(
      _state.copyWith(
        isInitialized: true,
        isLoading: profileState.isLoading,
        isAuthenticated: true,
        userId: userId,
        profile: profileState.profile,
        errorMessage: profileState.errorMessage,
      ),
    );
  }

  Future<void> reloadProfile() async {
    final controller = _profileController;

    if (controller == null) {
      await syncCurrentAuthUser();
      return;
    }

    await controller.reloadProfile();

    if (_isDisposed) return;

    final userId = controller.userId;
    final profileState = controller.state;

    _rememberProfileSafely(profileState.profile);

    _setState(
      _state.copyWith(
        isInitialized: true,
        isLoading: profileState.isLoading,
        isAuthenticated: userId.trim().isNotEmpty,
        userId: userId,
        profile: profileState.profile,
        errorMessage: profileState.errorMessage,
      ),
    );
  }

  void _rememberProfileSafely(LumaUserProfileModel? profile) {
    if (_isDisposed || profile == null) return;

    unawaited(
      _rememberedLoginAccountStorageService.upsertProfile(profile).catchError(
        (Object error, StackTrace stackTrace) {
          debugPrint('User profile could not be remembered locally: $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      ),
    );
  }

  Future<void> _clearProfileController() async {
    final controller = _profileController;
    final listener = _profileListener;

    _profileController = null;
    _profileListener = null;

    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }

    controller?.dispose();
  }

  void _setState(
    UserIdentityState newState,
  ) {
    if (_isDisposed) return;

    _applyStateIfChanged(newState);
  }

  void _applyStateIfChanged(
    UserIdentityState nextState,
  ) {
    if (_isDisposed) return;
    if (_state == nextState) return;

    _state = nextState;

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;

    final authSubscription = _authSubscription;

    _authSubscription = null;

    if (authSubscription != null) {
      unawaited(
        authSubscription.cancel(),
      );
    }

    unawaited(
      MessengerController.instance.configureRemoteMode(
        mode: MessengerRemoteMode.remoteOnly,
      ),
    );

    unawaited(
      _clearProfileController(),
    );

    super.dispose();
  }
}
