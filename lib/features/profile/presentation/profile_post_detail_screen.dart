// Pfad: lib/features/profile/presentation/profile_post_detail_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../comments/application/profile_post_comments_controller.dart';
import '../../comments/domain/profile_post_comment_model.dart';
import '../domain/profile_model.dart';
import '../domain/profile_post_model.dart';

class ProfilePostDetailScreen extends StatelessWidget {
  const ProfilePostDetailScreen({
    super.key,
    required this.profile,
    required this.post,
    required this.isOwnProfile,
    required this.onEditPost,
    required this.onDeletePost,
  });

  final ProfileModel profile;
  final ProfilePostModel post;
  final bool isOwnProfile;
  final Future<bool> Function(ProfilePostModel post) onEditPost;
  final Future<bool> Function(ProfilePostModel post) onDeletePost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final displayName = profile.displayName.trim().isEmpty
        ? post.username
        : profile.displayName.trim();

    final avatarUrl = profile.profileImageUrl.trim().isNotEmpty
        ? profile.profileImageUrl.trim()
        : post.userAvatarUrl.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beitrag'),
        actions: <Widget>[
          if (isOwnProfile)
            PopupMenuButton<String>(
              tooltip: 'Beitragsoptionen',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) async {
                if (value == 'edit') {
                  final edited = await onEditPost(post);
                  if (!context.mounted || !edited) return;

                  Navigator.of(context).pop(true);
                  return;
                }

                if (value == 'delete') {
                  final deleted = await onDeletePost(post);
                  if (!context.mounted || !deleted) return;

                  Navigator.of(context).pop(true);
                }
              },
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 10),
                      Text('Beitrag bearbeiten'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.delete_outline_rounded),
                      SizedBox(width: 10),
                      Text('Beitrag löschen'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 23,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                foregroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person_outline_rounded)
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            _dateLabel(post.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '·',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _visibilityIcon(post.visibility),
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _visibilityLabel(post.visibility),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.hasText) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              post.contentText,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.48,
              ),
            ),
          ],
          if (post.hasImage) ...<Widget>[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  post.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 220,
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    );
                  },
                ),
              ),
            ),
          ],
          if (post.hasVideo) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 42,
                  ),
                  SizedBox(height: 8),
                  Text('Video'),
                ],
              ),
            ),
          ],
          if (post.isRepost && post.hasOriginalContent) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (post.originalUsername.trim().isNotEmpty)
                    Text(
                      post.originalUsername,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (post.originalUsername.trim().isNotEmpty &&
                      post.originalContentText.trim().isNotEmpty)
                    const SizedBox(height: 6),
                  if (post.originalContentText.trim().isNotEmpty)
                    Text(
                      post.originalContentText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  if (post.originalImageUrl.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        post.originalImageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                  if (post.originalVideoUrl.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 86,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.play_circle_outline_rounded),
                          SizedBox(width: 8),
                          Text('Video'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Divider(
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(
                Icons.thumb_up_alt_outlined,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text('${post.likeCount}'),
              const SizedBox(width: 22),
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text('${post.commentCount}'),
            ],
          ),
          const SizedBox(height: 18),
          _ProfilePostCommentsSection(
            postId: post.id,
            authorName: displayName,
            authorAvatarUrl: avatarUrl,
          ),
        ],
      ),
    );
  }

  static IconData _visibilityIcon(ProfilePostVisibility visibility) {
    switch (visibility) {
      case ProfilePostVisibility.public:
        return Icons.public_rounded;
      case ProfilePostVisibility.friends:
        return Icons.people_outline_rounded;
      case ProfilePostVisibility.private:
        return Icons.lock_outline_rounded;
    }
  }

  static String _visibilityLabel(ProfilePostVisibility visibility) {
    switch (visibility) {
      case ProfilePostVisibility.public:
        return 'Öffentlich';
      case ProfilePostVisibility.friends:
        return 'Freunde';
      case ProfilePostVisibility.private:
        return 'Nur ich';
    }
  }

  static String _dateLabel(DateTime value) {
    if (value.millisecondsSinceEpoch <= 0) return '';

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day.$month.${local.year} · $hour:$minute';
  }
}

class _ProfilePostCommentsSection extends StatefulWidget {
  const _ProfilePostCommentsSection({
    required this.postId,
    required this.authorName,
    required this.authorAvatarUrl,
  });

  final String postId;
  final String authorName;
  final String authorAvatarUrl;

  @override
  State<_ProfilePostCommentsSection> createState() =>
      _ProfilePostCommentsSectionState();
}

class _ProfilePostCommentsSectionState
    extends State<_ProfilePostCommentsSection> {
  late final ProfilePostCommentsController _controller;
  late final TextEditingController _commentTextController;
  late final FocusNode _commentFocusNode;

  @override
  void initState() {
    super.initState();

    _controller = ProfilePostCommentsController();
    _commentTextController = TextEditingController();
    _commentFocusNode = FocusNode();

    _controller.addListener(_handleControllerChanged);
    _controller.load(postId: widget.postId);
  }

  @override
  void didUpdateWidget(covariant _ProfilePostCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.postId != widget.postId) {
      _controller.load(postId: widget.postId);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _commentTextController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Kommentare',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _buildComposer(context),
        const SizedBox(height: 16),
        _buildContent(context),
      ],
    );
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final canSend = user != null && !_controller.isSending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _commentTextController,
                focusNode: _commentFocusNode,
                enabled: !_controller.isSending,
                minLines: 1,
                maxLines: 5,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Kommentar schreiben …',
                  counterText: '',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
                onChanged: (_) {
                  if (_controller.sendErrorMessage != null) {
                    _controller.clearSendError();
                  } else {
                    setState(() {});
                  }
                },
                onSubmitted: (_) {
                  if (canSend) {
                    _sendComment();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Kommentar senden',
              onPressed: canSend &&
                      _commentTextController.text.trim().isNotEmpty
                  ? _sendComment
                  : null,
              icon: _controller.isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
        if (_controller.sendErrorMessage != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _controller.sendErrorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _sendComment() async {
    if (_controller.isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Du musst angemeldet sein, um zu kommentieren.'),
        ),
      );
      return;
    }

    final text = _commentTextController.text.trim();
    if (text.isEmpty) return;

    final fallbackName = user.displayName?.trim() ?? '';
    final authorName = widget.authorName.trim().isNotEmpty
        ? widget.authorName.trim()
        : fallbackName;

    if (authorName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dein Anzeigename konnte nicht geladen werden.'),
        ),
      );
      return;
    }

    final profileAvatar = widget.authorAvatarUrl.trim();
    final authAvatar = user.photoURL?.trim() ?? '';
    final authorAvatarUrl =
        profileAvatar.isNotEmpty ? profileAvatar : authAvatar;

    final sent = await _controller.createComment(
      postId: widget.postId,
      authorId: user.uid,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      text: text,
    );

    if (!mounted || !sent) return;

    _commentTextController.clear();
    _commentFocusNode.unfocus();
    setState(() {});
  }

  Widget _buildContent(BuildContext context) {
    switch (_controller.state) {
      case ProfilePostCommentsLoadState.initial:
      case ProfilePostCommentsLoadState.loading:
        return const SizedBox(
          height: 82,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

      case ProfilePostCommentsLoadState.error:
        return _CommentMessage(
          icon: Icons.cloud_off_outlined,
          text:
              _controller.errorMessage ?? 'Kommentare konnten nicht geladen werden.',
          actionLabel: 'Erneut versuchen',
          onAction: () => _controller.reload(postId: widget.postId),
        );

      case ProfilePostCommentsLoadState.loaded:
        final rootComments = _controller.rootComments;

        if (rootComments.isEmpty) {
          return const _CommentMessage(
            icon: Icons.chat_bubble_outline_rounded,
            text: 'Noch keine Kommentare.',
          );
        }

        return Column(
          children: rootComments
              .map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CommentThread(
                    comment: comment,
                    replies: _controller.repliesFor(comment.id),
                  ),
                ),
              )
              .toList(growable: false),
        );
    }
  }
}

class _CommentThread extends StatelessWidget {
  const _CommentThread({
    required this.comment,
    required this.replies,
  });

  final ProfilePostCommentModel comment;
  final List<ProfilePostCommentModel> replies;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _CommentTile(comment: comment),
        if (replies.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Column(
              children: replies
                  .map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CommentTile(
                        comment: reply,
                        isReply: true,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    this.isReply = false,
  });

  final ProfilePostCommentModel comment;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = comment.authorAvatarUrl.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: isReply ? 15 : 18,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty
              ? Icon(
                  Icons.person_outline_rounded,
                  size: isReply ? 17 : 20,
                )
              : null,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _commentDateLabel(comment.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                  ),
                ),
                if (comment.reactionCount > 0 ||
                    comment.replyCount > 0) ...<Widget>[
                  const SizedBox(height: 7),
                  Row(
                    children: <Widget>[
                      if (comment.reactionCount > 0) ...<Widget>[
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${comment.reactionCount}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (comment.reactionCount > 0 &&
                          comment.replyCount > 0)
                        const SizedBox(width: 12),
                      if (comment.replyCount > 0) ...<Widget>[
                        Icon(
                          Icons.reply_rounded,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${comment.replyCount}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _commentDateLabel(DateTime value) {
    if (value.millisecondsSinceEpoch <= 0) return '';

    final local = value.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    if (sameDay) {
      return '$hour:$minute';
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return '$day.$month.';
  }
}

class _CommentMessage extends StatelessWidget {
  const _CommentMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
