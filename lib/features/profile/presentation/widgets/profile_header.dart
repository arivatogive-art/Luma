// Pfad: lib/features/profile/presentation/widgets/profile_header.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/profile_model.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  static const Color _coverOverlayTop = Color(0x08000000);
  static const Color _coverOverlayBottom = Color(0xA8000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.94)
              : colorScheme.surface.withValues(alpha: 0.99),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colorScheme.shadow.withValues(
                alpha: isDark ? 0.14 : 0.05,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildCover(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Transform.translate(
                offset: const Offset(0, -38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        _buildAvatar(context),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: _buildIdentity(context),
                          ),
                        ),
                      ],
                    ),
                    if (profile.hasBio) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        profile.bio,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.78),
                          fontSize: 14.3,
                          height: 1.46,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final source = profile.coverImageUrl.trim();

    return SizedBox(
      height: 208,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (source.isNotEmpty)
            Image.network(
              source,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('PROFILE COVER LOAD ERROR: $error');
                return _buildCoverFallback(context);
              },
            )
          else
            _buildCoverFallback(context),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  _coverOverlayTop,
                  _coverOverlayBottom,
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.13),
                ),
              ),
              child: Text(
                source.isNotEmpty ? 'Titelbild' : 'Profilbereich',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  colorScheme.surfaceContainerHigh,
                  colorScheme.surfaceContainer,
                  colorScheme.surfaceContainerLow,
                ]
              : <Color>[
                  colorScheme.primary.withValues(alpha: 0.16),
                  colorScheme.surfaceContainer,
                  colorScheme.surface,
                ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            Icons.image_outlined,
            size: 36,
            color: colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final source = profile.profileImageUrl.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.surface,
              width: 4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.24),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: source.isNotEmpty
                ? Image.network(
                    source,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: kIsWeb
                        ? WebHtmlElementStrategy.prefer
                        : WebHtmlElementStrategy.never,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('PROFILE AVATAR LOAD ERROR: $error');
                      return _buildAvatarFallback(context);
                    },
                  )
                : _buildAvatarFallback(context),
          ),
        ),
        if (profile.isVerified)
          Positioned(
            right: 2,
            bottom: 6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.verified,
                color: Colors.blue,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
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

  Widget _buildIdentity(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayName = profile.displayName.trim().isEmpty
        ? 'Luma Nutzer'
        : profile.displayName.trim();
    final username = profile.username.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
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
            if (profile.isVerified) ...<Widget>[
              const SizedBox(width: 7),
              const Icon(
                Icons.verified,
                color: Colors.blue,
                size: 18,
              ),
            ],
          ],
        ),
        if (username.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            username.startsWith('@') ? username : '@$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.68),
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
