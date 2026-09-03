// Pfad: lib/presentation/widgets/profile_identity_helpers.dart

class ProfileIdentityHelpers {
  const ProfileIdentityHelpers._();

  static String nameFromEmail(String? email) {
    final cleanedEmail = email?.trim();

    if (cleanedEmail == null || cleanedEmail.isEmpty) {
      return 'Luma Nutzer';
    }

    final localPart = cleanedEmail.split('@').first.trim();

    if (localPart.isEmpty) return 'Luma Nutzer';

    return localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
      final trimmed = part.trim();
      if (trimmed.length == 1) return trimmed.toUpperCase();
      return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
    }).join(' ');
  }

  static String usernameFromEmail(String? email) {
    final cleanedEmail = email?.trim();

    if (cleanedEmail == null || cleanedEmail.isEmpty) {
      return 'luma_user';
    }

    final localPart = cleanedEmail.split('@').first.trim().toLowerCase();

    if (localPart.isEmpty) return 'luma_user';

    return localPart
        .replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
