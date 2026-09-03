// Pfad: lib/data/update_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../application/update_state.dart';

class UpdateRepository {
  UpdateRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String currentAppVersion = '1.0.47';

  Future<UpdateVersionInfo> fetchLatestVersionInfo() async {
    try {
      final snapshot =
          await _firestore.collection('app_config').doc('version').get();

      final data = snapshot.data();
      if (data == null) return UpdateVersionInfo.fallback();

      final updateType = _readUpdateType(data['updateType']);
      final isHardUpdate = _readBool(data['isHardUpdate'], false) ||
          _readBool(data['forceUpdate'], false) ||
          updateType == LumaUpdateType.required;

      return UpdateVersionInfo(
        latestVersion: _readVersion(data['latestVersion'], currentAppVersion),
        requiredVersion: _readVersion(
          data['requiredVersion'] ?? data['minimumSupportedVersion'],
          currentAppVersion,
        ),
        title: _readString(
          data['title'],
          _defaultTitle(updateType, isHardUpdate),
        ),
        message: _readString(
          data['message'],
          _defaultMessage(updateType, isHardUpdate),
        ),
        changelog: _readStringList(data['changelog']),
        downloadSizeLabel: _readDownloadSizeLabel(data),
        releaseDateLabel: _readReleaseDateLabel(data['releaseDate']),
        updateType: updateType,
        storeUrl: _readString(data['storeUrl'], ''),
        isEnabled: _readBool(data['isEnabled'], true),
        isHardUpdate: isHardUpdate,
      );
    } catch (error) {
      debugPrint('UpdateRepository.fetchLatestVersionInfo failed: $error');
      return UpdateVersionInfo.fallback();
    }
  }

  static String _readString(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static String _readVersion(Object? value, String fallback) {
    if (value is! String) return fallback;
    final v = value.trim();
    if (v.isEmpty ||
        v == '__KEEP_EXISTING__' ||
        v.toLowerCase() == 'keep_existing') {
      return fallback;
    }
    return v;
  }

  static bool _readBool(Object? value, bool fallback) {
    return value is bool ? value : fallback;
  }

  static List<String> _readStringList(Object? value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return <String>[value.trim()];
    }
    return const <String>[];
  }

  static LumaUpdateType _readUpdateType(Object? value) {
    if (value is! String) return LumaUpdateType.none;
    switch (value.trim().toLowerCase()) {
      case 'optional':
        return LumaUpdateType.optional;
      case 'recommended':
      case 'empfohlen':
        return LumaUpdateType.recommended;
      case 'required':
      case 'force':
      case 'pflicht':
        return LumaUpdateType.required;
      default:
        return LumaUpdateType.none;
    }
  }

  static String _readDownloadSizeLabel(Map<String, dynamic> data) {
    final direct = data['downloadSizeLabel'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();

    final raw = data['updateSizeMb'];
    final number = raw is num
        ? raw.toDouble()
        : raw is String
            ? double.tryParse(raw.replaceAll(',', '.'))
            : null;
    if (number == null || number <= 0) return '';

    final hasDecimal = number % 1 != 0;
    return '${number.toStringAsFixed(hasDecimal ? 1 : 0)} MB';
  }

  static String _readReleaseDateLabel(Object? value) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value.trim());
    }
    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String _defaultTitle(LumaUpdateType type, bool hard) {
    if (hard || type == LumaUpdateType.required) return 'Update erforderlich';
    if (type == LumaUpdateType.recommended) return 'Update empfohlen';
    if (type == LumaUpdateType.optional) {
      return 'Ein neues Luma-Update ist verfügbar.';
    }
    return 'Luma ist aktuell.';
  }

  static String _defaultMessage(LumaUpdateType type, bool hard) {
    if (hard || type == LumaUpdateType.required) {
      return 'Aktualisiere Luma, um die App weiter verwenden zu können.';
    }
    if (type == LumaUpdateType.recommended) {
      return 'Diese Version verbessert Stabilität, Geschwindigkeit und App-Erlebnis.';
    }
    if (type == LumaUpdateType.optional) {
      return 'Aktualisiere Luma, um die neueste Version zu verwenden.';
    }
    return 'Du nutzt bereits die aktuelle Version von Luma.';
  }
}
