// Pfad: lib/features/security/domain/security_device_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityDeviceModel {
  const SecurityDeviceModel({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.platformLabel,
    required this.platformType,
    required this.appContext,
    required this.trusted,
    required this.active,
    this.firstSeenAt,
    this.lastSeenAt,
    this.lastLoginAt,
    this.disabledAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String deviceName;
  final String platformLabel;
  final String platformType;
  final String appContext;
  final bool trusted;
  final bool active;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final DateTime? lastLoginAt;
  final DateTime? disabledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isKnown => id.trim().isNotEmpty && deviceName.trim().isNotEmpty;

  factory SecurityDeviceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return SecurityDeviceModel(
      id: _readString(data['id'], fallback: snapshot.id),
      userId: _readString(data['userId']),
      deviceName: _readString(data['deviceName'], fallback: 'Unbekanntes Gerät'),
      platformLabel: _readString(
        data['platformLabel'],
        fallback: 'Unbekannte Plattform',
      ),
      platformType: _readString(data['platformType'], fallback: 'unknown'),
      appContext: _readString(data['appContext'], fallback: 'unknown'),
      trusted: data['trusted'] == true,
      active: data['active'] == true,
      firstSeenAt: _readDateTime(data['firstSeenAt']),
      lastSeenAt: _readDateTime(data['lastSeenAt']),
      lastLoginAt: _readDateTime(data['lastLoginAt']),
      disabledAt: _readDateTime(data['disabledAt']),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  static String _readString(
    Object? value, {
    String fallback = '',
  }) {
    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.isNotEmpty) return cleaned;
    }
    return fallback;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }
}
