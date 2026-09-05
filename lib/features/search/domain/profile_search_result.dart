// Pfad: lib/features/search/domain/profile_search_result.dart
class ProfileSearchResult {
  const ProfileSearchResult({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.isVerified,
  });

  final String uid;
  final String displayName;
  final String username;
  final String avatarUrl;
  final bool isVerified;

  String get displayNameLowercase => displayName.trim().toLowerCase();

  factory ProfileSearchResult.fromFirestore({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return ProfileSearchResult(
      uid: uid.trim(),
      displayName: _readString(data, <String>['displayName', 'name']),
      username: _readString(data, <String>['username']),
      avatarUrl: _readString(
        data,
        <String>['avatarUrl', 'profileImageUrl', 'photoUrl', 'photoURL'],
      ),
      isVerified: data['isVerified'] == true,
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) {
        final cleaned = value.trim();
        if (cleaned.isNotEmpty) return cleaned;
      }
    }
    return '';
  }
}
