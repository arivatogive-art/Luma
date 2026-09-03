// Pfad: lib/features/shell/presentation/main_shell_screen.dart

import 'package:flutter/material.dart';

import '../../../features/notifications/application/notification_controller.dart';
import '../../../features/notifications/presentation/screens/notifications_activity_hub_screen.dart';
import '../../../presentation/screens/feed_screen.dart';
import '../../../presentation/screens/messenger_preview_screen.dart';
import '../../../presentation/screens/profile_screen.dart';

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
  static const Color _orange = Color(0xFFE58A2B);

  late int _currentIndex;
  late final LumaNotificationController _notificationController;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex.clamp(0, 3).toInt();

    _notificationController = LumaNotificationController();
    _notificationController.initialize();

    _pages = [
      const FeedScreen(),
      const MessengerPreviewScreen(),
      LumaNotificationsActivityHubScreen(
        notificationController: _notificationController,
      ),
      const ProfileScreen(isOwnProfile: true),
    ];
  }

  @override
  void dispose() {
    _notificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (_currentIndex == index) return;
          setState(() {
            _currentIndex = index;
          });
        },
        indicatorColor: _orange.withValues(alpha: 0.14),
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: _orange),
            label: 'Start',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: _orange),
            label: 'Messenger',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded, color: _orange),
            label: 'Mitteilungen',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: _orange),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
