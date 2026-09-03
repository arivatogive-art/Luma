import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/models/private_profile_model.dart';

class ProfileHeader extends StatelessWidget {
  final PrivateProfileModel profile;
  final bool isOwnProfile;
  final VoidCallback? onEditProfile;
  final VoidCallback? onEditProfileImage;
  final VoidCallback? onEditCoverImage;
  final VoidCallback? onOpenProfileOptions;
  final VoidCallback? onViewProfileImage;
  final VoidCallback? onViewCoverImage;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    this.onEditProfile,
    this.onEditProfileImage,
    this.onEditCoverImage,
    this.onOpenProfileOptions,
    this.onViewProfileImage,
    this.onViewCoverImage,
  });

  static const Color _coverOverlayTop = Color(0x08000000);
  static const Color _coverOverlayBottom = Color(0xC9000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'Unbekannter Nutzer';

    final username = profile.username.trim().isNotEmpty
        ? profile.username.trim()
        : '@unbekannt';

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.94)
            : colorScheme.surface.withValues(alpha: 0.985),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.14 : 0.052,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCover(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Transform.translate(
              offset: const Offset(0, -38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildAvatar(context),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildIdentityBlock(
                            context: context,
                            displayName: displayName,
                            username: username,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  _buildHeaderBio(context),
                  const SizedBox(height: 14),
                  _buildIdentityMetaRow(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final coverImageSource = profile.coverImageUrl.trim();
    final hasCover = coverImageSource.isNotEmpty;
    final coverAction = isOwnProfile ? onEditCoverImage : onViewCoverImage;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Stack(
        children: [
          SizedBox(
            height: 208,
            width: double.infinity,
            child: hasCover
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _openFullscreenMedia(
                        context: context,
                        source: coverImageSource,
                        heroTag: 'profile_cover_${profile.userId}',
                        title: 'Titelbild',
                      );
                    },
                    child: Hero(
                      tag: 'profile_cover_${profile.userId}',
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImageBySource(
                            source: coverImageSource,
                            fit: BoxFit.cover,
                            fallback: _buildCoverFallback(context),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _coverOverlayTop,
                                  _coverOverlayBottom,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildCoverFallback(context),
          ),
          Positioned(
            left: 14,
            bottom: 12,
            child: _buildCoverInfoPill(
              label: hasCover ? 'Titelbild' : 'Profilbereich',
            ),
          ),
          if (coverAction != null)
            Positioned(
              right: 14,
              top: 12,
              child: _HeaderMediaButton(
                icon: isOwnProfile
                    ? Icons.camera_alt_outlined
                    : Icons.visibility_outlined,
                label: isOwnProfile
                    ? (hasCover ? 'Titelbild bearbeiten' : 'Titelbild hinzufügen')
                    : 'Titelbild ansehen',
                onTap: coverAction,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoverFallback(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            colorScheme.surfaceContainerHigh,
            colorScheme.surfaceContainer,
            colorScheme.surfaceContainerLow,
          ]
        : [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.surfaceContainer,
            colorScheme.surface,
          ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -34,
            right: -22,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.026),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -34,
            left: -16,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.055),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(
                Icons.image_outlined,
                color: colorScheme.onSurface.withValues(alpha: 0.11),
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverInfoPill({
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.13),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.02,
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final profileImageSource = profile.profileImageUrl.trim();
    final hasProfileImage = profileImageSource.isNotEmpty;
    final avatarAction = isOwnProfile ? onEditProfileImage : onViewProfileImage;

    final avatar = Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.surfaceContainerHigh,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: hasProfileImage
            ? _buildImageBySource(
                source: profileImageSource,
                fit: BoxFit.cover,
                fallback: _buildAvatarFallback(context),
              )
            : _buildAvatarFallback(context),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        hasProfileImage
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _openFullscreenMedia(
                    context: context,
                    source: profileImageSource,
                    heroTag: 'profile_avatar_${profile.userId}',
                    title: 'Profilbild',
                  );
                },
                child: Hero(
                  tag: 'profile_avatar_${profile.userId}',
                  child: avatar,
                ),
              )
            : avatar,
        if (profile.isVerified)
          const Positioned(
            right: 2,
            bottom: 6,
            child: _VerifiedBadge(),
          ),
        if (avatarAction != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: _HeaderCircleActionButton(
              icon: isOwnProfile
                  ? Icons.camera_alt_outlined
                  : Icons.visibility_outlined,
              onTap: avatarAction,
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Icon(
        Icons.person,
        color: colorScheme.onPrimary,
        size: 50,
      ),
    );
  }

  Widget _buildImageBySource({
    required String source,
    required BoxFit fit,
    required Widget fallback,
  }) {
    final normalizedSource = source.trim();

    if (normalizedSource.isEmpty) {
      return fallback;
    }

    if (_isDataImageSource(normalizedSource)) {
      final bytes = _decodeDataImage(normalizedSource);

      if (bytes == null || bytes.isEmpty) {
        return fallback;
      }

      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    if (_isNetworkSource(normalizedSource)) {
      return Image.network(
        normalizedSource,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallback;
        },
      );
    }

    if (_isLocalFileSource(normalizedSource) && !kIsWeb) {
      final localPath = normalizedSource.startsWith('file://')
          ? normalizedSource.replaceFirst('file://', '')
          : normalizedSource;

      return Image.file(
        File(localPath),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return fallback;
  }

  bool _isDataImageSource(String value) {
    return value.toLowerCase().startsWith('data:image/');
  }

  bool _isNetworkSource(String value) {
    final lower = value.toLowerCase();

    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('blob:');
  }

  bool _isLocalFileSource(String value) {
    if (value.isEmpty) return false;

    final lower = value.toLowerCase();

    return lower.startsWith('file://') ||
        value.startsWith('/') ||
        value.startsWith(r'\') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  }

  Uint8List? _decodeDataImage(String source) {
    try {
      final commaIndex = source.indexOf(',');

      if (commaIndex < 0 || commaIndex >= source.length - 1) {
        return null;
      }

      final base64Part = source.substring(commaIndex + 1).trim();

      if (base64Part.isEmpty) {
        return null;
      }

      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  void _openFullscreenMedia({
    required BuildContext context,
    required String source,
    required String heroTag,
    required String title,
  }) {
    final normalizedSource = source.trim();

    if (normalizedSource.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ProfileMediaFullscreenViewer(
            source: normalizedSource,
            heroTag: heroTag,
            title: title,
            displayName: profile.displayName.trim().isNotEmpty
                ? profile.displayName.trim()
                : 'Luma Nutzer',
            username: profile.username.trim().isNotEmpty
                ? profile.username.trim()
                : '@luma',
            avatarSource: profile.profileImageUrl.trim(),
            isVerified: profile.isVerified,
            imageBuilder: ({
              required String source,
              required BoxFit fit,
              required Widget fallback,
            }) {
              return _buildImageBySource(
                source: source,
                fit: fit,
                fallback: fallback,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildIdentityBlock({
    required BuildContext context,
    required String displayName,
    required String username,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutualFriendsCount = profile.mutualFriendsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 25.5,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                  letterSpacing: -0.30,
                ),
              ),
            ),
            if (profile.isVerified) ...[
              const SizedBox(width: 7),
              const Icon(
                Icons.verified,
                color: Colors.blue,
                size: 18,
              ),
            ],
            if (isOwnProfile && onEditProfile != null) ...[
              const SizedBox(width: 8),
              _HeaderEditProfileButton(onTap: onEditProfile!),
            ],
            if (isOwnProfile && onOpenProfileOptions != null) ...[
              const SizedBox(width: 8),
              _HeaderOptionsButton(onTap: onOpenProfileOptions!),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.68),
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!isOwnProfile && mutualFriendsCount > 0) ...[
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  _buildMutualFriendsText(mutualFriendsCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderBio(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bio = profile.bio.trim();
    final hasBio = bio.isNotEmpty;

    if (!hasBio) {
      if (!isOwnProfile) {
        return const SizedBox.shrink();
      }

      return Text(
        'Füge eine kurze Biografie hinzu, damit dein Profil persönlicher wirkt.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.48),
          fontSize: 13.8,
          height: 1.44,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Text(
      bio,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface.withValues(alpha: 0.76),
        fontSize: 14.3,
        height: 1.46,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildIdentityMetaRow(BuildContext context) {
    final canEditBio = isOwnProfile && onEditProfile != null;
    final hasBio = profile.bio.trim().isNotEmpty;

    final statCards = <Widget>[
      Expanded(
        child: _ProfileStatCard(
          icon: profile.postsCount > 0
              ? Icons.grid_view_rounded
              : Icons.grid_view_outlined,
          value: profile.postsCount.toString(),
          label: profile.postsCount == 1 ? 'Moment' : 'Momente',
          highlighted: profile.postsCount > 0,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ProfileStatCard(
          icon: profile.friendsCount > 0
              ? Icons.groups_rounded
              : Icons.group_outlined,
          value: profile.friendsCount.toString(),
          label: profile.friendsCount == 1 ? 'Freund' : 'Freunde',
          highlighted: profile.friendsCount > 0,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: statCards),
        if (canEditBio && !hasBio) ...[
          const SizedBox(height: 10),
          _ProfileBioActionCard(
            hasBio: hasBio,
            onTap: onEditProfile,
          ),
        ],
      ],
    );
  }

  String _buildMutualFriendsText(int count) {
    if (count == 1) {
      return '1 gemeinsame Verbindung';
    }

    return '$count gemeinsame Verbindungen';
  }
}

typedef _ProfileMediaImageBuilder = Widget Function({
  required String source,
  required BoxFit fit,
  required Widget fallback,
});

class _ProfileMediaFullscreenViewer extends StatefulWidget {
  const _ProfileMediaFullscreenViewer({
    required this.source,
    required this.heroTag,
    required this.title,
    required this.displayName,
    required this.username,
    required this.avatarSource,
    required this.isVerified,
    required this.imageBuilder,
  });

  final String source;
  final String heroTag;
  final String title;
  final String displayName;
  final String username;
  final String avatarSource;
  final bool isVerified;
  final _ProfileMediaImageBuilder imageBuilder;

  @override
  State<_ProfileMediaFullscreenViewer> createState() =>
      _ProfileMediaFullscreenViewerState();
}

class _ProfileMediaFullscreenViewerState
    extends State<_ProfileMediaFullscreenViewer> {
  final TextEditingController _commentController = TextEditingController();

  final List<_LocalMediaComment> _comments = const <_LocalMediaComment>[];

  bool _isLiked = false;
  int _likeCount = 0;

  int get _commentCount => _comments.length;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;

      if (_likeCount < 0) {
        _likeCount = 0;
      }
    });
  }

  void _submitComment() {
    final text = _commentController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _commentController.clear();
      _comments.insert(
        0,
        _LocalMediaComment(
          authorName: 'Du',
          text: text,
          createdLabel: 'Gerade eben',
        ),
      );
    });
  }

  void _shareMedia() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Teilen ist als UI vorbereitet. Die echte Teilen-Logik folgt separat.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;

                if (velocity > 620) {
                  Navigator.of(context).pop();
                }
              },
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF050505),
                      Colors.black,
                      Color(0xFF050505),
                    ],
                  ),
                ),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: widget.imageBuilder(
                        source: widget.source,
                        fit: BoxFit.contain,
                        fallback: const _ProfileMediaViewerFallback(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  _ProfileMediaViewerHeader(
                    title: widget.title,
                    displayName: widget.displayName,
                    username: widget.username,
                    avatarSource: widget.avatarSource,
                    isVerified: widget.isVerified,
                    onClose: () => Navigator.of(context).pop(),
                    imageBuilder: widget.imageBuilder,
                    trailing: !isWide
                        ? _MediaQuickActions(
                            isLiked: _isLiked,
                            likeCount: _likeCount,
                            commentCount: _commentCount,
                            onLikeTap: _toggleLike,
                            onCommentTap: () {
                              FocusScope.of(context).requestFocus(FocusNode());
                            },
                            onShareTap: _shareMedia,
                          )
                        : null,
                  ),
                  const Spacer(),
                  if (isWide)
                    Align(
                      alignment: Alignment.centerRight,
                      child: _MediaInteractionPanel(
                        title: widget.title,
                        isLiked: _isLiked,
                        likeCount: _likeCount,
                        commentCount: _commentCount,
                        comments: _comments,
                        controller: _commentController,
                        onLikeTap: _toggleLike,
                        onShareTap: _shareMedia,
                        onSubmitComment: _submitComment,
                      ),
                    )
                  else
                    _MediaBottomCommentBar(
                      controller: _commentController,
                      onSubmitComment: _submitComment,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _ProfileMediaViewerHeader extends StatelessWidget {
  const _ProfileMediaViewerHeader({
    required this.title,
    required this.displayName,
    required this.username,
    required this.avatarSource,
    required this.isVerified,
    required this.onClose,
    required this.imageBuilder,
    this.trailing,
  });

  final String title;
  final String displayName;
  final String username;
  final String avatarSource;
  final bool isVerified;
  final VoidCallback onClose;
  final _ProfileMediaImageBuilder imageBuilder;
  final Widget? trailing;

  String get _safeUsername {
    final value = username.trim();

    if (value.isEmpty) return '@luma';

    return value.startsWith('@') ? value : '@$value';
  }

  String get _initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'LU';

    if (parts.length == 1) {
      final first = parts.first;

      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  bool get _hasAvatar {
    return avatarSource.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final mediaTypeLabel = title == 'Titelbild'
        ? 'Titelbild'
        : title == 'Profilbild'
            ? 'Profilbild'
            : 'Profilmedium';

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: onClose,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              minimumSize: const Size(38, 38),
            ),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE58A2B).withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _hasAvatar
                ? imageBuilder(
                    source: avatarSource,
                    fit: BoxFit.cover,
                    fallback: _ProfileMediaAvatarFallback(
                      initials: _initials,
                    ),
                  )
                : _ProfileMediaAvatarFallback(
                    initials: _initials,
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName.trim().isEmpty ? 'Luma Nutzer' : displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.8,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 15,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _safeUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      mediaTypeLabel == 'Titelbild'
                          ? Icons.landscape_outlined
                          : Icons.account_circle_outlined,
                      color: Colors.white.withValues(alpha: 0.48),
                      size: 12,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      mediaTypeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
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

class _ProfileMediaAvatarFallback extends StatelessWidget {
  const _ProfileMediaAvatarFallback({
    required this.initials,
  });

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE58A2B).withValues(alpha: 0.18),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFFE58A2B),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MediaQuickActions extends StatelessWidget {
  const _MediaQuickActions({
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
  });

  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MediaRoundActionButton(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: likeCount > 0 ? '$likeCount' : 'Like',
          active: isLiked,
          onTap: onLikeTap,
        ),
        const SizedBox(width: 8),
        _MediaRoundActionButton(
          icon: Icons.mode_comment_outlined,
          label: commentCount > 0 ? '$commentCount' : 'Kommentar',
          onTap: onCommentTap,
        ),
        const SizedBox(width: 8),
        _MediaRoundActionButton(
          icon: Icons.share_outlined,
          label: 'Teilen',
          onTap: onShareTap,
        ),
      ],
    );
  }
}

class _MediaInteractionPanel extends StatelessWidget {
  const _MediaInteractionPanel({
    required this.title,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.comments,
    required this.controller,
    required this.onLikeTap,
    required this.onShareTap,
    required this.onSubmitComment,
  });

  final String title;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final List<_LocalMediaComment> comments;
  final TextEditingController controller;
  final VoidCallback onLikeTap;
  final VoidCallback onShareTap;
  final VoidCallback onSubmitComment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      margin: const EdgeInsets.only(right: 4, bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE58A2B).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  title == 'Titelbild'
                      ? Icons.landscape_outlined
                      : Icons.account_circle_outlined,
                  color: const Color(0xFFE58A2B),
                  size: 18,
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.94),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Profilmedien',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MediaPanelActionButton(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: likeCount > 0 ? '$likeCount' : 'Like',
                  active: isLiked,
                  onTap: onLikeTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MediaPanelActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: commentCount > 0 ? '$commentCount' : 'Kommentar',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MediaPanelActionButton(
                  icon: Icons.share_outlined,
                  label: 'Teilen',
                  onTap: onShareTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MediaCommentsPreview(
            comments: comments,
          ),
          const SizedBox(height: 12),
          _MediaBottomCommentBar(
            controller: controller,
            onSubmitComment: onSubmitComment,
          ),
        ],
      ),
    );
  }
}


class _LocalMediaComment {
  const _LocalMediaComment({
    required this.authorName,
    required this.text,
    required this.createdLabel,
  });

  final String authorName;
  final String text;
  final String createdLabel;
}

class _MediaCommentsPreview extends StatelessWidget {
  const _MediaCommentsPreview({
    required this.comments,
  });

  final List<_LocalMediaComment> comments;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE58A2B).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.mode_comment_outlined,
                color: Color(0xFFE58A2B),
                size: 18,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Noch keine Kommentare',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Schreibe den ersten Kommentar zu diesem Bild.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final visibleComments = comments.take(3).toList(growable: false);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 210),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: visibleComments.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 9);
        },
        itemBuilder: (context, index) {
          final comment = visibleComments[index];

          return _MediaCommentBubble(comment: comment);
        },
      ),
    );
  }
}

class _MediaCommentBubble extends StatelessWidget {
  const _MediaCommentBubble({
    required this.comment,
  });

  final _LocalMediaComment comment;

  @override
  Widget build(BuildContext context) {
    final initial = comment.authorName.trim().isEmpty
        ? 'L'
        : comment.authorName.trim().characters.first.toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: const Color(0xFFE58A2B).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE58A2B).withValues(alpha: 0.22),
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFFE58A2B),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.4,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Text(
                      comment.createdLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 12.4,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaBottomCommentBar extends StatelessWidget {
  const _MediaBottomCommentBar({
    required this.controller,
    required this.onSubmitComment,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitComment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: const Color(0xFFE58A2B),
              decoration: InputDecoration(
                hintText: 'Kommentar schreiben...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSubmitComment,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE58A2B),
            ),
            icon: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaRoundActionButton extends StatelessWidget {
  const _MediaRoundActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFE58A2B) : Colors.white;

    return Material(
      color: Colors.black.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPanelActionButton extends StatelessWidget {
  const _MediaPanelActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFE58A2B) : Colors.white;

    return Material(
      color: Colors.white.withValues(alpha: active ? 0.14 : 0.08),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMediaViewerFallback extends StatelessWidget {
  const _ProfileMediaViewerFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.broken_image_outlined,
      color: Colors.white70,
      size: 52,
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: colorScheme.scrim.withValues(alpha: 0.78),
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.surface, width: 1.5),
      ),
      child: const Center(
        child: Icon(
          Icons.verified,
          color: Colors.blue,
          size: 15,
        ),
      ),
    );
  }
}

class _HeaderEditProfileButton extends StatelessWidget {
  const _HeaderEditProfileButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.10),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: colorScheme.primary.withValues(alpha: 0.06),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.15),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Icon(
            Icons.edit_outlined,
            color: colorScheme.primary.withValues(alpha: 0.92),
            size: 15.5,
          ),
        ),
      ),
    );
  }
}

class _HeaderOptionsButton extends StatelessWidget {
  const _HeaderOptionsButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: colorScheme.surface.withValues(alpha: isDark ? 0.44 : 0.74),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: colorScheme.onSurface.withValues(alpha: 0.05),
        highlightColor: colorScheme.onSurface.withValues(alpha: 0.04),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: isDark ? 0.13 : 0.16),
            ),
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            color: colorScheme.onSurface.withValues(alpha: isDark ? 0.58 : 0.52),
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? colorScheme.surface.withValues(alpha: 0.46)
        : const Color(0xFFFCF8F2);

    final borderColor = highlighted
        ? colorScheme.primary.withValues(alpha: 0.22)
        : isDark
            ? colorScheme.outline.withValues(alpha: 0.16)
            : const Color(0xFFE4D8CB);

    final iconBackgroundColor = highlighted
        ? colorScheme.primary.withValues(alpha: 0.12)
        : isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.32)
            : const Color(0xFFF2E7DA);

    final iconColor = highlighted
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.58);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF3B2B20).withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: highlighted
                    ? colorScheme.primary.withValues(alpha: 0.14)
                    : colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 19.2,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBioActionCard extends StatelessWidget {
  const _ProfileBioActionCard({
    required this.hasBio,
    this.onTap,
  });

  final bool hasBio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.38)
            : const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.14)
              : const Color(0xFFE4D8CB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note_rounded,
            color: hasBio
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.52),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              hasBio ? 'Biografie vorhanden' : 'Biografie hinzufügen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasBio
                    ? colorScheme.onSurface.withValues(alpha: 0.72)
                    : colorScheme.onSurface.withValues(alpha: 0.56),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.42),
              size: 20,
            ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      ),
    );
  }
}

class _HeaderMediaButton extends StatelessWidget {
  const _HeaderMediaButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.34),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.90),
                size: 14.5,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.01,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCircleActionButton extends StatelessWidget {
  const _HeaderCircleActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: colorScheme.primary.withValues(alpha: isDark ? 0.94 : 0.90),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: colorScheme.onPrimary.withValues(alpha: 0.10),
        highlightColor: colorScheme.onPrimary.withValues(alpha: 0.06),
        child: Container(
          width: 33,
          height: 33,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.onPrimary.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: isDark ? 0.16 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: colorScheme.onPrimary.withValues(alpha: 0.94),
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}
