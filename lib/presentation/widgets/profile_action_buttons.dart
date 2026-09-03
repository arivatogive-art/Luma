import 'package:flutter/material.dart';

import '../../domain/models/profile_relationship_status.dart';
import 'profile_action_buttons.dart';

class ProfileActionBarCard extends StatelessWidget {
  final ProfileRelationshipStatus relationshipStatus;
  final bool isOwnProfile;
  final bool allowFriendRequests;
  final VoidCallback onEditProfile;
  final Future<void> Function() onAddFriend;
  final Future<void> Function() onCancelRequest;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final Future<void> Function() onRemoveFriend;
  final VoidCallback onMessage;
  final Future<void> Function() onMarkAsFavorite;
  final VoidCallback onOpenProfileOptions;

  const ProfileActionBarCard({
    super.key,
    required this.relationshipStatus,
    required this.isOwnProfile,
    required this.allowFriendRequests,
    required this.onEditProfile,
    required this.onAddFriend,
    required this.onCancelRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onRemoveFriend,
    required this.onMessage,
    required this.onMarkAsFavorite,
    required this.onOpenProfileOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.54)
            : const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.12)
              : const Color(0xFFE9DDD0),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: isDark ? 0.08 : 0.018,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ProfileActionButtons(
                status: relationshipStatus,
                isOwnProfile: isOwnProfile,
                allowFriendRequests: allowFriendRequests,
                onEditProfile: onEditProfile,
                onAddFriend: onAddFriend,
                onCancelRequest: onCancelRequest,
                onAccept: onAccept,
                onDecline: onDecline,
                onRemoveFriend: onRemoveFriend,
                onMessage: onMessage,
                onMarkAsFavorite: onMarkAsFavorite,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ProfileMenuButton(
            onPressed: onOpenProfileOptions,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ProfileMenuButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? colorScheme.surface.withValues(alpha: 0.34)
          : const Color(0xFFF8F2EC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        splashColor: colorScheme.primary.withValues(alpha: 0.06),
        highlightColor: colorScheme.primary.withValues(alpha: 0.03),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withValues(alpha: 0.12)
                  : const Color(0xFFE6D9CB),
            ),
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.62),
            size: 21,
          ),
        ),
      ),
    );
  }
}
