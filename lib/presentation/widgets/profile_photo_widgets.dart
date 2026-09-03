// Pfad: lib/presentation/widgets/profile_photo_widgets.dart

import 'package:flutter/material.dart';

import '../../domain/models/profile_photo_model.dart';

class ProfilePhotoPreviewItemData {
  const ProfilePhotoPreviewItemData({
    required this.imageUrl,
    required this.label,
    required this.icon,
    this.type,
    this.createdAt,
  });

  final String imageUrl;
  final String label;
  final IconData icon;
  final ProfilePhotoType? type;
  final DateTime? createdAt;
}

class _ProfilePhotoPreviewTile extends StatefulWidget {
  final ProfilePhotoPreviewItemData photo;
  final VoidCallback onTap;
  final int extraCount;

  const _ProfilePhotoPreviewTile({
    required this.photo,
    required this.onTap,
    this.extraCount = 0,
  });

  @override
  State<_ProfilePhotoPreviewTile> createState() =>
      _ProfilePhotoPreviewTileState();
}

class _ProfilePhotoPreviewTileState extends State<_ProfilePhotoPreviewTile> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;

    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cleanImageUrl = widget.photo.imageUrl.trim();
    final radius = BorderRadius.circular(14);

    final tile = AnimatedScale(
      scale: _isPressed ? 0.982 : 1,
      duration: const Duration(milliseconds: 115),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _isPressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 115),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.030)
                  : Colors.white.withValues(alpha: 0.42),
              borderRadius: radius,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.040)
                    : const Color(0xFFEDE2D6).withValues(alpha: 0.46),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: isDark ? 0.040 : 0.014,
                  ),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cleanImageUrl.isNotEmpty)
                  Image.network(
                    cleanImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _ProfilePhotoPreviewFallback(
                        icon: widget.photo.icon,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _ProfilePhotoPreviewFallback(
                        icon: widget.photo.icon,
                      );
                    },
                  )
                else
                  _ProfilePhotoPreviewFallback(
                    icon: widget.photo.icon,
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.035),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.22),
                      ],
                      stops: const [0, 0.50, 1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  left: 7,
                  right: 7,
                  bottom: 7,
                  child: Text(
                    widget.photo.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.7,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -0.03,
                    ),
                  ),
                ),
                if (widget.extraCount > 0)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.44),
                    ),
                    child: Center(
                      child: Text(
                        '+${widget.extraCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: tile,
    );
  }
}

class ProfilePhotosGrid extends StatelessWidget {
  final List<ProfilePhotoPreviewItemData> photos;
  final ValueChanged<ProfilePhotoPreviewItemData> onPhotoTap;

  const ProfilePhotosGrid({
    required this.photos,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];

        return _ProfilePhotoPreviewTile(
          photo: photo,
          onTap: () => onPhotoTap(photo),
        );
      },
    );
  }
}

class ProfilePhotosEmptySheetState extends StatelessWidget {
  final bool isOwnProfile;

  const ProfilePhotosEmptySheetState({
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.028)
            : Colors.white.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.035)
              : const Color(0xFFEDE2D6).withValues(alpha: 0.52),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: colorScheme.primary.withValues(alpha: 0.70),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOwnProfile
                  ? 'Füge ein Profilbild oder Titelbild hinzu, damit deine Fotos hier erscheinen.'
                  : 'Dieses Profil hat aktuell keine sichtbaren Fotos.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.56),
                fontSize: 12.7,
                height: 1.28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePhotoFullscreenViewer extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String displayName;
  final String username;

  const ProfilePhotoFullscreenViewer({
    required this.imageUrl,
    required this.title,
    required this.displayName,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final safeUsername = username.trim().isEmpty
        ? ''
        : username.trim().startsWith('@')
            ? username.trim()
            : '@${username.trim()}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity > 620) {
                    Navigator.of(context).pop();
                  }
                },
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 52,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton.filled(
                      onPressed: () => Navigator.of(context).pop(),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.2,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            safeUsername.isEmpty
                                ? displayName
                                : '$displayName · $safeUsername',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 11.7,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoPreviewFallback extends StatelessWidget {
  final IconData icon;

  const _ProfilePhotoPreviewFallback({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.075),
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.090),
          ),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary.withValues(alpha: 0.72),
          size: 20,
        ),
      ),
    );
  }
}
