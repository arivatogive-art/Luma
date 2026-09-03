// Pfad: lib/presentation/widgets/profile_external_url_helper.dart

class ProfileExternalUrlHelper {
  const ProfileExternalUrlHelper._();

  static String? normalize(String rawUrl) {
    final trimmed = rawUrl.trim();

    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) {
      return null;
    }

    final lower = trimmed.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return trimmed;
    }

    if (lower.startsWith('www.')) {
      return 'https://$trimmed';
    }

    if (trimmed.contains('.') && !trimmed.startsWith('.')) {
      return 'https://$trimmed';
    }

    return null;
  }
}
