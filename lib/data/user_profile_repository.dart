// Pfad: lib/data/user_profile_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/luma_user_profile_model.dart';

class UserProfileRepository {
  static const String _usersCollection = 'users';

  final FirebaseFirestore _firestore;

  static const Duration _profileCacheTtl = Duration(minutes: 10);
  static const int _whereInChunkSize = 10;

  final Map<String, _CachedUserProfile> _profileCache =
      <String, _CachedUserProfile>{};

  UserProfileRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef {
    return _firestore.collection(_usersCollection);
  }

  Future<LumaUserProfileModel?> fetchProfile({
    required String userId,
    bool forceRefresh = false,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return null;
    }

    if (!forceRefresh) {
      final cached = _profileCache[cleanedUserId];

      if (cached != null && !cached.isExpired(_profileCacheTtl)) {
        return cached.profile;
      }
    }

    final documentReference = _usersRef.doc(cleanedUserId);

    try {
      final document = await documentReference.get();

      if (!document.exists) {
        _profileCache.remove(cleanedUserId);
        return null;
      }

      // Ein direkter DocumentReference.get()-Aufruf darf niemals ein anderes
      // Dokument liefern. Diese Assertion macht eine echte Abweichung sichtbar,
      // ohne parallele Debug-Ausgaben verschiedener Requests zu vermischen.
      assert(
        document.id == cleanedUserId,
        'UserProfileRepository UID mismatch: '
        'requested=$cleanedUserId, received=${document.id}',
      );

      final profile = _profileFromSnapshot(
        id: document.id,
        data: document.data() ?? <String, dynamic>{},
      );

      _profileCache[cleanedUserId] = _CachedUserProfile(
        profile: profile,
        cachedAt: DateTime.now(),
      );

      if (kDebugMode) {
        debugPrint(
          'LUMA PROFILE FETCH OK: '
          'requested="$cleanedUserId", document="${document.id}", '
          'displayName="${profile.displayName}"',
        );
      }

      return profile;
    } on FirebaseException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'LUMA PROFILE FIREBASE ERROR: '
          'uid="$cleanedUserId", code=${error.code}, '
          'message=${error.message}',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'LUMA PROFILE UNKNOWN ERROR: '
          'uid="$cleanedUserId", error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<List<LumaUserProfileModel>> fetchProfilesByIds({
    required List<String> userIds,
    bool forceRefresh = false,
  }) async {
    final cleanedIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (cleanedIds.isEmpty) {
      return const <LumaUserProfileModel>[];
    }

    final profilesById = <String, LumaUserProfileModel>{};
    final idsToLoad = <String>[];

    for (final userId in cleanedIds) {
      final cached = _profileCache[userId];

      if (!forceRefresh &&
          cached != null &&
          !cached.isExpired(_profileCacheTtl)) {
        profilesById[userId] = cached.profile;
      } else {
        idsToLoad.add(userId);
      }
    }

    for (var offset = 0;
        offset < idsToLoad.length;
        offset += _whereInChunkSize) {
      final end = (offset + _whereInChunkSize).clamp(
        0,
        idsToLoad.length,
      );

      final chunk = idsToLoad.sublist(offset, end);

      final snapshot = await _usersRef
          .where(
            FieldPath.documentId,
            whereIn: chunk,
          )
          .get();

      final returnedIds = <String>{};

      for (final document in snapshot.docs) {
        returnedIds.add(document.id);

        final profile = _profileFromDocument(document);
        profilesById[profile.id] = profile;

        _profileCache[profile.id] = _CachedUserProfile(
          profile: profile,
          cachedAt: DateTime.now(),
        );
      }

      for (final missingId in chunk.where(
        (id) => !returnedIds.contains(id),
      )) {
        _profileCache.remove(missingId);
      }
    }

    final profiles = cleanedIds
        .map((id) => profilesById[id])
        .whereType<LumaUserProfileModel>()
        .toList(growable: false);

    profiles.sort(
      (a, b) => a.displayNameLowercase.compareTo(
        b.displayNameLowercase,
      ),
    );

    return List<LumaUserProfileModel>.unmodifiable(profiles);
  }

  Stream<LumaUserProfileModel?> watchProfile({
    required String userId,
  }) {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return const Stream<LumaUserProfileModel?>.empty();
    }

    return _usersRef.doc(cleanedUserId).snapshots().map((document) {
      if (!document.exists) {
        _profileCache.remove(cleanedUserId);
        return null;
      }

      final profile = _profileFromSnapshot(
        id: document.id,
        data: document.data() ?? <String, dynamic>{},
      );

      _profileCache[cleanedUserId] = _CachedUserProfile(
        profile: profile,
        cachedAt: DateTime.now(),
      );

      return profile;
    });
  }

  Future<List<LumaUserProfileModel>> searchProfiles({
    required String query,
    required String currentUserId,
    int limit = 50,
    bool includeCurrentUser = true,
  }) async {
    final cleanedQuery = _normalizeSearchText(query);
    final usernameQuery = _normalizeUsernameQuery(query);
    final compactQuery = cleanedQuery.replaceAll(' ', '');
    final cleanedCurrentUserId = currentUserId.trim();

    if (cleanedQuery.isEmpty && usernameQuery.isEmpty) {
      return const <LumaUserProfileModel>[];
    }

    final safeLimit = limit.clamp(1, 100).toInt();
    final profilesById = <String, LumaUserProfileModel>{};

    Future<void> addSnapshotResults(
      Future<QuerySnapshot<Map<String, dynamic>>> future,
    ) async {
      final snapshot = await future;

      for (final document in snapshot.docs) {
        final profile = _profileFromDocument(document);

        if (!includeCurrentUser && profile.id == cleanedCurrentUserId) {
          continue;
        }

        if (_matchesSearch(
          profile: profile,
          cleanedQuery: cleanedQuery,
          usernameQuery: usernameQuery,
          compactQuery: compactQuery,
        )) {
          profilesById[profile.id] = profile;
        }
      }
    }

    final futures = <Future<void>>[];

    if (usernameQuery.isNotEmpty) {
      futures.add(
        addSnapshotResults(
          _buildPrefixQuery(
            field: 'usernameLowercase',
            value: usernameQuery,
            limit: safeLimit,
          ).get(),
        ),
      );

      futures.add(
        addSnapshotResults(
          _usersRef
              .where(
                'searchKeywords',
                arrayContains: usernameQuery,
              )
              .limit(safeLimit)
              .get(),
        ),
      );
    }

    if (cleanedQuery.isNotEmpty) {
      futures.add(
        addSnapshotResults(
          _buildPrefixQuery(
            field: 'displayNameLowercase',
            value: cleanedQuery,
            limit: safeLimit,
          ).get(),
        ),
      );

      futures.add(
        addSnapshotResults(
          _usersRef
              .where(
                'searchKeywords',
                arrayContains: cleanedQuery,
              )
              .limit(safeLimit)
              .get(),
        ),
      );
    }

    if (compactQuery.isNotEmpty && compactQuery != cleanedQuery) {
      futures.add(
        addSnapshotResults(
          _usersRef
              .where(
                'searchKeywords',
                arrayContains: compactQuery,
              )
              .limit(safeLimit)
              .get(),
        ),
      );
    }

    if (cleanedQuery.contains('@')) {
      futures.add(
        addSnapshotResults(
          _buildPrefixQuery(
            field: 'emailLowercase',
            value: cleanedQuery,
            limit: safeLimit,
          ).get(),
        ),
      );
    } else if (cleanedQuery.length >= 3) {
      futures.add(
        addSnapshotResults(
          _buildPrefixQuery(
            field: 'emailLowercase',
            value: cleanedQuery,
            limit: safeLimit,
          ).get(),
        ),
      );
    }

    if (futures.isEmpty) {
      return const <LumaUserProfileModel>[];
    }

    await Future.wait(futures);

    final results = profilesById.values.toList(growable: false);

    results.sort((a, b) {
      final aScore = _searchScore(
        profile: a,
        cleanedQuery: cleanedQuery,
        usernameQuery: usernameQuery,
        compactQuery: compactQuery,
        currentUserId: cleanedCurrentUserId,
      );

      final bScore = _searchScore(
        profile: b,
        cleanedQuery: cleanedQuery,
        usernameQuery: usernameQuery,
        compactQuery: compactQuery,
        currentUserId: cleanedCurrentUserId,
      );

      if (aScore != bScore) return bScore.compareTo(aScore);

      return a.displayNameLowercase.compareTo(b.displayNameLowercase);
    });

    return results.take(safeLimit).toList(growable: false);
  }

  Future<LumaUserProfileModel> createProfileIfMissing({
    required String userId,
    String? displayName,
    String? username,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User ID darf nicht leer sein.',
      );
    }

    final documentRef = _usersRef.doc(cleanedUserId);
    final document = await documentRef.get();

    if (document.exists) {
      final rawData = document.data() ?? <String, dynamic>{};

      final existingProfile = _profileFromSnapshot(
        id: document.id,
        data: rawData,
      );

      final nextDisplayName = _normalizeText(
        existingProfile.displayName,
        fallback: _normalizeText(
          displayName,
          fallback: 'Luma Nutzer',
        ),
      );

      final nextUsername = _normalizeUsername(
        existingProfile.username,
        fallbackSource: username ?? nextDisplayName,
      );

      final nextEmail = _normalizeNullableText(email) ?? existingProfile.email;

      final nextPhoneNumber =
          _normalizeNullableText(phoneNumber) ?? existingProfile.phoneNumber;

      final repairedProfile = existingProfile.copyWith(
        id: cleanedUserId,
        displayName: nextDisplayName,
        username: nextUsername,
        email: nextEmail,
        phoneNumber: nextPhoneNumber,
        avatarUrl:
            _normalizeNullableText(avatarUrl) ?? existingProfile.avatarUrl,
        updatedAt: DateTime.now(),
      );

      final shouldRepair = _profileNeedsSearchRepair(
        rawData: rawData,
        profile: repairedProfile,
      );

      if (shouldRepair) {
        await documentRef.set(
          _profileToFirestoreMap(repairedProfile),
          SetOptions(merge: true),
        );
      } else if (email != null || phoneNumber != null || avatarUrl != null) {
        await documentRef.set(
          {
            'email': repairedProfile.email,
            'phoneNumber': repairedProfile.phoneNumber,
            'emailLowercase': repairedProfile.emailLowercase,
            'phoneNumberSearch': repairedProfile.phoneNumberSearch,
            'avatarUrl': repairedProfile.avatarUrl,
            'searchKeywords': repairedProfile.searchKeywords,
            'updatedAt': Timestamp.fromDate(repairedProfile.updatedAt),
          },
          SetOptions(merge: true),
        );
      }

      return repairedProfile;
    }

    final now = DateTime.now();

    final safeDisplayName = _normalizeText(
      displayName,
      fallback: 'Luma Nutzer',
    );

    final safeUsername = _normalizeUsername(
      username,
      fallbackSource: safeDisplayName,
    );

    final profile = LumaUserProfileModel(
      id: cleanedUserId,
      displayName: safeDisplayName,
      username: safeUsername,
      email: _normalizeNullableText(email),
      phoneNumber: _normalizeNullableText(phoneNumber),
      avatarUrl: _normalizeNullableText(avatarUrl),
      createdAt: now,
      updatedAt: now,
    );

    await documentRef.set(_profileToFirestoreMap(profile));

    return profile;
  }

  Future<void> saveProfile({
    required LumaUserProfileModel profile,
  }) async {
    final cleanedUserId = profile.id.trim();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError.value(
        profile.id,
        'profile.id',
        'Profil-ID darf nicht leer sein.',
      );
    }

    final normalizedProfile = profile.copyWith(
      id: cleanedUserId,
      displayName: _normalizeText(
        profile.displayName,
        fallback: 'Luma Nutzer',
      ),
      username: _normalizeUsername(
        profile.username,
        fallbackSource: profile.displayName,
      ),
      email: _normalizeNullableText(profile.email),
      phoneNumber: _normalizeNullableText(profile.phoneNumber),
      updatedAt: DateTime.now(),
    );

    await _usersRef.doc(cleanedUserId).set(
          _profileToFirestoreMap(normalizedProfile),
          SetOptions(merge: true),
        );
  }

  Future<void> updateProfileFields({
    required String userId,
    String? displayName,
    String? username,
    String? email,
    String? phoneNumber,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    bool? isPrivate,
    bool? isVerified,
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
    bool clearBirthday = false,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User ID darf nicht leer sein.',
      );
    }

    final currentProfile = await fetchProfile(userId: cleanedUserId);

    final nextDisplayName = _normalizeText(
      displayName ?? currentProfile?.displayName,
      fallback: 'Luma Nutzer',
    );

    final nextUsername = _normalizeUsername(
      username ?? currentProfile?.username,
      fallbackSource: nextDisplayName,
    );

    final nextEmail = _normalizeNullableText(email ?? currentProfile?.email);

    final nextPhoneNumber = _normalizeNullableText(
      phoneNumber ?? currentProfile?.phoneNumber,
    );

    final updates = <String, dynamic>{
      'displayName': nextDisplayName,
      'username': nextUsername,
      'email': nextEmail,
      'phoneNumber': nextPhoneNumber,
      'displayNameLowercase': _normalizeSearchText(nextDisplayName),
      'usernameLowercase': _normalizeSearchText(nextUsername),
      'emailLowercase': _normalizeSearchText(nextEmail ?? ''),
      'phoneNumberSearch': _normalizePhoneNumber(nextPhoneNumber ?? ''),
      'searchKeywords': LumaUserProfileModel.buildSearchKeywords(
        displayName: nextDisplayName,
        username: nextUsername,
        email: nextEmail,
        phoneNumber: nextPhoneNumber,
      ),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (bio != null) {
      updates['bio'] = _normalizeNullableText(bio);
    }

    if (avatarUrl != null) {
      updates['avatarUrl'] = _normalizeNullableText(avatarUrl);
    }

    if (coverUrl != null) {
      updates['coverUrl'] = _normalizeNullableText(coverUrl);
    }

    if (isPrivate != null) {
      updates['isPrivate'] = isPrivate;
    }

    if (isVerified != null) {
      updates['isVerified'] = isVerified;
    }


    if (location != null) {
      updates['location'] = _normalizeNullableText(location);
    }

    if (work != null) {
      updates['work'] = _normalizeNullableText(work);
    }

    if (education != null) {
      updates['education'] = _normalizeNullableText(education);
    }

    if (website != null) {
      updates['website'] = _normalizeNullableText(website);
    }

    if (nickname != null) {
      updates['nickname'] = _normalizeNullableText(nickname);
    }

    if (relationshipStatusText != null) {
      updates['relationshipStatusText'] =
          _normalizeNullableText(relationshipStatusText);
    }

    if (familyInfo != null) {
      updates['familyInfo'] = _normalizeNullableText(familyInfo);
    }

    if (clearBirthday) {
      updates['birthday'] = null;
    } else if (birthday != null) {
      updates['birthday'] = Timestamp.fromDate(birthday);
    }

    if (birthdayVisibility != null) {
      updates['birthdayVisibility'] = birthdayVisibility.name;
    }

    if (birthYearVisibility != null) {
      updates['birthYearVisibility'] = birthYearVisibility.name;
    }

    if (friendsVisibility != null) {
      updates['friendsVisibility'] = friendsVisibility.name;
    }

    if (instagramUrl != null) {
      updates['instagramUrl'] = _normalizeNullableText(instagramUrl);
    }

    if (youtubeUrl != null) {
      updates['youtubeUrl'] = _normalizeNullableText(youtubeUrl);
    }

    if (spotifyUrl != null) {
      updates['spotifyUrl'] = _normalizeNullableText(spotifyUrl);
    }

    if (tiktokUrl != null) {
      updates['tiktokUrl'] = _normalizeNullableText(tiktokUrl);
    }

    if (facebookUrl != null) {
      updates['facebookUrl'] = _normalizeNullableText(facebookUrl);
    }

    if (whatsappUrl != null) {
      updates['whatsappUrl'] = _normalizeNullableText(whatsappUrl);
    }

    if (twitterUrl != null) {
      updates['twitterUrl'] = _normalizeNullableText(twitterUrl);
    }

    await _usersRef.doc(cleanedUserId).set(
          updates,
          SetOptions(merge: true),
        );
  }

  Future<bool> profileExists({
    required String userId,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return false;

    final document = await _usersRef.doc(cleanedUserId).get();

    return document.exists;
  }

  Future<void> repairOwnSearchFields({
    required String userId,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    final documentRef = _usersRef.doc(cleanedUserId);
    final document = await documentRef.get();

    if (!document.exists) return;

    final profile = _profileFromSnapshot(
      id: document.id,
      data: document.data() ?? <String, dynamic>{},
    );

    await documentRef.set(
      _profileToFirestoreMap(
        profile.copyWith(
          id: cleanedUserId,
          displayName: _normalizeText(
            profile.displayName,
            fallback: 'Luma Nutzer',
          ),
          username: _normalizeUsername(
            profile.username,
            fallbackSource: profile.displayName,
          ),
          email: _normalizeNullableText(profile.email),
          phoneNumber: _normalizeNullableText(profile.phoneNumber),
          updatedAt: DateTime.now(),
        ),
      ),
      SetOptions(merge: true),
    );
  }


  Future<void> updatePresence({
    required String userId,
    required bool isOnline,
    DateTime? lastSeenAt,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final resolvedLastSeenAt = lastSeenAt ?? now;

    await _usersRef.doc(cleanedUserId).set(
      {
        'isOnline': isOnline,
        'lastSeenAt': Timestamp.fromDate(resolvedLastSeenAt),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
  }

  Query<Map<String, dynamic>> _buildPrefixQuery({
    required String field,
    required String value,
    required int limit,
  }) {
    final cleanedValue = value.trim();

    return _usersRef
        .orderBy(field)
        .startAt([cleanedValue])
        .endAt(['$cleanedValue\uf8ff'])
        .limit(limit);
  }

  bool _matchesSearch({
    required LumaUserProfileModel profile,
    required String cleanedQuery,
    required String usernameQuery,
    required String compactQuery,
  }) {
    final displayName = _normalizeSearchText(profile.displayName);
    final username = _normalizeSearchText(profile.username);
    final usernameWithAt = '@$username';
    final email = _normalizeSearchText(profile.email ?? '');
    final phoneNumber = _normalizePhoneNumber(profile.phoneNumber ?? '');
    final compactDisplayName = displayName.replaceAll(' ', '');
    final compactUsername = username.replaceAll(' ', '');

    return displayName.contains(cleanedQuery) ||
        compactDisplayName.contains(compactQuery) ||
        username.contains(usernameQuery) ||
        usernameWithAt.contains(cleanedQuery) ||
        compactUsername.contains(compactQuery) ||
        email.contains(cleanedQuery) ||
        phoneNumber.contains(compactQuery) ||
        profile.searchKeywords.contains(cleanedQuery) ||
        profile.searchKeywords.contains(usernameQuery) ||
        profile.searchKeywords.contains(compactQuery);
  }

  int _searchScore({
    required LumaUserProfileModel profile,
    required String cleanedQuery,
    required String usernameQuery,
    required String compactQuery,
    required String currentUserId,
  }) {
    var score = 0;

    final displayName = _normalizeSearchText(profile.displayName);
    final username = _normalizeSearchText(profile.username);
    final email = _normalizeSearchText(profile.email ?? '');
    final phoneNumber = _normalizePhoneNumber(profile.phoneNumber ?? '');
    final compactDisplayName = displayName.replaceAll(' ', '');
    final compactUsername = username.replaceAll(' ', '');

    if (profile.id == currentUserId) score += 1000;
    if (username == usernameQuery) score += 900;
    if ('@$username' == cleanedQuery) score += 880;
    if (email == cleanedQuery) score += 850;
    if (phoneNumber == compactQuery) score += 830;
    if (displayName == cleanedQuery) score += 800;
    if (compactDisplayName == compactQuery) score += 700;
    if (compactUsername == compactQuery) score += 650;
    if (username.startsWith(usernameQuery)) score += 500;
    if (displayName.startsWith(cleanedQuery)) score += 450;
    if (email.startsWith(cleanedQuery)) score += 400;
    if (phoneNumber.startsWith(compactQuery)) score += 360;
    if (profile.searchKeywords.contains(cleanedQuery)) score += 300;
    if (profile.searchKeywords.contains(usernameQuery)) score += 250;
    if (profile.searchKeywords.contains(compactQuery)) score += 220;
    if (displayName.contains(cleanedQuery)) score += 120;
    if (username.contains(usernameQuery)) score += 110;
    if (email.contains(cleanedQuery)) score += 90;
    if (phoneNumber.contains(compactQuery)) score += 80;

    return score;
  }

  bool _profileNeedsSearchRepair({
    required Map<String, dynamic> rawData,
    required LumaUserProfileModel profile,
  }) {
    final expectedDisplayNameLowercase =
        _normalizeSearchText(profile.displayName);
    final expectedUsernameLowercase = _normalizeSearchText(profile.username);
    final expectedEmailLowercase = _normalizeSearchText(profile.email ?? '');
    final expectedPhoneNumberSearch =
        _normalizePhoneNumber(profile.phoneNumber ?? '');
    final expectedKeywords = profile.searchKeywords;

    final rawDisplayNameLowercase = rawData['displayNameLowercase'];
    final rawUsernameLowercase = rawData['usernameLowercase'];
    final rawEmailLowercase = rawData['emailLowercase'];
    final rawPhoneNumberSearch = rawData['phoneNumberSearch'];
    final rawSearchKeywords = rawData['searchKeywords'];

    if (rawDisplayNameLowercase != expectedDisplayNameLowercase) {
      return true;
    }

    if (rawUsernameLowercase != expectedUsernameLowercase) {
      return true;
    }

    if (rawEmailLowercase != expectedEmailLowercase) {
      return true;
    }

    if (rawPhoneNumberSearch != expectedPhoneNumberSearch) {
      return true;
    }

    if (rawSearchKeywords is! List) {
      return true;
    }

    final existingKeywords = rawSearchKeywords
        .whereType<String>()
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toSet();

    final expectedKeywordSet = expectedKeywords.toSet();

    if (existingKeywords.length != expectedKeywordSet.length) {
      return true;
    }

    return !existingKeywords.containsAll(expectedKeywordSet);
  }

  LumaUserProfileModel _profileFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return _profileFromSnapshot(
      id: document.id,
      data: document.data(),
    );
  }

  LumaUserProfileModel _profileFromSnapshot({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return LumaUserProfileModel.fromMap({
      ...data,
      'id': id,
    });
  }

  Map<String, dynamic> _profileToFirestoreMap(LumaUserProfileModel profile) {
    return profile.toMap();
  }

  static String _normalizeText(
    String? value, {
    required String fallback,
  }) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }

  static String? _normalizeNullableText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _normalizeUsername(
    String? value, {
    required String fallbackSource,
  }) {
    final source =
        value == null || value.trim().isEmpty ? fallbackSource : value;

    final normalized = source
        .trim()
        .toLowerCase()
        .replaceAll('@', '')
        .replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (normalized.isEmpty) return 'luma_user';

    return normalized;
  }

  static String _normalizeUsernameQuery(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('@', '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeSearchText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizePhoneNumber(String value) {
    return value.trim().replaceAll(RegExp(r'[\s().-]+'), '');
  }
}


class _CachedUserProfile {
  final LumaUserProfileModel profile;
  final DateTime cachedAt;

  const _CachedUserProfile({
    required this.profile,
    required this.cachedAt,
  });

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}
