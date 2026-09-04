// Pfad: lib/features/profile/presentation/profile_post_detail_screen.dart

import 'package:flutter/material.dart';

import '../domain/profile_model.dart';
import '../domain/profile_post_model.dart';

class ProfilePostDetailScreen extends StatelessWidget {
  const ProfilePostDetailScreen({
    super.key,
    required this.profile,
    required this.post,
  });

  final ProfileModel profile;
  final ProfilePostModel post;

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
                      color:
                          theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child:
                          const Icon(Icons.broken_image_outlined),
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
                        errorBuilder:
                            (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
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
          Text(
            'Reaktionen und Kommentare werden im nächsten Schritt '
            'an das bestehende Feed-System angebunden.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
