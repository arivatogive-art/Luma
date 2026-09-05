// Pfad: lib/features/profile/data/profile_post_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_post_model.dart';

class ProfilePostDeleteResult {
  const ProfilePostDeleteResult({
    required this.imageStoragePath,
  });

  final String imageStoragePath;
}

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

  Future<ProfilePostModel?> fetchPostById({
    required String postId,
  }) async {
    final cleanedPostId = postId.trim();
    if (cleanedPostId.isEmpty) return null;

    final snapshot =
        await _firestore.collection('feed_posts').doc(cleanedPostId).get();

    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) return null;

    return ProfilePostModel.fromFirestore(
      id: snapshot.id,
      data: data,
    );
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

  Future<ProfilePostModel> updatePost({
    required String postId,
    required String currentUserId,
    required String text,
    required ProfilePostVisibility visibility,
  }) async {
    final cleanedPostId = postId.trim();
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedText = text.trim();

    if (cleanedPostId.isEmpty) {
      throw StateError('profile-post-missing-post-id');
    }

    if (cleanedCurrentUserId.isEmpty) {
      throw StateError('profile-post-missing-user-id');
    }

    if (cleanedText.length > 420) {
      throw StateError('profile-post-text-too-long');
    }

    final postRef = _firestore.collection('feed_posts').doc(cleanedPostId);
    final snapshot = await postRef.get();

    if (!snapshot.exists) {
      throw StateError('profile-post-not-found');
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final authorId = _readString(data['authorId']);
    final userId = _readString(data['userId']);
    final ownerId = authorId.isNotEmpty ? authorId : userId;

    if (ownerId != cleanedCurrentUserId) {
      throw StateError('profile-post-edit-not-owner');
    }

    final postType = _readString(data['postType']);
    if (postType == 'repost') {
      throw StateError('profile-post-edit-repost-unsupported');
    }

    final hasImage = _readString(data['imageUrl']).isNotEmpty ||
        _readString(data['feedImageUrl']).isNotEmpty;
    final hasVideo = _readString(data['videoUrl']).isNotEmpty;

    if (cleanedText.isEmpty && !hasImage && !hasVideo) {
      throw StateError('profile-post-empty-content');
    }

    await postRef.update(<String, dynamic>{
      'contentText': cleanedText,
      'visibility': visibility.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final updatedSnapshot = await postRef.get();
    final updatedData = updatedSnapshot.data();

    if (updatedData == null) {
      throw StateError('profile-post-not-found');
    }

    return ProfilePostModel.fromFirestore(
      id: updatedSnapshot.id,
      data: updatedData,
    );
  }

  Future<ProfilePostDeleteResult> deletePost({
    required String postId,
    required String currentUserId,
  }) async {
    final cleanedPostId = postId.trim();
    final cleanedCurrentUserId = currentUserId.trim();

    if (cleanedPostId.isEmpty) {
      throw StateError('profile-post-missing-post-id');
    }

    if (cleanedCurrentUserId.isEmpty) {
      throw StateError('profile-post-missing-user-id');
    }

    final postRef = _firestore.collection('feed_posts').doc(cleanedPostId);
    final snapshot = await postRef.get();

    if (!snapshot.exists) {
      return const ProfilePostDeleteResult(
        imageStoragePath: '',
      );
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final authorId = _readString(data['authorId']);
    final userId = _readString(data['userId']);
    final ownerId = authorId.isNotEmpty ? authorId : userId;

    if (ownerId != cleanedCurrentUserId) {
      throw StateError('profile-post-delete-not-owner');
    }

    final imageStoragePath = _readFirstString(
      data,
      const <String>[
        'imageStoragePath',
        'feedImageStoragePath',
      ],
    );

    await postRef.delete();

    return ProfilePostDeleteResult(
      imageStoragePath: imageStoragePath,
    );
  }

  String _readFirstString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _readString(data[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
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
