// Pfad: lib/presentation/widgets/profile_friends_preview_card.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/models/private_profile_model.dart';

class ProfileFriendsPreviewCard extends StatelessWidget {
  const ProfileFriendsPreviewCard({
    super.key,
    required this.isOwnProfile,
    required this.friends,
    required this.onOpenFriendsList,
    required this.onOpenFriendProfile,
    this.isRestrictedByPrivacy = false,
  });

  final bool isOwnProfile;
  final List<PrivateProfileModel> friends;
  final VoidCallback onOpenFriendsList;
  final ValueChanged<PrivateProfileModel> onOpenFriendProfile;
  final bool isRestrictedByPrivacy;

  bool get _hasFriends => friends.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final topFriends = friends.take(8).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF102033).withValues(alpha: 0.36)
            : const Color(0xFFFFFCF8).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.040)
              : const Color(0xFFE8DCCE).withValues(alpha: 0.62),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.070 : 0.028),
            blurRadius: 22,
            spreadRadius: -14,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.012 : 0.50),
            blurRadius: 0,
            offset: const Offset(0, 1),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (isRestrictedByPrivacy) ...[
            const SizedBox(height: 10),
            _buildPrivacyRestrictedState(context),
          ] else if (_hasFriends) ...[
            const SizedBox(height: 11),
            _buildFriendsList(topFriends),
          ] else ...[
            const SizedBox(height: 10),
            _buildEmptyState(context),
          ],
          if (!isRestrictedByPrivacy) ...[
            const SizedBox(height: 9),
            _buildOpenTextAction(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Freunde',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.94)
                  : const Color(0xFF102033),
              fontSize: 17.8,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: -0.30,
            ),
          ),
        ),
        if (isRestrictedByPrivacy)
          _PrivateVisibilityPill(colorScheme: colorScheme),
      ],
    );
  }

  Widget _buildFriendsList(List<PrivateProfileModel> topFriends) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: topFriends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final friend = topFriends[index];

          return _FriendPreviewItem(
            profile: friend,
            onTap: () => onOpenFriendProfile(friend),
          );
        },
      ),
    );
  }

  Widget _buildPrivacyRestrictedState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.026)
            : const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.030)
              : const Color(0xFFE8DCCE).withValues(alpha: 0.54),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.115 : 0.080),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: isDark ? 0.13 : 0.10),
              ),
            ),
            child: Icon(
              Icons.lock_rounded,
              color: colorScheme.primary.withValues(alpha: 0.78),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Freundesliste privat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.78)
                        : const Color(0xFF102033),
                    fontSize: 13.2,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.04,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diese Freundesliste wurde für dich nicht freigegeben.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.54)
                        : const Color(0xFF756D65),
                    fontSize: 12.2,
                    height: 1.26,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.02,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.026)
            : const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.030)
              : const Color(0xFFE8DCCE).withValues(alpha: 0.54),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.people_outline_rounded,
            color: isDark
                ? Colors.white.withValues(alpha: 0.34)
                : const Color(0xFF756D65),
            size: 17,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOwnProfile
                  ? 'Deine Freunde erscheinen hier, sobald Verbindungen bestätigt wurden.'
                  : 'Dieses Profil zeigt derzeit keine Freunde an.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.56)
                    : const Color(0xFF756D65),
                fontSize: 12.4,
                height: 1.24,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.02,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenTextAction(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onOpenFriendsList,
          borderRadius: BorderRadius.circular(999),
          splashColor: colorScheme.primary.withValues(alpha: 0.055),
          highlightColor: colorScheme.primary.withValues(alpha: 0.028),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 7, 12, 7),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.120 : 0.090),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: isDark ? 0.150 : 0.115),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.035),
                    blurRadius: 14,
                    spreadRadius: -10,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOwnProfile ? 'Alle Freunde' : 'Freunde ansehen',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary.withValues(alpha: 0.92),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.05,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13.5,
                  color: colorScheme.primary.withValues(alpha: 0.78),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivateVisibilityPill extends StatelessWidget {
  const _PrivateVisibilityPill({
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 9, 5),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.035)
            : const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.045)
              : const Color(0xFFE8DCCE).withValues(alpha: 0.54),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            size: 11.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.42)
                : const Color(0xFF756D65),
          ),
          const SizedBox(width: 5),
          Text(
            'Privat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.46)
                  : const Color(0xFF756D65),
              fontSize: 11.4,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.03,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendPreviewItem extends StatefulWidget {
  const _FriendPreviewItem({
    required this.profile,
    required this.onTap,
  });

  final PrivateProfileModel profile;
  final VoidCallback onTap;

  @override
  State<_FriendPreviewItem> createState() => _FriendPreviewItemState();
}

class _FriendPreviewItemState extends State<_FriendPreviewItem> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayName = widget.profile.displayName.trim().isEmpty
        ? 'Unbekannter Nutzer'
        : widget.profile.displayName.trim();

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 105),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 78,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _IntegratedFriendImage(
                      imageUrl: widget.profile.profileImageUrl,
                      size: 68,
                    ),
                    if (widget.profile.isVerified)
                      const Positioned(
                        right: -1,
                        bottom: 1,
                        child: Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 17,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.94)
                        : const Color(0xFF102033),
                    fontSize: 12.6,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntegratedFriendImage extends StatelessWidget {
  const _IntegratedFriendImage({
    required this.imageUrl,
    required this.size,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = imageUrl.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.58),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.10 : 0.045),
            blurRadius: 13,
            spreadRadius: -7,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: source.isEmpty
          ? const _FriendImageFallback()
          : _isDataImageSource(source)
              ? _buildMemoryImage(source)
              : _isNetworkSource(source)
                  ? Image.network(
                      source,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const _FriendImageFallback();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const _FriendImageFallback();
                      },
                    )
                  : const _FriendImageFallback(),
    );
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

  Widget _buildMemoryImage(String source) {
    final bytes = _decodeDataImage(source);

    if (bytes == null || bytes.isEmpty) {
      return const _FriendImageFallback();
    }

    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const _FriendImageFallback();
      },
    );
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
}

class _FriendImageFallback extends StatelessWidget {
  const _FriendImageFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.primary,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 21,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
