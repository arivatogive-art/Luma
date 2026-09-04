// Pfad: lib/features/profile/presentation/widgets/profile_posts_section.dart

import 'package:flutter/material.dart';

import '../../application/profile_posts_controller.dart';
import '../../domain/profile_model.dart';
import '../../domain/profile_post_model.dart';

class ProfilePostsSection extends StatelessWidget {
  const ProfilePostsSection({
    super.key,
    required this.profile,
    required this.state,
    required this.posts,
    required this.onOpenPost,
    this.errorMessage,
  });

  final ProfileModel profile;
  final ProfilePostsLoadState state;
  final List<ProfilePostModel> posts;
  final ValueChanged<ProfilePostModel> onOpenPost;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Beiträge',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (state) {
      case ProfilePostsLoadState.initial:
      case ProfilePostsLoadState.loading:
        return const SizedBox(
          height: 120,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

      case ProfilePostsLoadState.error:
        return _PostMessage(
          icon: Icons.cloud_off_outlined,
          text: errorMessage ?? 'Beiträge konnten nicht geladen werden.',
        );

      case ProfilePostsLoadState.loaded:
        if (posts.isEmpty) {
          return const _PostMessage(
            icon: Icons.article_outlined,
            text: 'Noch keine sichtbaren Beiträge vorhanden.',
          );
        }

        return Column(
          children: posts
              .map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProfilePostCard(
                    profile: profile,
                    post: post,
                    onTap: () => onOpenPost(post),
                  ),
                ),
              )
              .toList(growable: false),
        );
    }
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.profile,
    required this.post,
    required this.onTap,
  });

  final ProfileModel profile;
  final ProfilePostModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final displayName = profile.displayName.trim().isEmpty
        ? post.username
        : profile.displayName.trim();

    final avatarUrl = profile.profileImageUrl.trim().isNotEmpty
        ? profile.profileImageUrl.trim()
        : post.userAvatarUrl.trim();

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.7,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    foregroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person_outline_rounded)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateLabel(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (post.hasText) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  post.contentText,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.42),
                ),
              ],
              if (post.hasImage) ...<Widget>[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 180,
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      );
                    },
                  ),
                ),
              ],
              if (post.hasVideo) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
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
              if (post.isRepost && post.hasOriginalContent) ...<Widget>[
                const SizedBox(height: 12),
                _RepostPreview(post: post),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text('${post.likeCount}'),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text('${post.commentCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dateLabel(DateTime value) {
    if (value.millisecondsSinceEpoch <= 0) return '';

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return '$day.$month.${local.year}';
  }
}

class _RepostPreview extends StatelessWidget {
  const _RepostPreview({
    required this.post,
  });

  final ProfilePostModel post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (post.originalUsername.trim().isNotEmpty)
            Text(
              post.originalUsername.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          if (post.originalUsername.trim().isNotEmpty &&
              post.originalContentText.trim().isNotEmpty)
            const SizedBox(height: 6),
          if (post.originalContentText.trim().isNotEmpty)
            Text(
              post.originalContentText.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          if (post.originalImageUrl.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                post.originalImageUrl.trim(),
                width: double.infinity,
                height: 170,
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
              height: 72,
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
    );
  }
}

class _PostMessage extends StatelessWidget {
  const _PostMessage({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
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
        ],
      ),
    );
  }
}
