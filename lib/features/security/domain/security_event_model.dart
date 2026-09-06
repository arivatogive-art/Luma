// Pfad: lib/features/security/domain/security_event_model.dart
//
// Luma Core Rebuild 2.0 - Sicherheit & Anmeldung, Phase C1.
// Read-only Modell für bestehende users/{uid}/security_events/{eventId}.

import 'package:cloud_firestore/cloud_firestore.dart';

enum SecurityEventSeverity { low, medium, high, critical, unknown }

class SecurityEventModel {
  const SecurityEventModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.deviceId,
    required this.deviceName,
    required this.platformLabel,
    required this.read,
    required this.createdAt,
    required this.readAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String type;
  final SecurityEventSeverity severity;
  final String title;
  final String description;
  final String? deviceId;
  final String? deviceName;
  final String? platformLabel;
  final bool read;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? updatedAt;

  bool get isUnread => !read;

  bool get isHighRisk =>
      severity == SecurityEventSeverity.high ||
      severity == SecurityEventSeverity.critical;

  factory SecurityEventModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return SecurityEventModel(
      id: _readString(data['id'], fallback: document.id),
      userId: _readString(data['userId']),
      type: _readString(data['type'], fallback: 'unknown'),
      severity: _readSeverity(data['severity']),
      title: _readString(data['title'], fallback: 'Sicherheitsereignis'),
      description: _readString(
        data['description'],
        fallback:
            'Für dieses Sicherheitsereignis liegen keine weiteren Angaben vor.',
      ),
      deviceId: _readNullableString(data['deviceId']),
      deviceName: _readNullableString(data['deviceName']),
      platformLabel: _readNullableString(data['platformLabel']),
      read: data['read'] == true,
      createdAt: _readDateTime(data['createdAt']),
      readAt: _readDateTime(data['readAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  static SecurityEventSeverity _readSeverity(Object? value) {
    final cleaned = value is String ? value.trim().toLowerCase() : '';

    return switch (cleaned) {
      'low' => SecurityEventSeverity.low,
      'medium' => SecurityEventSeverity.medium,
      'high' => SecurityEventSeverity.high,
      'critical' => SecurityEventSeverity.critical,
      _ => SecurityEventSeverity.unknown,
    };
  }

  static String _readString(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final cleaned = value.trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static String? _readNullableString(Object? value) {
    final cleaned = _readString(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.isNotEmpty) {
        return DateTime.tryParse(cleaned);
      }
    }

    return null;
  }
}
