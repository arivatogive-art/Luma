// Pfad: lib/features/security/data/security_device_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/security_device_model.dart';

class SecurityDeviceRepository {
  SecurityDeviceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';
  static const String _devicesCollection = 'devices';

  Future<List<SecurityDeviceModel>> loadDevices({
    required String userId,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) {
      return const <SecurityDeviceModel>[];
    }

    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(cleanedUserId)
        .collection(_devicesCollection)
        .get();

    final devices = snapshot.docs
        .map(SecurityDeviceModel.fromFirestore)
        .where((device) => device.isKnown)
        .toList(growable: false);

    final sorted = List<SecurityDeviceModel>.from(devices)
      ..sort((a, b) {
        final aDate = a.lastSeenAt ??
            a.lastLoginAt ??
            a.updatedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.lastSeenAt ??
            b.lastLoginAt ??
            b.updatedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return List<SecurityDeviceModel>.unmodifiable(sorted);
  }
}
