// Pfad: lib/features/profile/domain/profile_model.dart

import 'package:flutter/foundation.dart';

@immutable
class ProfileModel {
  const ProfileModel({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.profileImageUrl,
    required this.coverImageUrl,
    required this.isVerified,
    required this.location,
    required this.work,
    required this.education,
    required this.website,
  });

  final String uid;
  final String displayName;
  final String username;
  final String bio;
  final String profileImageUrl;
  final String coverImageUrl;
  final bool isVerified;

  final String location;
  final String work;
  final String education;
  final String website;

  bool get hasProfileImage => profileImageUrl.trim().isNotEmpty;
  bool get hasCoverImage => coverImageUrl.trim().isNotEmpty;
  bool get hasBio => bio.trim().isNotEmpty;

  bool get hasLocation => location.trim().isNotEmpty;
  bool get hasWork => work.trim().isNotEmpty;
  bool get hasEducation => education.trim().isNotEmpty;
  bool get hasWebsite => website.trim().isNotEmpty;

  bool get hasAboutInformation =>
      hasLocation || hasWork || hasEducation || hasWebsite;

  factory ProfileModel.fromFirestore({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return ProfileModel(
      uid: uid.trim(),
      displayName: _readString(
        data['displayName'],
        fallback: 'Luma Nutzer',
      ),
      username: _readString(data['username']),
      bio: _readString(data['bio']),
      profileImageUrl: _readFirstString(
        data,
        const <String>[
          'avatarUrl',
          'profileImageUrl',
          'photoUrl',
          'photoURL',
        ],
      ),
      coverImageUrl: _readFirstString(
        data,
        const <String>[
          'coverUrl',
          'coverImageUrl',
        ],
      ),
      isVerified: _readBool(data['isVerified']),
      location: _readString(data['location']),
      work: _readString(data['work']),
      education: _readString(data['education']),
      website: _readString(data['website']),
    );
  }

  static String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String) {
      final cleaned = value.trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return fallback;
  }

  static String _readFirstString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _readString(data[key]);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  static bool _readBool(dynamic value) {
    return value is bool ? value : false;
  }
}
