// Pfad: lib/presentation/widgets/profile_display_name_helper.dart

import '../../domain/models/private_profile_model.dart';

class ProfileDisplayNameHelper {
  const ProfileDisplayNameHelper._();

  static String safeDisplayName(PrivateProfileModel profile) {
    final displayName = profile.displayName.trim();

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final username = profile.username.trim();

    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    return 'dieses Profil';
  }

  static String safeUsername(PrivateProfileModel profile) {
    final username = profile.username.trim();

    if (username.isEmpty) {
      return '';
    }

    return username.startsWith('@') ? username : '@$username';
  }
}
