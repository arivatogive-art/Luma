// Pfad: lib/presentation/widgets/profile_timeline_section.dart

import 'package:flutter/material.dart';

import 'profile_posts_preview_card.dart' as profile_posts;
import 'profile_utils.dart';

class ProfileTimelineSection extends StatelessWidget {
  const ProfileTimelineSection({
    required this.isOwnProfile,
    required this.isLoading,
    required this.errorMessage,
    required this.moments,
    required this.onCreatePost,
    required this.onViewAllPosts,
    required this.onEditMoment,
    required this.onDeleteMoment,
    required this.onTaggedFriendTap,
    required this.onToggleLike,
    required this.onCommentTap,
    required this.onLikeSummaryTap,
    this.profileDisplayName = '',
    this.profileUsername = '',
    this.profileImageUrl = '',
  });

  final bool isOwnProfile;
  final bool isLoading;
  final String? errorMessage;
  final List<profile_posts.ProfileMomentPreviewData> moments;
  final VoidCallback onCreatePost;
  final VoidCallback onViewAllPosts;
  final void Function(profile_posts.ProfileMomentPreviewData moment)
      onEditMoment;
  final Future<void> Function(profile_posts.ProfileMomentPreviewData moment)
      onDeleteMoment;
  final void Function(String friendUserId) onTaggedFriendTap;
  final Future<void> Function(profile_posts.ProfileMomentPreviewData moment)
      onToggleLike;
  final void Function(profile_posts.ProfileMomentPreviewData moment) onCommentTap;
  final void Function(profile_posts.ProfileMomentPreviewData moment)
      onLikeSummaryTap;

  final String profileDisplayName;
  final String profileUsername;
  final String profileImageUrl;

  bool get _hasMoments => moments.isNotEmpty;

  String get _safeAuthorName {
    final cleanDisplayName = profileDisplayName.trim();
    if (cleanDisplayName.isNotEmpty) return cleanDisplayName;

    final cleanUsername = profileUsername.trim();
    if (cleanUsername.isNotEmpty) {
      return cleanUsername.startsWith('@') ? cleanUsername : '@$cleanUsername';
    }

    return isOwnProfile ? 'Du' : 'Profil';
  }

  String get _safeAuthorSubtitle {
    final cleanUsername = profileUsername.trim();

    if (cleanUsername.isEmpty) {
      return isOwnProfile ? 'Profilbeitrag' : 'Profilbeitrag';
    }

    return cleanUsername.startsWith('@') ? cleanUsername : '@$cleanUsername';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final visibleMoments = moments.take(3).toList(growable: false);
    final cleanErrorMessage = errorMessage?.trim() ?? '';
    final showFooter = moments.length > visibleMoments.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.62)
            : const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.12)
              : const Color(0xFFEADFD2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.08 : 0.018),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
              child: ProfileTimelineStateCard(
                icon: Icons.article_outlined,
                title: 'Beiträge werden geladen',
                message: 'Luma lädt gerade die sichtbaren Profilbeiträge.',
                trailing: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
          ] else if (cleanErrorMessage.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
              child: ProfileTimelineStateCard(
                icon: Icons.cloud_off_outlined,
                iconColor: colorScheme.error,
                title: 'Beiträge konnten nicht geladen werden',
                message: cleanErrorMessage,
              ),
            ),
          ] else if (!_hasMoments) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
              child: ProfileTimelineStateCard(
                icon: isOwnProfile
                    ? Icons.edit_note_rounded
                    : Icons.notes_outlined,
                title: isOwnProfile
                    ? 'Noch kein Beitrag auf deinem Profil'
                    : 'Noch keine sichtbaren Beiträge',
                message: isOwnProfile
                    ? 'Dein erster Beitrag erscheint hier, sobald du oben etwas teilst.'
                    : 'Dieses Profil hat aktuell keine sichtbaren Beiträge freigegeben.',
              ),
            ),
          ] else ...[
            for (var index = 0; index < visibleMoments.length; index++) ...[
              if (index > 0)
                Container(
                  height: 6,
                  color: isDark
                      ? colorScheme.surface.withValues(alpha: 0.22)
                      : const Color(0xFFF5EEE6),
                ),
              ProfileTimelineMomentCard(
                moment: visibleMoments[index],
                canManage: isOwnProfile,
                authorName: _safeAuthorName,
                authorSubtitle: _safeAuthorSubtitle,
                authorImageUrl: profileImageUrl,
                onEdit: () => onEditMoment(visibleMoments[index]),
                onDelete: () => onDeleteMoment(visibleMoments[index]),
                onTaggedFriendTap: onTaggedFriendTap,
                onToggleLike: () => onToggleLike(visibleMoments[index]),
                onCommentTap: () => onCommentTap(visibleMoments[index]),
                onLikeSummaryTap: () => onLikeSummaryTap(visibleMoments[index]),
              ),
            ],
            if (showFooter) ...[
              Container(
                height: 8,
                color: isDark
                    ? colorScheme.surface.withValues(alpha: 0.22)
                    : const Color(0xFFF5EEE6),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
                child: ProfileTimelineFooterButton(
                  label: 'Alle ${moments.length} Beiträge ansehen',
                  onTap: onViewAllPosts,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class ProfileTimelineMomentCard extends StatelessWidget {
  const ProfileTimelineMomentCard({
    required this.moment,
    required this.canManage,
    required this.authorName,
    required this.authorSubtitle,
    required this.authorImageUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onTaggedFriendTap,
    required this.onToggleLike,
    required this.onCommentTap,
    required this.onLikeSummaryTap,
  });

  final profile_posts.ProfileMomentPreviewData moment;
  final bool canManage;
  final String authorName;
  final String authorSubtitle;
  final String authorImageUrl;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final void Function(String friendUserId) onTaggedFriendTap;
  final Future<void> Function() onToggleLike;
  final VoidCallback onCommentTap;
  final VoidCallback onLikeSummaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cleanText = moment.text.trim();
    final cleanMoodLabel = moment.moodLabel.trim();
    final cleanAuthorName =
        authorName.trim().isEmpty ? 'Profil' : authorName.trim();
    final cleanAuthorSubtitle = authorSubtitle.trim();
    final cleanAuthorImageUrl = authorImageUrl.trim();
    final taggedNames = moment.taggedFriendNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final taggedIds = moment.taggedFriendIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileTimelineAuthorAvatar(
                displayName: cleanAuthorName,
                imageUrl: cleanAuthorImageUrl,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: ProfileTimelineAuthorBlock(
                  authorName: cleanAuthorName,
                  authorSubtitle: cleanAuthorSubtitle,
                  createdAt: moment.createdAt,
                ),
              ),
              if (canManage)
                ProfileTimelineManageMenu(
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
            ],
          ),
          if (cleanText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              cleanText,
              maxLines: 10,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.94),
                fontSize: 16.8,
                height: 1.34,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.08,
              ),
            ),
          ],
          if (moment.hasImage) ...[
            const SizedBox(height: 10),
            ProfileTimelineMomentImage(imageUrl: moment.mediaUrl),
          ],
          if (cleanMoodLabel.isNotEmpty || taggedNames.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (cleanMoodLabel.isNotEmpty)
                  ProfileTimelineTagChip(
                    icon: Icons.mood_outlined,
                    label: cleanMoodLabel,
                  ),
                for (var index = 0; index < taggedNames.length; index++)
                  ProfileTimelineTagChip(
                    icon: Icons.person_outline_rounded,
                    label: taggedNames[index],
                    onTap: index < taggedIds.length
                        ? () => onTaggedFriendTap(taggedIds[index])
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 9),
          ProfileTimelineSocialMetaRow(
            likeCount: moment.likeCount,
            commentCount: moment.commentCount,
            onLikeSummaryTap: onLikeSummaryTap,
          ),
          const SizedBox(height: 5),
          ProfileTimelineActionBar(
            isLiked: moment.isLikedByCurrentUser,
            onLikeTap: onToggleLike,
            onCommentTap: onCommentTap,
          ),
        ],
      ),
    );
  }
}


class ProfileTimelineMomentImage extends StatelessWidget {
  final String imageUrl;

  const ProfileTimelineMomentImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 180,
          maxHeight: 360,
        ),
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : const Color(0xFFF8F2EC),
        child: Image.network(
          cleanUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 190,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                'Foto konnte nicht geladen werden',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.56),
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProfileTimelineManageMenu extends StatelessWidget {
  const ProfileTimelineManageMenu({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      tooltip: 'Beitrag verwalten',
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
          return;
        }

        if (value == 'delete') {
          onDelete();
        }
      },
      color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.14)
              : const Color(0xFFE3D7CA),
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Bearbeiten'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: colorScheme.error,
              ),
              const SizedBox(width: 10),
              Text(
                'Löschen',
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.045),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          color: colorScheme.onSurface.withValues(alpha: 0.48),
          size: 19,
        ),
      ),
    );
  }
}

class ProfileTimelineAuthorAvatar extends StatelessWidget {
  const ProfileTimelineAuthorAvatar({
    required this.displayName,
    required this.imageUrl,
  });

  final String displayName;
  final String imageUrl;

  String get _initial {
    final cleanName = displayName.trim();

    if (cleanName.isEmpty) return 'L';

    final firstRune = cleanName.runes.first;
    return String.fromCharCode(firstRune).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cleanImageUrl = imageUrl.trim();

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: 0.13),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: cleanImageUrl.isEmpty
          ? Center(
              child: Text(
                _initial,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
            )
          : Image.network(
              cleanImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    _initial,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                );
              },
            ),
    );
  }
}

class ProfileTimelineAuthorBlock extends StatelessWidget {
  const ProfileTimelineAuthorBlock({
    required this.authorName,
    required this.authorSubtitle,
    required this.createdAt,
  });

  final String authorName;
  final String authorSubtitle;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cleanSubtitle = authorSubtitle.trim();
    final dateText = ProfileUtils.formatProfileMomentDate(createdAt);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 16.2,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: -0.12,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Flexible(
                child: Text(
                  cleanSubtitle.isEmpty
                      ? dateText
                      : '$cleanSubtitle · $dateText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.50),
                    fontSize: 12.1,
                    fontWeight: FontWeight.w700,
                    height: 1.10,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.public_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.40),
                size: 13,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileTimelineSocialMetaRow extends StatelessWidget {
  const ProfileTimelineSocialMetaRow({
    required this.likeCount,
    required this.commentCount,
    required this.onLikeSummaryTap,
  });

  final int likeCount;
  final int commentCount;
  final VoidCallback onLikeSummaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final safeLikeCount = likeCount < 0 ? 0 : likeCount;
    final safeCommentCount = commentCount < 0 ? 0 : commentCount;

    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: safeLikeCount > 0 ? onLikeSummaryTap : null,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 8, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.13,
                        ),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Icon(
                        Icons.thumb_up_alt_rounded,
                        color: colorScheme.primary,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _buildLikeLabel(safeLikeCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.56),
                        fontSize: 12.4,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: -0.01,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 10),
          Text(
_buildCommentMetaLabel(safeCommentCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.56),
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: -0.01,
            ),
          ),
        ],
      ),
    );
  }

  String _buildLikeLabel(int count) {
    if (count <= 0) return 'Sei die erste Person, der das gefällt';
    if (count == 1) return '1 Person gefällt das';
    return '$count Personen gefällt das';
  }

  String _buildCommentMetaLabel(int commentCount) {
    if (commentCount <= 0) return 'Kommentieren';
    if (commentCount == 1) return '1 Kommentar';
    return '$commentCount Kommentare';
  }
}

class ProfileTimelineActionBar extends StatelessWidget {
  const ProfileTimelineActionBar({
    required this.isLiked,
    required this.onLikeTap,
    required this.onCommentTap,
  });

  final bool isLiked;
  final Future<void> Function() onLikeTap;
  final VoidCallback onCommentTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? colorScheme.outline.withValues(alpha: 0.13)
                : const Color(0xFFE9DED2),
          ),
        ),
      ),
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: ProfileTimelineActionButton(
              icon: isLiked
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_alt_outlined,
              label: 'Gefällt mir',
              isActive: isLiked,
              onTap: onLikeTap,
            ),
          ),
          Expanded(
            child: ProfileTimelineActionButton(
              icon: Icons.mode_comment_outlined,
              label: 'Kommentieren',
              onTap: onCommentTap,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileTimelineActionButton extends StatelessWidget {
  const ProfileTimelineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedColor = isActive
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.66);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: resolvedColor,
                size: 18,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: resolvedColor,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.02,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTimelineTagChip extends StatelessWidget {
  const ProfileTimelineTagChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.38)
            : const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.12)
              : const Color(0xFFE7DBCF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: colorScheme.onSurface.withValues(alpha: 0.52),
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.64),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }
}

class ProfileTimelineStateCard extends StatelessWidget {
  const ProfileTimelineStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.actionLabel,
    this.onActionTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final resolvedIconColor = iconColor ?? colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.34)
            : const Color(0xFFF9F3EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.12)
              : const Color(0xFFE4D8CB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: resolvedIconColor.withValues(alpha: isDark ? 0.13 : 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: resolvedIconColor.withValues(alpha: 0.86),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                    letterSpacing: -0.04,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 12.1,
                    height: 1.34,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (actionLabel != null && onActionTap != null) ...[
                  const SizedBox(height: 9),
                  ProfileTimelineInlineButton(
                    label: actionLabel!,
                    onTap: onActionTap!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class ProfileTimelineFooterButton extends StatelessWidget {
  const ProfileTimelineFooterButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? colorScheme.surface.withValues(alpha: 0.34)
          : const Color(0xFFF8F2EC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withValues(alpha: 0.12)
                  : const Color(0xFFE3D7CA),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontSize: 12.6,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: colorScheme.primary,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTimelineInlineButton extends StatelessWidget {
  const ProfileTimelineInlineButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontSize: 11.8,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileTimelineIconButton extends StatelessWidget {
  const ProfileTimelineIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
