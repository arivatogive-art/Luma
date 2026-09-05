// Pfad: lib/features/comments/data/profile_post_comments_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_post_comment_model.dart';

class ProfilePostCommentsRepository {
  ProfilePostCommentsRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<ProfilePostCommentModel>> fetchComments({
    required String postId,
    int limit = 100,
  }) async {
    final cleanedPostId = postId.trim();

    if (cleanedPostId.isEmpty) {
      return const <ProfilePostCommentModel>[];
    }

    final safeLimit = limit.clamp(1, 200).toInt();

    final snapshot = await _firestore
        .collection('feed_posts')
        .doc(cleanedPostId)
        .collection('comments')
        .orderBy('createdAt')
        .limit(safeLimit)
        .get();

    final comments = <ProfilePostCommentModel>[];

    for (final document in snapshot.docs) {
      final comment = ProfilePostCommentModel.fromFirestore(
        id: document.id,
        data: document.data(),
      );

      if (comment.isDeleted) {
        continue;
      }

      if (comment.postId.isNotEmpty && comment.postId != cleanedPostId) {
        continue;
      }

      if (comment.id.isEmpty ||
          comment.authorId.isEmpty ||
          comment.authorName.isEmpty ||
          comment.text.isEmpty) {
        continue;
      }

      comments.add(comment);
    }

    return List<ProfilePostCommentModel>.unmodifiable(comments);
  }
}
