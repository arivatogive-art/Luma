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

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    final cleanedUserId = userId.trim();
    final cleanedNotificationId = notificationId.trim();

    if (cleanedUserId.isEmpty || cleanedNotificationId.isEmpty) {
      throw ArgumentError('userId und notificationId dürfen nicht leer sein.');
    }

    final reference = _firestore
        .collection('users')
        .doc(cleanedUserId)
        .collection('notifications')
        .doc(cleanedNotificationId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      return;
    }

    final data = snapshot.data();
    if (data == null) {
      return;
    }

    if ((data['userId'] as String?)?.trim() != cleanedUserId) {
      throw StateError('Die Benachrichtigung gehört nicht zum aktiven Nutzer.');
    }

    if (data['isRead'] == true) {
      return;
    }

    await reference.update(<String, dynamic>{
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead({
    required String userId,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError('userId darf nicht leer sein.');
    }

    final collection = _firestore
        .collection('users')
        .doc(cleanedUserId)
        .collection('notifications');

    final snapshot = await collection
        .where('isRead', isEqualTo: false)
        .limit(400)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final document in snapshot.docs) {
      final data = document.data();

      if ((data['userId'] as String?)?.trim() != cleanedUserId) {
        continue;
      }

      batch.update(document.reference, <String, dynamic>{
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
