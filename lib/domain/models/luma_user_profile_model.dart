// Pfad: lib/domain/models/luma_user_profile_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ProfileFieldVisibility {
  onlyMe,
  friends,
  public,
}

@immutable
class LumaUserProfileModel {
  final String id;
  final String displayName;
  final String username;
  final String? email;
  final String? phoneNumber;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final bool isPrivate;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOnline;
  final DateTime? lastSeenAt;

  final String? location;
  final String? work;
  final String? education;
  final String? website;

  final String? nickname;
  final String? relationshipStatusText;
  final String? familyInfo;
  final DateTime? birthday;
  final ProfileFieldVisibility birthdayVisibility;
  final ProfileFieldVisibility birthYearVisibility;
  final ProfileFieldVisibility friendsVisibility;

  final String? instagramUrl;
  final String? youtubeUrl;
  final String? spotifyUrl;
  final String? tiktokUrl;
  final String? facebookUrl;
  final String? whatsappUrl;
  final String? twitterUrl;

  const LumaUserProfileModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.phoneNumber,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.isPrivate = false,
    this.isVerified = false,
    this.isOnline = false,
    this.lastSeenAt,
    this.location,
    this.work,
    this.education,
    this.website,
    this.nickname,
    this.relationshipStatusText,
    this.familyInfo,
    this.birthday,
    this.birthdayVisibility = ProfileFieldVisibility.friends,
    this.birthYearVisibility = ProfileFieldVisibility.onlyMe,
    this.friendsVisibility = ProfileFieldVisibility.friends,
    this.instagramUrl,
    this.youtubeUrl,
    this.spotifyUrl,
    this.tiktokUrl,
    this.facebookUrl,
    this.whatsappUrl,
    this.twitterUrl,
  });

  bool get hasBio => bio != null && bio!.trim().isNotEmpty;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;
  bool get hasCover => coverUrl != null && coverUrl!.trim().isNotEmpty;
  bool get hasEmail => email != null && email!.trim().isNotEmpty;

  bool get hasPhoneNumber {
    return phoneNumber != null && phoneNumber!.trim().isNotEmpty;
  }

  bool get hasLocation => location != null && location!.trim().isNotEmpty;

  bool get hasWork => work != null && work!.trim().isNotEmpty;

  bool get hasEducation {
    return education != null && education!.trim().isNotEmpty;
  }

  bool get hasWebsite => website != null && website!.trim().isNotEmpty;

  bool get hasNickname => nickname != null && nickname!.trim().isNotEmpty;

  bool get hasRelationshipStatusText {
    return relationshipStatusText != null &&
        relationshipStatusText!.trim().isNotEmpty;
  }

  bool get hasFamilyInfo {
    return familyInfo != null && familyInfo!.trim().isNotEmpty;
  }

  bool get hasBirthday => birthday != null;

  bool get hasInstagram {
    return instagramUrl != null && instagramUrl!.trim().isNotEmpty;
  }

  bool get hasYoutube {
    return youtubeUrl != null && youtubeUrl!.trim().isNotEmpty;
  }

  bool get hasSpotify {
    return spotifyUrl != null && spotifyUrl!.trim().isNotEmpty;
  }

  bool get hasTikTok {
    return tiktokUrl != null && tiktokUrl!.trim().isNotEmpty;
  }

  bool get hasFacebook {
    return facebookUrl != null && facebookUrl!.trim().isNotEmpty;
  }

  bool get hasWhatsApp {
    return whatsappUrl != null && whatsappUrl!.trim().isNotEmpty;
  }

  bool get hasTwitter {
    return twitterUrl != null && twitterUrl!.trim().isNotEmpty;
  }

  String get displayNameLowercase => _normalizeSearchText(displayName);
  String get usernameLowercase => _normalizeSearchText(username);
  String get emailLowercase => _normalizeSearchText(email ?? '');
  String get phoneNumberSearch => _normalizePhoneNumber(phoneNumber ?? '');

  List<String> get searchKeywords {
    return buildSearchKeywords(
      displayName: displayName,
      username: username,
      email: email,
      phoneNumber: phoneNumber,
    );
  }

  LumaUserProfileModel copyWith({
    String? id,
    String? displayName,
    String? username,
    String? email,
    String? phoneNumber,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    bool? isPrivate,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
    DateTime? lastSeenAt,
    String? location,
    String? work,
    String? education,
    String? website,
    String? nickname,
    String? relationshipStatusText,
    String? familyInfo,
    DateTime? birthday,
    ProfileFieldVisibility? birthdayVisibility,
    ProfileFieldVisibility? birthYearVisibility,
    ProfileFieldVisibility? friendsVisibility,
    String? instagramUrl,
    String? youtubeUrl,
    String? spotifyUrl,
    String? tiktokUrl,
    String? facebookUrl,
    String? whatsappUrl,
    String? twitterUrl,
    bool clearEmail = false,
    bool clearPhoneNumber = false,
    bool clearBio = false,
    bool clearAvatarUrl = false,
    bool clearCoverUrl = false,
    bool clearNickname = false,
    bool clearRelationshipStatusText = false,
    bool clearFamilyInfo = false,
    bool clearBirthday = false,
    bool clearLastSeenAt = false,
    bool clearLocation = false,
    bool clearWork = false,
    bool clearEducation = false,
    bool clearWebsite = false,
    bool clearInstagramUrl = false,
    bool clearYoutubeUrl = false,
    bool clearSpotifyUrl = false,
    bool clearTiktokUrl = false,
    bool clearFacebookUrl = false,
    bool clearWhatsappUrl = false,
    bool clearTwitterUrl = false,
  }) {
    return LumaUserProfileModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: clearEmail ? null : email ?? this.email,
      phoneNumber: clearPhoneNumber ? null : phoneNumber ?? this.phoneNumber,
      bio: clearBio ? null : bio ?? this.bio,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      coverUrl: clearCoverUrl ? null : coverUrl ?? this.coverUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: clearLastSeenAt ? null : lastSeenAt ?? this.lastSeenAt,
      location: clearLocation ? null : location ?? this.location,
      work: clearWork ? null : work ?? this.work,
      education: clearEducation ? null : education ?? this.education,
      website: clearWebsite ? null : website ?? this.website,
      nickname: clearNickname ? null : nickname ?? this.nickname,
      relationshipStatusText: clearRelationshipStatusText
          ? null
          : relationshipStatusText ?? this.relationshipStatusText,
      familyInfo: clearFamilyInfo ? null : familyInfo ?? this.familyInfo,
      birthday: clearBirthday ? null : birthday ?? this.birthday,
      birthdayVisibility: birthdayVisibility ?? this.birthdayVisibility,
      birthYearVisibility: birthYearVisibility ?? this.birthYearVisibility,
      friendsVisibility: friendsVisibility ?? this.friendsVisibility,
      instagramUrl:
          clearInstagramUrl ? null : instagramUrl ?? this.instagramUrl,
      youtubeUrl: clearYoutubeUrl ? null : youtubeUrl ?? this.youtubeUrl,
      spotifyUrl: clearSpotifyUrl ? null : spotifyUrl ?? this.spotifyUrl,
      tiktokUrl: clearTiktokUrl ? null : tiktokUrl ?? this.tiktokUrl,
      facebookUrl: clearFacebookUrl ? null : facebookUrl ?? this.facebookUrl,
      whatsappUrl: clearWhatsappUrl ? null : whatsappUrl ?? this.whatsappUrl,
      twitterUrl: clearTwitterUrl ? null : twitterUrl ?? this.twitterUrl,
    );
  }

  factory LumaUserProfileModel.empty({
    required String id,
    String? fallbackName,
    String? email,
    String? phoneNumber,
  }) {
    final now = DateTime.now();

    final normalizedFallbackName = fallbackName?.trim();
    final safeDisplayName =
        normalizedFallbackName == null || normalizedFallbackName.isEmpty
            ? 'Luma Nutzer'
            : normalizedFallbackName;

    return LumaUserProfileModel(
      id: id.trim(),
      displayName: safeDisplayName,
      username: _usernameFromDisplayName(safeDisplayName),
      email: _readNullableString(email),
      phoneNumber: _readNullableString(phoneNumber),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory LumaUserProfileModel.fromMap(Map<String, dynamic> map) {
    return LumaUserProfileModel(
      id: _readString(map['id']),
      displayName: _readString(map['displayName'], fallback: 'Luma Nutzer'),
      username: _readString(map['username'], fallback: 'luma_user'),
      email: _readNullableString(map['email']),
      phoneNumber: _readNullableString(map['phoneNumber']),
      bio: _readNullableString(map['bio']),
      avatarUrl: _readNullableString(map['avatarUrl']),
      coverUrl: _readNullableString(map['coverUrl']),
      isPrivate: _readBool(map['isPrivate']),
      isVerified: _readBool(map['isVerified']),
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
      isOnline: _readBool(map['isOnline']),
      lastSeenAt: _readNullableDateTime(map['lastSeenAt']),
      location: _readNullableString(map['location']),
      work: _readNullableString(map['work']),
      education: _readNullableString(map['education']),
      website: _readNullableString(map['website']),
      nickname: _readNullableString(map['nickname']),
      relationshipStatusText:
          _readNullableString(map['relationshipStatusText']),
      familyInfo: _readNullableString(map['familyInfo']),
      birthday: _readNullableDateTime(map['birthday']),
      birthdayVisibility: _readProfileFieldVisibility(
        map['birthdayVisibility'],
        fallback: ProfileFieldVisibility.friends,
      ),
      birthYearVisibility: _readProfileFieldVisibility(
        map['birthYearVisibility'],
        fallback: ProfileFieldVisibility.onlyMe,
      ),
      friendsVisibility: _readProfileFieldVisibility(
        map['friendsVisibility'],
        fallback: ProfileFieldVisibility.friends,
      ),
      instagramUrl: _readNullableString(map['instagramUrl']),
      youtubeUrl: _readNullableString(map['youtubeUrl']),
      spotifyUrl: _readNullableString(map['spotifyUrl']),
      tiktokUrl: _readNullableString(map['tiktokUrl']),
      facebookUrl: _readNullableString(map['facebookUrl']),
      whatsappUrl: _readNullableString(map['whatsappUrl']),
      twitterUrl: _readNullableString(map['twitterUrl']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayNameLowercase': displayNameLowercase,
      'usernameLowercase': usernameLowercase,
      'emailLowercase': emailLowercase,
      'phoneNumberSearch': phoneNumberSearch,
      'searchKeywords': searchKeywords,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'isPrivate': isPrivate,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt == null ? null : Timestamp.fromDate(lastSeenAt!),
      'location': location,
      'work': work,
      'education': education,
      'website': website,
      'nickname': nickname,
      'relationshipStatusText': relationshipStatusText,
      'familyInfo': familyInfo,
      'birthday': birthday == null ? null : Timestamp.fromDate(birthday!),
      'birthdayVisibility': birthdayVisibility.name,
      'birthYearVisibility': birthYearVisibility.name,
      'friendsVisibility': friendsVisibility.name,
      'instagramUrl': instagramUrl,
      'youtubeUrl': youtubeUrl,
      'spotifyUrl': spotifyUrl,
      'tiktokUrl': tiktokUrl,
      'facebookUrl': facebookUrl,
      'whatsappUrl': whatsappUrl,
      'twitterUrl': twitterUrl,
    };
  }

  static List<String> buildSearchKeywords({
    required String displayName,
    required String username,
    String? email,
    String? phoneNumber,
  }) {
    final values = <String>{
      _normalizeSearchText(displayName),
      _normalizeSearchText(username),
      _normalizeSearchText(username).replaceAll('@', ''),
    };

    final normalizedEmail = _normalizeSearchText(email ?? '');
    if (normalizedEmail.isNotEmpty) {
      values.add(normalizedEmail);
      values.add(normalizedEmail.split('@').first);
    }

    final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber ?? '');
    if (normalizedPhoneNumber.isNotEmpty) {
      values.add(normalizedPhoneNumber);
    }

    final keywords = <String>{};

    for (final value in values) {
      if (value.isEmpty) continue;

      final compact = value.replaceAll(RegExp(r'\s+'), '');

      _addPrefixes(keywords, value);
      _addPrefixes(keywords, compact);

      final parts = value.split(RegExp(r'[\s@._-]+'));
      for (final part in parts) {
        _addPrefixes(keywords, part);
      }
    }

    keywords.removeWhere((keyword) => keyword.trim().isEmpty);

    return keywords.toList()..sort();
  }

  static void _addPrefixes(Set<String> target, String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;

    final maxLength = cleaned.length.clamp(1, 40);

    for (var i = 1; i <= maxLength; i++) {
      target.add(cleaned.substring(0, i));
    }
  }

  static String _usernameFromDisplayName(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (cleaned.isEmpty) return 'luma_user';

    return cleaned;
  }

  static String _normalizeSearchText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizePhoneNumber(String value) {
    return value.trim().replaceAll(RegExp(r'[\s().-]+'), '');
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static String? _readNullableString(dynamic value) {
    if (value is! String) return null;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    return trimmed;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    return false;
  }

  static DateTime _readDateTime(dynamic value) {
    return _readNullableDateTime(value) ?? DateTime.now();
  }

  static DateTime? _readNullableDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is Timestamp) return value.toDate();

    if (value is String) {
      return DateTime.tryParse(value);
    }

    final dynamic seconds = value.seconds;
    final dynamic nanoseconds = value.nanoseconds;

    if (seconds is int) {
      final milliseconds = seconds * 1000;
      final extraMilliseconds =
          nanoseconds is int ? nanoseconds ~/ 1000000 : 0;

      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds + extraMilliseconds,
      );
    }

    return null;
  }

  static ProfileFieldVisibility _readProfileFieldVisibility(
    dynamic value, {
    required ProfileFieldVisibility fallback,
  }) {
    if (value is! String) return fallback;

    final cleanedValue = value.trim();

    for (final visibility in ProfileFieldVisibility.values) {
      if (visibility.name == cleanedValue) {
        return visibility;
      }
    }

    return fallback;
  }
}
