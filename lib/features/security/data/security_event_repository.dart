// Pfad: lib/features/security/data/security_event_repository.dart
//
// Luma Core Rebuild 2.0 - Sicherheit & Anmeldung, Phase C1.
// Ausschließlich lesender Zugriff auf bestehende Security Events.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/security_event_model.dart';

class SecurityEventRepository {
  SecurityEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _usersCollection = 'users';
  static const String _eventsCollection = 'security_events';

  final FirebaseFirestore _firestore;

  Future<List<SecurityEventModel>> loadRecentEvents({
    required String userId,
    int limit = 30,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return const <SecurityEventModel>[];
    }

    final safeLimit = limit.clamp(1, 100);

    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(cleanedUserId)
        .collection(_eventsCollection)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return snapshot.docs
        .map(SecurityEventModel.fromFirestore)
        .where((event) => event.id.trim().isNotEmpty)
        .toList(growable: false);
  }
}
