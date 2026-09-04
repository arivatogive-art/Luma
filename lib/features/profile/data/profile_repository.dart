// Pfad: lib/features/profile/data/profile_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_model.dart';

class ProfileRepository {
  ProfileRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<ProfileModel?> fetchProfile({
    required String uid,
  }) async {
    final cleanedUid = uid.trim();
    if (cleanedUid.isEmpty) return null;

    final snapshot =
        await _firestore.collection('users').doc(cleanedUid).get();

    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) return null;

    return ProfileModel.fromFirestore(
      uid: snapshot.id,
      data: data,
    );
  }

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String username,
    required String bio,
    required String location,
    required String work,
    required String education,
    required String website,
  }) async {
    final cleanedUid = uid.trim();

    if (cleanedUid.isEmpty) {
      throw ArgumentError.value(
        uid,
        'uid',
        'User ID darf nicht leer sein.',
      );
    }

    final cleanedDisplayName = displayName.trim();
    final cleanedUsername = _normalizeUsername(username);

    if (cleanedDisplayName.isEmpty) {
      throw ArgumentError(
        'Der Anzeigename darf nicht leer sein.',
      );
    }

    if (cleanedUsername.isEmpty) {
      throw ArgumentError(
        'Der Benutzername darf nicht leer sein.',
      );
    }

    await _firestore.collection('users').doc(cleanedUid).update(
      <String, dynamic>{
        'displayName': cleanedDisplayName,
        'username': cleanedUsername,
        'displayNameLowercase': cleanedDisplayName.toLowerCase(),
        'usernameLowercase': cleanedUsername.toLowerCase(),
        'bio': _nullableString(bio),
        'location': _nullableString(location),
        'work': _nullableString(work),
        'education': _nullableString(education),
        'website': _nullableString(website),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> updateAvatarUrl({
    required String uid,
    required String avatarUrl,
  }) {
    return _updateMediaField(
      uid: uid,
      field: 'avatarUrl',
      value: avatarUrl,
    );
  }

  Future<void> updateCoverUrl({
    required String uid,
    required String coverUrl,
  }) {
    return _updateMediaField(
      uid: uid,
      field: 'coverUrl',
      value: coverUrl,
    );
  }

  Future<void> _updateMediaField({
    required String uid,
    required String field,
    required String value,
  }) async {
    final cleanedUid = uid.trim();
    if (cleanedUid.isEmpty) return;

    await _firestore.collection('users').doc(cleanedUid).update(
      <String, dynamic>{
        field: _nullableString(value),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  static String _normalizeUsername(String value) {
    final cleaned = value.trim();
    if (cleaned.startsWith('@')) {
      return cleaned.substring(1).trim();
    }
    return cleaned;
  }

  static String? _nullableString(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}
