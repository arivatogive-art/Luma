// Pfad: lib/application/user_identity_state.dart

import 'package:flutter/foundation.dart';

import '../domain/models/luma_user_profile_model.dart';

@immutable
class UserIdentityState {
  const UserIdentityState({
    required this.isInitialized,
    required this.isLoading,
    required this.isAuthenticated,
    required this.userId,
    required this.profile,
    required this.errorMessage,
  });

  const UserIdentityState.initial()
      : isInitialized = false,
        isLoading = false,
        isAuthenticated = false,
        userId = null,
        profile = null,
        errorMessage = null;

  final bool isInitialized;
  final bool isLoading;
  final bool isAuthenticated;
  final String? userId;
  final LumaUserProfileModel? profile;
  final String? errorMessage;

  UserIdentityState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isAuthenticated,
    String? userId,
    bool clearUserId = false,
    LumaUserProfileModel? profile,
    bool clearProfile = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return UserIdentityState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: clearUserId ? null : userId ?? this.userId,
      profile: clearProfile ? null : profile ?? this.profile,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}
