// Pfad: lib/presentation/widgets/profile_friend_picker_dialog.dart

import 'package:flutter/material.dart';

import '../../domain/models/private_profile_model.dart';
import 'profile_sheet_action_button.dart';

class ProfileFriendPickerDialog extends StatelessWidget {
  final List<PrivateProfileModel> availableFriends;
  final List<PrivateProfileModel> selectedFriends;

  const ProfileFriendPickerDialog({
    super.key,
    required this.availableFriends,
    required this.selectedFriends,
  });

  static Future<List<PrivateProfileModel>?> show({
    required BuildContext context,
    required List<PrivateProfileModel> availableFriends,
    required List<PrivateProfileModel> selectedFriends,
  }) {
    return showDialog<List<PrivateProfileModel>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (_) {
        return ProfileFriendPickerDialog(
          availableFriends: availableFriends,
          selectedFriends: selectedFriends,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final initiallySelectedIds = selectedFriends
        .map((friend) => friend.userId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedIds = <String>{...initiallySelectedIds};

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 24,
      ),
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedFriendsResult = availableFriends.where((friend) {
            return selectedIds.contains(friend.userId.trim());
          }).toList(growable: false);

          return ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 540,
              maxHeight: 580,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.040),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.035),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(11, 9, 11, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Freunde markieren',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Wähle Freunde aus, die in diesem Profilmoment erwähnt werden sollen.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.64,
                              ),
                              fontSize: 14,
                              height: 1.42,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: availableFriends.isEmpty
                          ? const _ProfileMomentNoFriendsState()
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                              itemCount: availableFriends.length,
                              separatorBuilder: (context, index) {
                                return const SizedBox(height: 5);
                              },
                              itemBuilder: (context, index) {
                                final friend = availableFriends[index];
                                final friendId = friend.userId.trim();
                                final isSelected = selectedIds.contains(friendId);

                                return _ProfileMomentFriendPickerTile(
                                  friend: friend,
                                  isSelected: isSelected,
                                  onTap: () {
                                    if (friendId.isEmpty) return;

                                    setDialogState(() {
                                      if (isSelected) {
                                        selectedIds.remove(friendId);
                                      } else {
                                        selectedIds.add(friendId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                      child: Row(
                        children: [
                          Expanded(
                            child: ProfileSheetActionButton(
                              label: 'Abbrechen',
                              onPressed: () {
                                Navigator.of(context).pop(null);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(selectedFriendsResult);
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: colorScheme.onPrimary,
                                backgroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: Text(
                                selectedIds.isEmpty
                                    ? 'Ohne Markierung'
                                    : '${selectedIds.length} markieren',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileMomentFriendPickerTile extends StatelessWidget {
  final PrivateProfileModel friend;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileMomentFriendPickerTile({
    required this.friend,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = friend.displayName.trim().isEmpty
        ? 'Luma Freund'
        : friend.displayName.trim();
    final username = friend.username.trim().isEmpty
        ? ''
        : '@${friend.username.trim().replaceAll('@', '')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.10)
                : colorScheme.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : colorScheme.outline.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              _ProfileMomentFriendAvatar(friend: friend),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.05,
                      ),
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.54),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.38),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMomentFriendAvatar extends StatelessWidget {
  final PrivateProfileModel friend;

  const _ProfileMomentFriendAvatar({
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = friend.profileImageUrl.trim();

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _ProfileMomentFriendAvatarFallback(friend: friend);
                },
              )
            : _ProfileMomentFriendAvatarFallback(friend: friend),
      ),
    );
  }
}

class _ProfileMomentFriendAvatarFallback extends StatelessWidget {
  final PrivateProfileModel friend;

  const _ProfileMomentFriendAvatarFallback({
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = friend.displayName.trim();
    final label = displayName.isEmpty ? 'F' : displayName.substring(0, 1);

    return Center(
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileMomentNoFriendsState extends StatelessWidget {
  const _ProfileMomentNoFriendsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.040),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.people_outline_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                'Noch keine Freunde verfügbar. Sobald Freunde geladen sind, kannst du sie in Profilmomenten markieren.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.36,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
