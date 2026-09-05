// Pfad: lib/features/notifications/presentation/notifications_screen.dart

import 'package:flutter/material.dart';

import '../application/notification_controller.dart';
import '../domain/notification_model.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.controller,
  });

  final LumaNotificationController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: controller.reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Benachrichtigungen',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (controller.unreadCount > 0)
                        TextButton(
                          onPressed: controller.isMarkingAllAsRead
                              ? null
                              : controller.markAllAsRead,
                          child: controller.isMarkingAllAsRead
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Alle gelesen'),
                        ),
                    ],
                  ),
                ),
              ),
              if (controller.errorMessage != null &&
                  controller.state == LumaNotificationsLoadState.loaded)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _InlineErrorMessage(
                      text: controller.errorMessage!,
                    ),
                  ),
                ),
              _buildContent(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (controller.state) {
      case LumaNotificationsLoadState.initial:
      case LumaNotificationsLoadState.loading:
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

      case LumaNotificationsLoadState.error:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _NotificationMessage(
            icon: Icons.cloud_off_outlined,
            text: controller.errorMessage ??
                'Benachrichtigungen konnten nicht geladen werden.',
            actionLabel: 'Erneut versuchen',
            onAction: controller.reload,
          ),
        );

      case LumaNotificationsLoadState.loaded:
        if (controller.notifications.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: _NotificationMessage(
              icon: Icons.notifications_none_rounded,
              text: 'Noch keine Benachrichtigungen.',
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
          sliver: SliverList.separated(
            itemCount: controller.notifications.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notification = controller.notifications[index];

              return _NotificationTile(
                notification: notification,
                isProcessing:
                    controller.isMarkingAsRead(notification.id),
                onTap: notification.isUnread
                    ? () => controller.markAsRead(notification.id)
                    : null,
              );
            },
          ),
        );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isProcessing,
    required this.onTap,
  });

  final LumaNotificationModel notification;
  final bool isProcessing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actorAvatarUrl = notification.actorAvatarUrl?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: notification.isUnread
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.30)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  CircleAvatar(
                    radius: 23,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    foregroundImage: actorAvatarUrl.isNotEmpty
                        ? NetworkImage(actorAvatarUrl)
                        : null,
                    child: actorAvatarUrl.isEmpty
                        ? Icon(
                            _iconForType(notification.type),
                            size: 22,
                          )
                        : null,
                  ),
                  if (notification.isUnread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: notification.isUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                    if (notification.body.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (notification.previewText?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        notification.previewText!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _dateLabel(notification.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (isProcessing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForType(LumaNotificationType type) {
    switch (type) {
      case LumaNotificationType.postLike:
      case LumaNotificationType.commentLike:
        return Icons.thumb_up_alt_outlined;
      case LumaNotificationType.postComment:
      case LumaNotificationType.commentReply:
        return Icons.chat_bubble_outline_rounded;
      case LumaNotificationType.postShare:
        return Icons.share_outlined;
      case LumaNotificationType.friendRequest:
      case LumaNotificationType.friendRequestAccepted:
      case LumaNotificationType.newFollower:
        return Icons.person_add_alt_1_outlined;
      case LumaNotificationType.storyView:
      case LumaNotificationType.storyReaction:
      case LumaNotificationType.storyReply:
        return Icons.auto_stories_outlined;
      case LumaNotificationType.mention:
        return Icons.alternate_email_rounded;
      case LumaNotificationType.groupActivity:
        return Icons.groups_outlined;
      case LumaNotificationType.pageActivity:
        return Icons.flag_outlined;
      case LumaNotificationType.relationshipRequest:
      case LumaNotificationType.relationshipAccepted:
      case LumaNotificationType.relationshipRejected:
      case LumaNotificationType.relationshipCancelled:
      case LumaNotificationType.relationshipRemoved:
      case LumaNotificationType.relationshipChanged:
        return Icons.favorite_border_rounded;
      case LumaNotificationType.securityAlert:
        return Icons.shield_outlined;
      case LumaNotificationType.systemUpdate:
        return Icons.system_update_alt_rounded;
      case LumaNotificationType.unknown:
        return Icons.notifications_none_rounded;
    }
  }

  static String _dateLabel(DateTime value) {
    if (value.millisecondsSinceEpoch <= 0) return '';

    final local = value.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (!difference.isNegative) {
      if (difference.inMinutes < 1) return 'Gerade eben';
      if (difference.inMinutes < 60) {
        return 'Vor ${difference.inMinutes} Min.';
      }
      if (difference.inHours < 24) {
        return 'Vor ${difference.inHours} Std.';
      }
      if (difference.inDays < 7) {
        return 'Vor ${difference.inDays} T.';
      }
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }
}

class _InlineErrorMessage extends StatelessWidget {
  const _InlineErrorMessage({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 34,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => onAction!(),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
