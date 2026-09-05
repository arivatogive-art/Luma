// Pfad: lib/features/shell/presentation/main_shell_screen.dart

import 'package:flutter/material.dart';

import '../../messenger/presentation/messenger_screen.dart';
import '../../notifications/application/notification_controller.dart';
import '../../notifications/domain/notification_model.dart';
import '../../notifications/presentation/notification_post_target_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;
  late final LumaNotificationController _notificationController;
  final GlobalKey<NavigatorState> _notificationsNavigatorKey =
      GlobalKey<NavigatorState>();

  bool _isNotificationTargetOpen = false;

  static const List<_ShellDestination> _destinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Messenger',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    _ShellDestination(
      label: 'Benachrichtigungen',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
    ),
    _ShellDestination(
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _notificationController = LumaNotificationController()
      ..addListener(_handleNotificationChanged);

    _notificationController.initialize();

    _currentIndex = widget.initialIndex.clamp(
      0,
      _destinations.length - 1,
    );
  }

  @override
  void dispose() {
    _notificationController.removeListener(_handleNotificationChanged);
    _notificationController.dispose();
    super.dispose();
  }

  void _handleNotificationChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 1 && _isNotificationTargetOpen
          ? null
          : _buildAppBar(context),
      body: IndexedStack(
        index: _currentIndex,
        children: <Widget>[
          const MessengerScreen(),
          Navigator(
            key: _notificationsNavigatorKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => NotificationsScreen(
                  controller: _notificationController,
                  onNotificationTap: _openNotificationTarget,
                ),
              );
            },
          ),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectDestination,
        destinations: List<NavigationDestination>.generate(
          _destinations.length,
          (index) {
            final destination = _destinations[index];

            return NavigationDestination(
              icon: _buildDestinationIcon(
                context: context,
                index: index,
                icon: destination.icon,
                selected: false,
              ),
              selectedIcon: _buildDestinationIcon(
                context: context,
                index: index,
                icon: destination.selectedIcon,
                selected: true,
              ),
              label: destination.label,
            );
          },
          growable: false,
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 18,
      title: Text(
        'Luma',
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: colorScheme.onSurface,
        ),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'Suchen',
          onPressed: _openSearch,
          icon: const Icon(
            Icons.search_rounded,
            size: 25,
          ),
        ),
        const SizedBox(width: 2),
        TextButton(
          onPressed: _openMyLuma,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          child: Text(
            'Mein Luma',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDestinationIcon({
    required BuildContext context,
    required int index,
    required IconData icon,
    required bool selected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseIcon = Icon(
      icon,
      color: selected ? colorScheme.primary : null,
    );

    if (index != 1 || _notificationController.unreadCount <= 0) {
      return baseIcon;
    }

    final count = _notificationController.unreadCount;
    final label = count > 99 ? '99+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        baseIcon,
        Positioned(
          right: -13,
          top: -8,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.surface,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  void _selectDestination(int index) {
    if (index == _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openNotificationTarget(
    LumaNotificationModel notification,
  ) async {
    if (!_supportsPostTarget(notification.type)) {
      return;
    }

    final navigator = _notificationsNavigatorKey.currentState;
    if (navigator == null) return;

    if (mounted) {
      setState(() {
        _isNotificationTargetOpen = true;
      });
    }

    try {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => NotificationPostTargetScreen(
            notification: notification,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isNotificationTargetOpen = false;
        });
      }
    }
  }

  bool _supportsPostTarget(LumaNotificationType type) {
    switch (type) {
      case LumaNotificationType.postLike:
      case LumaNotificationType.postComment:
      case LumaNotificationType.commentReply:
      case LumaNotificationType.commentLike:
      case LumaNotificationType.postShare:
        return true;
      case LumaNotificationType.friendRequest:
      case LumaNotificationType.friendRequestAccepted:
      case LumaNotificationType.storyView:
      case LumaNotificationType.storyReaction:
      case LumaNotificationType.storyReply:
      case LumaNotificationType.mention:
      case LumaNotificationType.groupActivity:
      case LumaNotificationType.pageActivity:
      case LumaNotificationType.newFollower:
      case LumaNotificationType.relationshipRequest:
      case LumaNotificationType.relationshipAccepted:
      case LumaNotificationType.relationshipRejected:
      case LumaNotificationType.relationshipCancelled:
      case LumaNotificationType.relationshipRemoved:
      case LumaNotificationType.relationshipChanged:
      case LumaNotificationType.securityAlert:
      case LumaNotificationType.systemUpdate:
      case LumaNotificationType.unknown:
        return false;
    }
  }

  void _openSearch() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Die Suche wird als eigener Bereich angebunden.'),
        ),
      );
  }

  void _openMyLuma() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Mein Luma wird als Einstellungsbereich angebunden.'),
        ),
      );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
