// Pfad: lib/features/profile/data/profile_post_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_post_model.dart';

class ProfilePostRepository {
  ProfilePostRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<ProfilePostModel>> fetchProfilePosts({
    required String profileUserId,
    required String currentUserId,
    required bool areFriends,
    int limit = 20,
  }) async {
    final cleanedProfileUserId = profileUserId.trim();
    final cleanedCurrentUserId = currentUserId.trim();

    if (cleanedProfileUserId.isEmpty || cleanedCurrentUserId.isEmpty) {
      return const <ProfilePostModel>[];
    }

    final safeLimit = limit.clamp(1, 40).toInt();
    final queryLimit = (safeLimit * 2).clamp(safeLimit, 80).toInt();

    final snapshot = await _firestore
        .collection('feed_posts')
        .where('authorId', isEqualTo: cleanedProfileUserId)
        .orderBy('createdAt', descending: true)
        .limit(queryLimit)
        .get();

    final isOwnProfile = cleanedProfileUserId == cleanedCurrentUserId;
    final posts = <ProfilePostModel>[];

    for (final document in snapshot.docs) {
      final post = ProfilePostModel.fromFirestore(
        id: document.id,
        data: document.data(),
      );

      if (!_canViewPost(
        post: post,
        isOwnProfile: isOwnProfile,
        areFriends: areFriends,
      )) {
        continue;
      }

      posts.add(post);
      if (posts.length >= safeLimit) break;
    }

    return List<ProfilePostModel>.unmodifiable(posts);
  }

  bool _canViewPost({
    required ProfilePostModel post,
    required bool isOwnProfile,
    required bool areFriends,
  }) {
    if (isOwnProfile) return true;

    switch (post.visibility) {
      case ProfilePostVisibility.public:
        return true;
      case ProfilePostVisibility.friends:
        return areFriends;
      case ProfilePostVisibility.private:
        return false;
    }
  }
}
