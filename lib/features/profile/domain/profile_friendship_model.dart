// Pfad: lib/features/profile/domain/profile_friendship_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ProfileFriendshipStatus {
  self,
  notFriends,
  requestSent,
  requestReceived,
  friends,
  blocked,
}

@immutable
class ProfileFriendshipModel {
  const ProfileFriendshipModel({
    required this.status,
    required this.friendshipId,
    required this.requesterUserId,
    required this.addresseeUserId,
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
  });

  const ProfileFriendshipModel.self()
      : status = ProfileFriendshipStatus.self,
        friendshipId = '',
        requesterUserId = '',
        addresseeUserId = '',
        participants = const <String>[],
        createdAt = null,
        updatedAt = null;

  const ProfileFriendshipModel.notFriends()
      : status = ProfileFriendshipStatus.notFriends,
        friendshipId = '',
        requesterUserId = '',
        addresseeUserId = '',
        participants = const <String>[],
        createdAt = null,
        updatedAt = null;

  final ProfileFriendshipStatus status;
  final String friendshipId;
  final String requesterUserId;
  final String addresseeUserId;
  final List<String> participants;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasFriendshipDocument => friendshipId.trim().isNotEmpty;
  bool get isSelf => status == ProfileFriendshipStatus.self;
  bool get isFriend => status == ProfileFriendshipStatus.friends;
  bool get hasPendingRequest =>
      status == ProfileFriendshipStatus.requestSent ||
      status == ProfileFriendshipStatus.requestReceived;

  factory ProfileFriendshipModel.fromFirestore({
    required String friendshipId,
    required Map<String, dynamic> data,
    required String currentUserId,
    required String viewedUserId,
  }) {
    final requesterUserId = _readString(data['requesterUserId']);
    final addresseeUserId = _readString(data['addresseeUserId']);
    final participants = _readStringList(data['participants']);
    final rawStatus = _readString(data['status']).toLowerCase();

    final status = _resolveStatus(
      rawStatus: rawStatus,
      currentUserId: currentUserId,
      viewedUserId: viewedUserId,
      requesterUserId: requesterUserId,
      addresseeUserId: addresseeUserId,
    );

    return ProfileFriendshipModel(
      status: status,
      friendshipId: friendshipId.trim(),
      requesterUserId: requesterUserId,
      addresseeUserId: addresseeUserId,
      participants: List<String>.unmodifiable(participants),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  static ProfileFriendshipStatus _resolveStatus({
    required String rawStatus,
    required String currentUserId,
    required String viewedUserId,
    required String requesterUserId,
    required String addresseeUserId,
  }) {
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedViewedUserId = viewedUserId.trim();

    if (cleanedCurrentUserId.isNotEmpty &&
        cleanedCurrentUserId == cleanedViewedUserId) {
      return ProfileFriendshipStatus.self;
    }

    switch (rawStatus) {
      case 'accepted':
        return ProfileFriendshipStatus.friends;

      case 'blocked':
        return ProfileFriendshipStatus.blocked;

      case 'pending':
        if (requesterUserId == cleanedCurrentUserId &&
            addresseeUserId == cleanedViewedUserId) {
          return ProfileFriendshipStatus.requestSent;
        }

        if (requesterUserId == cleanedViewedUserId &&
            addresseeUserId == cleanedCurrentUserId) {
          return ProfileFriendshipStatus.requestReceived;
        }

        return ProfileFriendshipStatus.notFriends;

      case 'declined':
      default:
        return ProfileFriendshipStatus.notFriends;
    }
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
