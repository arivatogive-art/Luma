// Pfad: lib/application/user_profile_state.dart

import 'package:flutter/foundation.dart';

import '../domain/models/luma_user_profile_model.dart';

@immutable
class UserProfileState {
  const UserProfileState({
    required this.isInitialized,
    required this.isLoading,
    required this.isSaving,
    required this.profile,
    required this.errorMessage,
  });

  const UserProfileState.initial()
      : isInitialized = false,
        isLoading = false,
        isSaving = false,
        profile = null,
        errorMessage = null;

  final bool isInitialized;
  final bool isLoading;
  final bool isSaving;
  final LumaUserProfileModel? profile;
  final String? errorMessage;

  bool get hasProfile => profile != null;

  UserProfileState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isSaving,
    LumaUserProfileModel? profile,
    bool clearProfile = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return UserProfileState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      profile: clearProfile ? null : profile ?? this.profile,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}
