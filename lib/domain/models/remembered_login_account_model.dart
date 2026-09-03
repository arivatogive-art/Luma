// Pfad: lib/domain/models/remembered_login_account_model.dart

import 'package:flutter/foundation.dart';

@immutable
class RememberedLoginAccountModel {
  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final String userId;
  final String displayName;
  final String? email;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime lastLoginAt;
  final String signInProvider;

  const RememberedLoginAccountModel({
    required this.userId,
    required this.displayName,
    required this.lastLoginAt,
    this.email,
    this.phoneNumber,
    this.avatarUrl,
    this.signInProvider = 'password',
    this.schemaVersion = currentSchemaVersion,
  });

  bool get hasEmail {
    return email != null && email!.trim().isNotEmpty;
  }

  bool get hasPhoneNumber {
    return phoneNumber != null && phoneNumber!.trim().isNotEmpty;
  }

  bool get hasAvatar {
    return avatarUrl != null && avatarUrl!.trim().isNotEmpty;
  }

  bool get isGoogleAccount {
    return normalizedSignInProvider == 'google.com';
  }

  bool get isPhoneAccount {
    return normalizedSignInProvider == 'phone';
  }

  bool get isEmailPasswordAccount {
    return normalizedSignInProvider == 'password';
  }

  String get normalizedSignInProvider {
    return _normalizeProvider(signInProvider);
  }

  String get providerLabel {
    if (isGoogleAccount) return 'Google';
    if (isPhoneAccount) return 'Telefon';
    return 'E-Mail';
  }

  String get primaryIdentifier {
    final cleanedEmail = _cleanNullableString(email);
    if (cleanedEmail != null) return cleanedEmail;

    final cleanedPhoneNumber = _cleanNullableString(phoneNumber);
    if (cleanedPhoneNumber != null) return cleanedPhoneNumber;

    final cleanedDisplayName = displayName.trim();
    if (cleanedDisplayName.isNotEmpty) return cleanedDisplayName;

    return 'Luma Konto';
  }

  String get safeDisplayName {
    final cleanedDisplayName = displayName.trim();
    if (cleanedDisplayName.isNotEmpty) return cleanedDisplayName;

    final cleanedEmail = _cleanNullableString(email);
    if (cleanedEmail != null) {
      final localPart = cleanedEmail.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
    }

    final cleanedPhoneNumber = _cleanNullableString(phoneNumber);
    if (cleanedPhoneNumber != null) return cleanedPhoneNumber;

    return 'Luma Nutzer';
  }

  String get stableAccountKey {
    return userId.trim();
  }

  bool matchesUserId(String? value) {
    final cleanedValue = value?.trim();
    if (cleanedValue == null || cleanedValue.isEmpty) return false;
    return stableAccountKey == cleanedValue;
  }

  RememberedLoginAccountModel copyWith({
    int? schemaVersion,
    String? userId,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    DateTime? lastLoginAt,
    String? signInProvider,
    bool clearEmail = false,
    bool clearPhoneNumber = false,
    bool clearAvatarUrl = false,
  }) {
    return RememberedLoginAccountModel(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: clearEmail ? null : email ?? this.email,
      phoneNumber:
          clearPhoneNumber ? null : phoneNumber ?? this.phoneNumber,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      signInProvider: signInProvider ?? this.signInProvider,
    );
  }

  RememberedLoginAccountModel normalized() {
    return RememberedLoginAccountModel(
      schemaVersion: currentSchemaVersion,
      userId: userId.trim(),
      displayName: safeDisplayName,
      email: _cleanNullableString(email),
      phoneNumber: _cleanNullableString(phoneNumber),
      avatarUrl: _cleanNullableString(avatarUrl),
      lastLoginAt: lastLoginAt,
      signInProvider: normalizedSignInProvider,
    );
  }

  factory RememberedLoginAccountModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return RememberedLoginAccountModel(
      schemaVersion: _readSchemaVersion(map['schemaVersion']),
      userId: _readString(map['userId']),
      displayName: _readString(
        map['displayName'],
        fallback: 'Luma Nutzer',
      ),
      email: _readNullableString(map['email']),
      phoneNumber: _readNullableString(map['phoneNumber']),
      avatarUrl: _readNullableString(map['avatarUrl']),
      lastLoginAt: _readDateTime(map['lastLoginAt']),
      signInProvider: _normalizeProvider(
        map['signInProvider'],
      ),
    ).normalized();
  }

  Map<String, dynamic> toMap() {
    final normalizedModel = normalized();

    return {
      'schemaVersion': currentSchemaVersion,
      'userId': normalizedModel.userId,
      'displayName': normalizedModel.displayName,
      'email': normalizedModel.email,
      'phoneNumber': normalizedModel.phoneNumber,
      'avatarUrl': normalizedModel.avatarUrl,
      'lastLoginAt':
          normalizedModel.lastLoginAt.toIso8601String(),
      'signInProvider':
          normalizedModel.normalizedSignInProvider,
    };
  }

  static int _readSchemaVersion(dynamic value) {
    if (value is int && value > 0) {
      return value;
    }

    if (value is num && value.toInt() > 0) {
      return value.toInt();
    }

    return 1;
  }

  static String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static String? _readNullableString(dynamic value) {
    if (value is! String) return null;
    return _cleanNullableString(value);
  }

  static String? _cleanNullableString(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  static DateTime _readDateTime(dynamic value) {
    if (value is DateTime) return value;

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
      );
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed;

      final milliseconds = int.tryParse(value.trim());
      if (milliseconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _normalizeProvider(dynamic value) {
    if (value is! String) return 'password';

    final cleaned = value.trim().toLowerCase();

    if (cleaned == 'google.com' ||
        cleaned == 'google' ||
        cleaned == 'google_sign_in') {
      return 'google.com';
    }

    if (cleaned == 'phone' ||
        cleaned == 'phone_number' ||
        cleaned == 'sms') {
      return 'phone';
    }

    return 'password';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RememberedLoginAccountModel &&
        other.schemaVersion == schemaVersion &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.avatarUrl == avatarUrl &&
        other.lastLoginAt == lastLoginAt &&
        other.signInProvider == signInProvider;
  }

  @override
  int get hashCode {
    return Object.hash(
      schemaVersion,
      userId,
      displayName,
      email,
      phoneNumber,
      avatarUrl,
      lastLoginAt,
      signInProvider,
    );
  }

  @override
  String toString() {
    return 'RememberedLoginAccountModel('
        'schemaVersion: $schemaVersion, '
        'userId: $userId, '
        'displayName: $displayName, '
        'email: ${email == null ? 'null' : '[stored]'}, '
        'phoneNumber: ${phoneNumber == null ? 'null' : '[stored]'}, '
        'avatarUrl: ${avatarUrl == null ? 'null' : '[stored]'}, '
        'lastLoginAt: $lastLoginAt, '
        'signInProvider: $signInProvider'
        ')';
  }
}
