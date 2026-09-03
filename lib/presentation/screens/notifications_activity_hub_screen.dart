// Pfad: lib/features/notifications/presentation/screens/notifications_activity_hub_screen.dart

import 'package:flutter/material.dart';

import '../../application/notification_controller.dart';
import 'notifications_screen.dart';

class LumaNotificationsActivityHubScreen extends StatelessWidget {
  const LumaNotificationsActivityHubScreen({
    super.key,
    this.notificationController,
  });

  final LumaNotificationController? notificationController;

  @override
  Widget build(BuildContext context) {
    return LumaNotificationsScreen(
      notificationController: notificationController,
    );
  }
}
