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

  String createPostId() {
    return 'post_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<ProfilePostModel> createTextPost({
    required String currentUserId,
    required String username,
    required String userAvatarUrl,
    required String text,
    required ProfilePostVisibility visibility,
  }) async {
    final cleanedUserId = currentUserId.trim();
    final cleanedUsername = username.trim();
    final cleanedAvatarUrl = userAvatarUrl.trim();
    final cleanedText = text.trim();

    if (cleanedUserId.isEmpty) {
      throw StateError('profile-post-missing-user-id');
    }

    if (cleanedUsername.isEmpty) {
      throw StateError('profile-post-missing-username');
    }

    if (cleanedText.isEmpty) {
      throw StateError('profile-post-empty-text');
    }

    if (cleanedText.length > 420) {
      throw StateError('profile-post-text-too-long');
    }

    final postRef = _firestore.collection('feed_posts').doc(
          createPostId(),
        );

    final createdAt = DateTime.now();

    final data = <String, dynamic>{
      'id': postRef.id,
      'userId': cleanedUserId,
      'username': cleanedUsername,
      'userAvatarUrl': cleanedAvatarUrl.isEmpty ? null : cleanedAvatarUrl,
      'contentText': cleanedText,
      'imageUrl': null,
      'imageStoragePath': null,
      'feedImageUrl': null,
      'feedImageStoragePath': null,
      'videoUrl': null,
      'videoStoragePath': null,
      'mood': null,
      'taggedFriends': <String>[],
      'locationLabel': null,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': 0,
      'commentCount': 0,
      'postType': 'standard',
      'visibility': visibility.name,
      'contentCategory': 'thought',
      'authorType': 'user',
      'authorId': cleanedUserId,
      'shareTarget': 'feed',
      'originalPostId': null,
      'originalUsername': null,
      'originalContentText': null,
      'originalImageUrl': null,
      'originalVideoUrl': null,
    };

    await postRef.set(data);

    return ProfilePostModel.fromFirestore(
      id: postRef.id,
      data: data,
    );
  }

  Future<ProfilePostModel> createImagePost({
    required String postId,
    required String currentUserId,
    required String username,
    required String userAvatarUrl,
    required String text,
    required String imageUrl,
    required String imageStoragePath,
    required ProfilePostVisibility visibility,
  }) async {
    final cleanedPostId = postId.trim();
    final cleanedUserId = currentUserId.trim();
    final cleanedUsername = username.trim();
    final cleanedAvatarUrl = userAvatarUrl.trim();
    final cleanedText = text.trim();
    final cleanedImageUrl = imageUrl.trim();
    final cleanedImageStoragePath = imageStoragePath.trim();

    if (cleanedPostId.isEmpty) {
      throw StateError('profile-post-missing-post-id');
    }

    if (cleanedUserId.isEmpty) {
      throw StateError('profile-post-missing-user-id');
    }

    if (cleanedUsername.isEmpty) {
      throw StateError('profile-post-missing-username');
    }

    if (cleanedText.length > 420) {
      throw StateError('profile-post-text-too-long');
    }

    if (cleanedImageUrl.isEmpty || cleanedImageStoragePath.isEmpty) {
      throw StateError('profile-post-missing-image');
    }

    final postRef = _firestore.collection('feed_posts').doc(cleanedPostId);
    final createdAt = DateTime.now();

    final data = <String, dynamic>{
      'id': postRef.id,
      'userId': cleanedUserId,
      'username': cleanedUsername,
      'userAvatarUrl': cleanedAvatarUrl.isEmpty ? null : cleanedAvatarUrl,
      'contentText': cleanedText,
      'imageUrl': cleanedImageUrl,
      'imageStoragePath': cleanedImageStoragePath,
      'feedImageUrl': cleanedImageUrl,
      'feedImageStoragePath': cleanedImageStoragePath,
      'videoUrl': null,
      'videoStoragePath': null,
      'mood': null,
      'taggedFriends': <String>[],
      'locationLabel': null,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': 0,
      'commentCount': 0,
      'postType': 'standard',
      'visibility': visibility.name,
      'contentCategory': 'photo',
      'authorType': 'user',
      'authorId': cleanedUserId,
      'shareTarget': 'feed',
      'originalPostId': null,
      'originalUsername': null,
      'originalContentText': null,
      'originalImageUrl': null,
      'originalVideoUrl': null,
    };

    await postRef.set(data);

    return ProfilePostModel.fromFirestore(
      id: postRef.id,
      data: data,
    );
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
