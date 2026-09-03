// Pfad: lib/data/legal_consent_repository.dart
//
// Unveränderbarer Nachweis der bei einer Registrierung bestätigten
// Luma-Rechtsdokumente.
//
// Wichtig:
// - acceptedAt wird ausschließlich als Firestore-Serverzeit geschrieben.
// - Bestehende Einträge werden niemals überschrieben.
// - Pro erfolgreicher Zustimmung entsteht ein eigener Audit-Eintrag.

import 'package:cloud_firestore/cloud_firestore.dart';

class LegalConsentRepository {
  LegalConsentRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String currentTermsVersion = '2026-08';
  static const String currentPrivacyVersion = '2026-08';

  static const String _usersCollection = 'users';
  static const String _legalConsentsCollection = 'legal_consents';

  final FirebaseFirestore _firestore;

  Future<void> recordRegistrationConsent({
    required String userId,
    required String source,
  }) async {
    final cleanedUserId = userId.trim();
    final cleanedSource = source.trim().toLowerCase();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User ID darf nicht leer sein.',
      );
    }

    if (cleanedSource != 'email' && cleanedSource != 'google') {
      throw ArgumentError.value(
        source,
        'source',
        'Quelle muss "email" oder "google" sein.',
      );
    }

    final document = _firestore
        .collection(_usersCollection)
        .doc(cleanedUserId)
        .collection(_legalConsentsCollection)
        .doc();

    await document.set(
      <String, dynamic>{
        'userId': cleanedUserId,
        'termsAccepted': true,
        'termsVersion': currentTermsVersion,
        'privacyAcknowledged': true,
        'privacyVersion': currentPrivacyVersion,
        'acceptedAt': FieldValue.serverTimestamp(),
        'source': cleanedSource,
        'context': 'registration',
        'schemaVersion': 1,
      },
    );
  }
}
