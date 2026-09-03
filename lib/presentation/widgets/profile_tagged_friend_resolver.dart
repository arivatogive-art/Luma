// Pfad: lib/presentation/widgets/profile_tagged_friend_resolver.dart

import '../../domain/models/private_profile_model.dart';

class ProfileTaggedFriendResolver {
  const ProfileTaggedFriendResolver._();

  static List<String> resolveTaggedFriendNames({
    required List<String> taggedFriendIds,
    required List<PrivateProfileModel> friends,
  }) {
    if (taggedFriendIds.isEmpty || friends.isEmpty) {
      return const <String>[];
    }

    final normalizedTaggedFriendIds = taggedFriendIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedTaggedFriendIds.isEmpty) {
      return const <String>[];
    }

    final friendNameById = <String, String>{};

    for (final friend in friends) {
      final friendId = friend.userId.trim();
      final friendName = friend.displayName.trim();

      if (friendId.isEmpty || friendName.isEmpty) continue;

      friendNameById[friendId] = friendName;
    }

    if (friendNameById.isEmpty) {
      return const <String>[];
    }

    return normalizedTaggedFriendIds
        .map((friendId) => friendNameById[friendId] ?? '')
        .where((friendName) => friendName.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static Map<String, String> resolveTaggedFriendNamesById({
    required List<String> taggedFriendIds,
    required List<PrivateProfileModel> friends,
  }) {
    if (taggedFriendIds.isEmpty || friends.isEmpty) {
      return const <String, String>{};
    }

    final normalizedTaggedFriendIds = taggedFriendIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedTaggedFriendIds.isEmpty) {
      return const <String, String>{};
    }

    final friendNameById = <String, String>{};

    for (final friend in friends) {
      final friendId = friend.userId.trim();
      final friendName = friend.displayName.trim();

      if (friendId.isEmpty || friendName.isEmpty) continue;

      friendNameById[friendId] = friendName;
    }

    if (friendNameById.isEmpty) {
      return const <String, String>{};
    }

    final resolvedFriendNamesById = <String, String>{};

    for (final friendId in normalizedTaggedFriendIds) {
      final friendName = friendNameById[friendId]?.trim() ?? '';

      if (friendName.isEmpty) continue;

      resolvedFriendNamesById[friendId] = friendName;
    }

    return resolvedFriendNamesById;
  }

  static Map<String, String> resolveTaggedFriendAvatarUrlsById({
    required List<String> taggedFriendIds,
    required List<PrivateProfileModel> friends,
  }) {
    if (taggedFriendIds.isEmpty || friends.isEmpty) {
      return const <String, String>{};
    }

    final normalizedTaggedFriendIds = taggedFriendIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (normalizedTaggedFriendIds.isEmpty) {
      return const <String, String>{};
    }

    final resolvedAvatarUrlsById = <String, String>{};

    for (final friend in friends) {
      final friendId = friend.userId.trim();
      final avatarUrl = friend.profileImageUrl.trim();

      if (friendId.isEmpty || avatarUrl.isEmpty) continue;
      if (!normalizedTaggedFriendIds.contains(friendId)) continue;

      resolvedAvatarUrlsById[friendId] = avatarUrl;
    }

    return resolvedAvatarUrlsById;
  }
}
