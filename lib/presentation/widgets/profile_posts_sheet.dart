// Pfad: lib/presentation/widgets/profile_posts_sheet.dart

import 'package:flutter/material.dart';

import 'profile_moment_sheet_card.dart';
import 'profile_posts_preview_card.dart' as profile_posts;
import 'profile_sheet_action_button.dart';
import 'profile_sheet_handle.dart';
import 'profile_utils.dart';

class ProfilePostsSheet {
  const ProfilePostsSheet._();

  static void show({
    required BuildContext context,
    required List<profile_posts.ProfileMomentPreviewData> profileMoments,
    required bool isViewingOwnProfile,
    required bool isLoadingMoments,
    required String? momentError,
    required Widget Function() buildMomentsLoadingSheetState,
    required Widget Function() buildMomentsErrorSheetState,
    required Widget Function() buildEmptyMomentsSheetState,
    required VoidCallback onCreateMoment,
    required void Function(profile_posts.ProfileMomentPreviewData moment)
        onEditMoment,
    required Future<void> Function(profile_posts.ProfileMomentPreviewData moment)
        onDeleteMoment,
    required void Function(profile_posts.ProfileMomentPreviewData moment)
        onLikeSummaryTap,
    required void Function(String friendUserId) onTaggedFriendTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasMoments = profileMoments.isNotEmpty;

            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ProfileSheetHandle(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Alle Profilmomente',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isViewingOwnProfile)
                            ProfileSmallSheetIconButton(
                              icon: Icons.add_rounded,
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                onCreateMoment();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hasMoments
                            ? 'Deine Profilmomente werden geladen und bleiben vom Feed getrennt.'
                            : isViewingOwnProfile
                                ? 'Noch keine Profilmomente vorhanden.'
                                : 'Dieses Profil hat aktuell keine sichtbaren Momente.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.68),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      if (isLoadingMoments) ...[
                        const SizedBox(height: 5),
                        buildMomentsLoadingSheetState(),
                      ] else if (momentError != null) ...[
                        const SizedBox(height: 5),
                        buildMomentsErrorSheetState(),
                      ] else ...[
                        const SizedBox(height: 5),
                        if (hasMoments)
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: profileMoments.length,
                              separatorBuilder: (context, index) {
                                return const SizedBox(height: 5);
                              },
                              itemBuilder: (context, index) {
                                final moment = profileMoments[index];
                                final isNewestMoment = index == 0;
                                final isFreshMoment = DateTime.now()
                                        .difference(moment.createdAt)
                                        .inHours <
                                    24;
                                final animationDelay =
                                    index * 30 > 150 ? 150 : index * 30;

                                return TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: Duration(
                                    milliseconds: 220 + animationDelay,
                                  ),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 10 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: ProfileMomentSheetCard(
                                    moment: moment,
                                    canManage: isViewingOwnProfile,
                                    formattedDate:
                                        ProfileUtils.formatProfileMomentDate(
                                      moment.createdAt,
                                    ),
                                    isHighlighted: isNewestMoment,
                                    isFresh: isFreshMoment,
                                    onEdit: () {
                                      Navigator.of(sheetContext).pop();
                                      onEditMoment(moment);
                                    },
                                    onDelete: () async {
                                      await onDeleteMoment(moment);
                                      setSheetState(() {});
                                    },
                                    onLikeSummaryTap: () {
                                      Navigator.of(sheetContext).pop();
                                      onLikeSummaryTap(moment);
                                    },
                                    onTaggedFriendTap: (friendUserId) {
                                      Navigator.of(sheetContext).pop();
                                      onTaggedFriendTap(friendUserId);
                                    },
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          buildEmptyMomentsSheetState(),
                      ],
                      const SizedBox(height: 5),
                      ProfileSheetActionButton(
                        label: 'Schließen',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
