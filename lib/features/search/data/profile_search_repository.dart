// Pfad: lib/features/search/data/profile_search_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_search_result.dart';

class ProfileSearchRepository {
  ProfileSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<List<ProfileSearchResult>> searchProfiles({
    required String query,
    int limit = 25,
  }) async {
    final cleanedQuery = _normalizeSearchText(query);
    final usernameQuery = _normalizeUsernameQuery(query);

    if (cleanedQuery.isEmpty && usernameQuery.isEmpty) {
      return const <ProfileSearchResult>[];
    }

    final safeLimit = limit.clamp(1, 50).toInt();
    final resultsById = <String, ProfileSearchResult>{};

    Future<void> addResults(
      Future<QuerySnapshot<Map<String, dynamic>>> future,
    ) async {
      final snapshot = await future;

      for (final document in snapshot.docs) {
        final result = ProfileSearchResult.fromFirestore(
          uid: document.id,
          data: document.data(),
        );

        if (result.displayName.isEmpty && result.username.isEmpty) {
          continue;
        }

        resultsById[result.uid] = result;
      }
    }

    final futures = <Future<void>>[];

    if (usernameQuery.isNotEmpty) {
      futures.add(
        addResults(
          _buildPrefixQuery(
            field: 'usernameLowercase',
            value: usernameQuery,
            limit: safeLimit,
          ).get(),
        ),
      );
    }

    if (cleanedQuery.isNotEmpty) {
      futures.add(
        addResults(
          _buildPrefixQuery(
            field: 'displayNameLowercase',
            value: cleanedQuery,
            limit: safeLimit,
          ).get(),
        ),
      );
    }

    if (futures.isEmpty) {
      return const <ProfileSearchResult>[];
    }

    await Future.wait(futures);

    final results = resultsById.values.toList(growable: false)
      ..sort((a, b) {
        final aScore = _scoreResult(
          result: a,
          cleanedQuery: cleanedQuery,
          usernameQuery: usernameQuery,
        );
        final bScore = _scoreResult(
          result: b,
          cleanedQuery: cleanedQuery,
          usernameQuery: usernameQuery,
        );

        if (aScore != bScore) {
          return bScore.compareTo(aScore);
        }

        return a.displayNameLowercase.compareTo(b.displayNameLowercase);
      });

    return List<ProfileSearchResult>.unmodifiable(
      results.take(safeLimit),
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
        .startAt(<Object?>[cleanedValue])
        .endAt(<Object?>['$cleanedValue\uf8ff'])
        .limit(limit);
  }

  int _scoreResult({
    required ProfileSearchResult result,
    required String cleanedQuery,
    required String usernameQuery,
  }) {
    var score = 0;

    final displayName = _normalizeSearchText(result.displayName);
    final username = _normalizeSearchText(result.username);

    if (username == usernameQuery) score += 900;
    if ('@$username' == cleanedQuery) score += 880;
    if (displayName == cleanedQuery) score += 800;
    if (username.startsWith(usernameQuery)) score += 500;
    if (displayName.startsWith(cleanedQuery)) score += 450;

    return score;
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
}
