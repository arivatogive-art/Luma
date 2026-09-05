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

  Future<void> createComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String authorAvatarUrl,
    required String text,
  }) {
    return _createComment(
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      text: text,
      parentCommentId: null,
    );
  }

  Future<void> createReply({
    required String postId,
    required String parentCommentId,
    required String authorId,
    required String authorName,
    required String authorAvatarUrl,
    required String text,
  }) {
    return _createComment(
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      text: text,
      parentCommentId: parentCommentId,
    );
  }

  Future<void> _createComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String authorAvatarUrl,
    required String text,
    required String? parentCommentId,
  }) async {
    final cleanedPostId = postId.trim();
    final cleanedAuthorId = authorId.trim();
    final cleanedAuthorName = authorName.trim();
    final cleanedAvatarUrl = authorAvatarUrl.trim();
    final cleanedText = text.trim();
    final cleanedParentCommentId = parentCommentId?.trim() ?? '';

    if (cleanedPostId.isEmpty) {
      throw ArgumentError.value(postId, 'postId', 'Beitrags-ID fehlt.');
    }

    if (cleanedAuthorId.isEmpty) {
      throw ArgumentError.value(authorId, 'authorId', 'Nutzer-ID fehlt.');
    }

    if (cleanedAuthorName.isEmpty || cleanedAuthorName.length > 120) {
      throw ArgumentError.value(
        authorName,
        'authorName',
        'Der Anzeigename ist ungültig.',
      );
    }

    if (cleanedAvatarUrl.length > 4096) {
      throw ArgumentError.value(
        authorAvatarUrl,
        'authorAvatarUrl',
        'Die Avatar-URL ist zu lang.',
      );
    }

    if (cleanedText.isEmpty || cleanedText.length > 500) {
      throw ArgumentError.value(
        text,
        'text',
        'Der Kommentar muss zwischen 1 und 500 Zeichen lang sein.',
      );
    }

    if (parentCommentId != null &&
        (cleanedParentCommentId.isEmpty ||
            cleanedParentCommentId.length > 220)) {
      throw ArgumentError.value(
        parentCommentId,
        'parentCommentId',
        'Die Antwort-Zuordnung ist ungültig.',
      );
    }

    final postRef = _firestore.collection('feed_posts').doc(cleanedPostId);
    final commentsRef = postRef.collection('comments');
    final commentRef = commentsRef.doc();
    final parentRef = cleanedParentCommentId.isEmpty
        ? null
        : commentsRef.doc(cleanedParentCommentId);
    final now = Timestamp.now();

    await _firestore.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) {
        throw StateError('Der Beitrag existiert nicht mehr.');
      }

      final postData = postSnapshot.data();
      if (postData == null) {
        throw StateError('Der Beitrag konnte nicht gelesen werden.');
      }

      DocumentSnapshot<Map<String, dynamic>>? parentSnapshot;

      if (parentRef != null) {
        parentSnapshot = await transaction.get(parentRef);

        if (!parentSnapshot.exists) {
          throw StateError('Der Kommentar existiert nicht mehr.');
        }

        final parentData = parentSnapshot.data();
        if (parentData == null) {
          throw StateError('Der Kommentar konnte nicht gelesen werden.');
        }

        if (parentData['isDeleted'] == true) {
          throw StateError('Auf einen gelöschten Kommentar kann nicht geantwortet werden.');
        }
      }

      final rawCommentCount = postData['commentCount'];
      final currentCommentCount = rawCommentCount is num
          ? rawCommentCount.toInt().clamp(0, 2147483647)
          : 0;

      transaction.set(
        commentRef,
        <String, dynamic>{
          'id': commentRef.id,
          'postId': cleanedPostId,
          'authorId': cleanedAuthorId,
          'authorName': cleanedAuthorName,
          'authorAvatarUrl':
              cleanedAvatarUrl.isEmpty ? null : cleanedAvatarUrl,
          'text': cleanedText,
          'createdAt': now,
          'updatedAt': null,
          'deletedAt': null,
          'parentCommentId':
              cleanedParentCommentId.isEmpty ? null : cleanedParentCommentId,
          'likeCount': 0,
          'reactionCount': 0,
          'reactionCounts': <String, int>{
            'like': 0,
            'love': 0,
            'haha': 0,
            'wow': 0,
            'sad': 0,
            'angry': 0,
          },
          'replyCount': 0,
          'isDeleted': false,
          'schemaVersion': 2,
        },
      );

      transaction.update(
        postRef,
        <String, dynamic>{
          'commentCount': currentCommentCount + 1,
          'updatedAt': now,
        },
      );

      if (parentRef != null && parentSnapshot != null) {
        final parentData = parentSnapshot.data();
        final rawReplyCount = parentData?['replyCount'];
        final currentReplyCount = rawReplyCount is num
            ? rawReplyCount.toInt().clamp(0, 2147483647)
            : 0;

        transaction.update(
          parentRef,
          <String, dynamic>{
            'replyCount': currentReplyCount + 1,
            'updatedAt': now,
          },
        );
      }
    });
  }
}
