// Pfad: lib/features/notifications/data/notification_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/notification_model.dart';

class LumaNotificationRepository {
  LumaNotificationRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<LumaNotificationModel>> watchNotifications({
    required String userId,
    int limit = 100,
  }) {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return Stream<List<LumaNotificationModel>>.value(
        const <LumaNotificationModel>[],
      );
    }

    final safeLimit = limit.clamp(1, 200).toInt();

    return _firestore
        .collection('users')
        .doc(cleanedUserId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map((snapshot) {
      final notifications = <LumaNotificationModel>[];

      for (final document in snapshot.docs) {
        final notification = LumaNotificationModel.fromFirestore(
          id: document.id,
          data: document.data(),
        );

        if (notification.id.trim().isEmpty) continue;
        if (notification.userId.trim().isEmpty) continue;
        if (notification.userId.trim() != cleanedUserId) continue;

        notifications.add(notification);
      }

      notifications.sort(
        (first, second) => second.createdAt.compareTo(first.createdAt),
      );

      return List<LumaNotificationModel>.unmodifiable(notifications);
    });
  }
}
