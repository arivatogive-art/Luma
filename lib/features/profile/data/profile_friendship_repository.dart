// Pfad: lib/features/profile/data/profile_friendship_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_friendship_model.dart';

class ProfileFriendshipRepository {
  ProfileFriendshipRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _friendships {
    return _firestore.collection('friendships');
  }

  Future<ProfileFriendshipModel> fetchRelationship({
    required String currentUserId,
    required String viewedUserId,
  }) async {
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedViewedUserId = viewedUserId.trim();

    if (cleanedCurrentUserId.isEmpty || cleanedViewedUserId.isEmpty) {
      return const ProfileFriendshipModel.notFriends();
    }

    if (cleanedCurrentUserId == cleanedViewedUserId) {
      return const ProfileFriendshipModel.self();
    }

    final snapshot = await _friendships
        .where(
          'participants',
          arrayContains: cleanedCurrentUserId,
        )
        .get();

    final matches = snapshot.docs.where((document) {
      final data = document.data();
      final participants = _readStringList(data['participants']);

      if (participants.contains(cleanedCurrentUserId) &&
          participants.contains(cleanedViewedUserId)) {
        return true;
      }

      final requesterUserId = _readString(data['requesterUserId']);
      final addresseeUserId = _readString(data['addresseeUserId']);

      return (requesterUserId == cleanedCurrentUserId &&
              addresseeUserId == cleanedViewedUserId) ||
          (requesterUserId == cleanedViewedUserId &&
              addresseeUserId == cleanedCurrentUserId);
    }).toList(growable: false);

    if (matches.isEmpty) {
      return const ProfileFriendshipModel.notFriends();
    }

    matches.sort((a, b) {
      final aUpdatedAt = _readDateTime(a.data()['updatedAt']);
      final bUpdatedAt = _readDateTime(b.data()['updatedAt']);

      if (aUpdatedAt == null && bUpdatedAt == null) {
        return a.id.compareTo(b.id);
      }

      if (aUpdatedAt == null) {
        return 1;
      }

      if (bUpdatedAt == null) {
        return -1;
      }

      final dateCompare = bUpdatedAt.compareTo(aUpdatedAt);

      if (dateCompare != 0) {
        return dateCompare;
      }

      return a.id.compareTo(b.id);
    });

    final document = matches.first;

    return ProfileFriendshipModel.fromFirestore(
      friendshipId: document.id,
      data: document.data(),
      currentUserId: cleanedCurrentUserId,
      viewedUserId: cleanedViewedUserId,
    );
  }

  Future<List<String>> fetchAcceptedFriendUserIds({
    required String userId,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return const <String>[];
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(cleanedUserId)
        .collection('friends')
        .get();

    final friendIds = <String>{};

    for (final document in snapshot.docs) {
      final data = document.data();
      final status = _readString(data['status']).toLowerCase();

      if (status != 'accepted') {
        continue;
      }

      final friendUserId = _readString(data['friendUserId']);

      if (friendUserId.isNotEmpty && friendUserId != cleanedUserId) {
        friendIds.add(friendUserId);
      }
    }

    final sorted = friendIds.toList(growable: false)..sort();

    return List<String>.unmodifiable(sorted);
  }

  static String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }

    return '';
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    final result = <String>[];

    for (final item in value) {
      if (item is! String) {
        continue;
      }

      final cleaned = item.trim();

      if (cleaned.isEmpty || result.contains(cleaned)) {
        continue;
      }

      result.add(cleaned);
    }

    return result;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
