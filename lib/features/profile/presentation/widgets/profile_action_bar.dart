// Pfad: lib/features/profile/presentation/widgets/profile_action_bar.dart

import 'package:flutter/material.dart';

import '../../domain/profile_friendship_model.dart';

class ProfileActionBar extends StatelessWidget {
  const ProfileActionBar({
    super.key,
    required this.isOwnProfile,
    required this.friendshipStatus,
    required this.isFriendshipLoading,
    required this.onEditProfile,
    required this.onFriendshipAction,
    required this.onMessage,
    required this.onOpenOptions,
  });

  final bool isOwnProfile;
  final ProfileFriendshipStatus friendshipStatus;
  final bool isFriendshipLoading;
  final VoidCallback onEditProfile;
  final VoidCallback onFriendshipAction;
  final VoidCallback onMessage;
  final VoidCallback onOpenOptions;

  @override
  Widget build(BuildContext context) {
    if (isOwnProfile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Profil bearbeiten'),
              ),
            ),
            const SizedBox(width: 10),
            _OptionsButton(
              onPressed: onOpenOptions,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  isFriendshipLoading ? null : onFriendshipAction,
              icon: isFriendshipLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(_friendshipIcon(friendshipStatus)),
              label: Text(_friendshipLabel(friendshipStatus)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Nachricht'),
            ),
          ),
          const SizedBox(width: 10),
          _OptionsButton(
            onPressed: onOpenOptions,
          ),
        ],
      ),
    );
  }

  static String _friendshipLabel(
    ProfileFriendshipStatus status,
  ) {
    switch (status) {
      case ProfileFriendshipStatus.self:
        return 'Profil';
      case ProfileFriendshipStatus.notFriends:
        return 'Freund hinzufügen';
      case ProfileFriendshipStatus.requestSent:
        return 'Anfrage gesendet';
      case ProfileFriendshipStatus.requestReceived:
        return 'Anfrage ansehen';
      case ProfileFriendshipStatus.friends:
        return 'Freunde';
      case ProfileFriendshipStatus.blocked:
        return 'Nicht verfügbar';
    }
  }

  static IconData _friendshipIcon(
    ProfileFriendshipStatus status,
  ) {
    switch (status) {
      case ProfileFriendshipStatus.self:
        return Icons.person_outline_rounded;
      case ProfileFriendshipStatus.notFriends:
        return Icons.person_add_alt_1_outlined;
      case ProfileFriendshipStatus.requestSent:
        return Icons.schedule_rounded;
      case ProfileFriendshipStatus.requestReceived:
        return Icons.mark_email_unread_outlined;
      case ProfileFriendshipStatus.friends:
        return Icons.people_alt_outlined;
      case ProfileFriendshipStatus.blocked:
        return Icons.block_outlined;
    }
  }
}

class _OptionsButton extends StatelessWidget {
  const _OptionsButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
        ),
        child: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}
