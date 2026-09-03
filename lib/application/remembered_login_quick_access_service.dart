// Pfad: lib/application/remembered_login_quick_access_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RememberedLoginQuickAccessService extends ChangeNotifier {
  RememberedLoginQuickAccessService._();

  static final RememberedLoginQuickAccessService instance =
      RememberedLoginQuickAccessService._();

  static const String _stateKey =
      'luma.auth.quickAccess.state.v4';

  static const String _stateKeyV3 =
      'luma.auth.quickAccess.state.v3';

  static const String _stateKeyV2 =
      'luma.auth.quickAccess.state.v2';

  static const String _askedUserIdsKeyV1 =
      'luma.auth.quickAccess.askedUserIds.v1';

  static const String _enabledUserIdsKeyV1 =
      'luma.auth.quickAccess.enabledUserIds.v1';

  static const String _lockedUserIdKeyV1 =
      'luma.auth.quickAccess.lockedUserId.v1';

  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  Set<String> _askedUserIds = <String>{};
  Set<String> _enabledUserIds = <String>{};
  Set<String> _lockedUserIds = <String>{};

  bool get isInitialized => _isInitialized;

  bool get isLocked => _lockedUserIds.isNotEmpty;

  String? get lockedUserId {
    if (_lockedUserIds.length != 1) return null;
    return _lockedUserIds.first;
  }

  Set<String> get lockedUserIds =>
      Set<String>.unmodifiable(_lockedUserIds);

  bool hasAskedFor(String? userId) {
    final cleanedUserId = _cleanUserId(userId);

    if (cleanedUserId == null) {
      return false;
    }

    return _askedUserIds.contains(cleanedUserId);
  }

  bool isEnabledFor(String? userId) {
    final cleanedUserId = _cleanUserId(userId);

    if (cleanedUserId == null) {
      return false;
    }

    return _enabledUserIds.contains(cleanedUserId);
  }

  bool isLockedFor(String? userId) {
    final cleanedUserId = _cleanUserId(userId);

    if (cleanedUserId == null) {
      return false;
    }

    return _lockedUserIds.contains(cleanedUserId);
  }

  Future<void> initialize() {
    if (_isInitialized) {
      return Future<void>.value();
    }

    final existingFuture = _initializationFuture;

    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _initializeInternal();
    _initializationFuture = future;

    return future;
  }

  Future<void> _initializeInternal() async {
    try {
      final preferences =
          await SharedPreferences.getInstance();

      final rawV4State =
          preferences.getString(_stateKey);

      if (rawV4State != null &&
          rawV4State.trim().isNotEmpty &&
          _restoreV4State(rawV4State)) {
        _sanitizeState();

        debugPrint(
          'QUICK ACCESS: V4 state restored. '
          'asked=${_askedUserIds.length}, '
          'enabled=${_enabledUserIds.length}, '
          'locked=${_lockedUserIds.length}',
        );
      } else {
        await _migrateLegacyState(preferences);
      }

      _isInitialized = true;

      debugPrint(
        'QUICK ACCESS INITIALIZED: '
        'askedUserIds=$_askedUserIds, '
        'enabledUserIds=$_enabledUserIds, '
        'lockedUserIds=$_lockedUserIds',
      );

      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint(
        'QUICK ACCESS INITIALIZATION FAILED: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> saveDecision({
    required String userId,
    required bool enabled,
  }) async {
    await initialize();

    final cleanedUserId =
        _requiredUserId(userId);

    _askedUserIds.add(cleanedUserId);

    if (enabled) {
      _enabledUserIds.add(cleanedUserId);
    } else {
      _enabledUserIds.remove(cleanedUserId);
      _lockedUserIds.remove(cleanedUserId);
    }

    await _persistState();

    debugPrint(
      'QUICK ACCESS DECISION SAVED: '
      'userId=$cleanedUserId, enabled=$enabled',
    );

    notifyListeners();
  }

  Future<void> lockForUser(String userId) async {
    await initialize();

    final cleanedUserId =
        _requiredUserId(userId);

    if (!isEnabledFor(cleanedUserId)) {
      throw StateError(
        'Schnellanmeldung ist für dieses Konto nicht aktiviert.',
      );
    }

    if (!_lockedUserIds.add(cleanedUserId)) {
      debugPrint(
        'QUICK ACCESS LOCK SKIPPED: '
        'userId=$cleanedUserId was already locked',
      );
      return;
    }

    await _persistState();

    debugPrint(
      'QUICK ACCESS LOCKED EXPLICITLY: '
      'userId=$cleanedUserId',
    );

    notifyListeners();
  }

  Future<void> unlockForUser(String userId) async {
    await initialize();

    final cleanedUserId =
        _requiredUserId(userId);

    if (!_lockedUserIds.remove(cleanedUserId)) {
      debugPrint(
        'QUICK ACCESS UNLOCK SKIPPED: '
        'userId=$cleanedUserId was not locked',
      );
      return;
    }

    await _persistState();

    debugPrint(
      'QUICK ACCESS UNLOCKED: '
      'userId=$cleanedUserId',
    );

    notifyListeners();
  }

  Future<void> unlock() async {
    await initialize();

    if (_lockedUserIds.isEmpty) {
      return;
    }

    final previouslyLocked =
        Set<String>.from(_lockedUserIds);

    _lockedUserIds.clear();

    await _persistState();

    debugPrint(
      'QUICK ACCESS ALL LOCKS CLEARED: '
      'previouslyLocked=$previouslyLocked',
    );

    notifyListeners();
  }

  Future<void> resetForUser(String userId) async {
    await initialize();

    final cleanedUserId =
        _requiredUserId(userId);

    _askedUserIds.remove(cleanedUserId);
    _enabledUserIds.remove(cleanedUserId);
    _lockedUserIds.remove(cleanedUserId);

    await _persistState();

    debugPrint(
      'QUICK ACCESS USER RESET: '
      'userId=$cleanedUserId',
    );

    notifyListeners();
  }

  Future<void> resetAll() async {
    await initialize();

    _askedUserIds.clear();
    _enabledUserIds.clear();
    _lockedUserIds.clear();

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(_stateKey);
    await preferences.remove(_stateKeyV3);
    await preferences.remove(_stateKeyV2);
    await preferences.remove(_askedUserIdsKeyV1);
    await preferences.remove(_enabledUserIdsKeyV1);
    await preferences.remove(_lockedUserIdKeyV1);

    debugPrint(
      'QUICK ACCESS FULL RESET COMPLETED',
    );

    notifyListeners();
  }

  Future<void> clearLockedSession() => unlock();

  @Deprecated(
    'Verwende unlockForUser(), resetForUser() oder resetAll().',
  )
  Future<void> clear() => unlock();

  Future<void> _migrateLegacyState(
    SharedPreferences preferences,
  ) async {
    final rawV3State =
        preferences.getString(_stateKeyV3);

    final rawV2State =
        preferences.getString(_stateKeyV2);

    if (rawV3State != null &&
        rawV3State.trim().isNotEmpty) {
      _restoreLegacyStateWithoutLocks(
        rawV3State,
      );
    } else if (rawV2State != null &&
        rawV2State.trim().isNotEmpty) {
      _restoreLegacyStateWithoutLocks(
        rawV2State,
      );
    } else {
      _askedUserIds = _readUserIdSet(
        preferences.getStringList(
          _askedUserIdsKeyV1,
        ),
      );

      _enabledUserIds = _readUserIdSet(
        preferences.getStringList(
          _enabledUserIdsKeyV1,
        ),
      );

      _lockedUserIds = <String>{};
    }

    // Alte Sperren werden beim Wechsel auf V4 genau einmal verworfen.
    //
    // Dadurch können fehlerhaft gespeicherte Sperren aus früheren Builds
    // einen weiterhin bei Firebase angemeldeten Nutzer nach einem normalen
    // App-Neustart nicht mehr auf den Loginbildschirm schicken.
    //
    // Neue, ausdrücklich über Logout gesetzte Sperren werden anschließend
    // regulär im V4-Zustand gespeichert und bleiben vollständig wirksam.
    _lockedUserIds = <String>{};

    _sanitizeState();
    await _persistState();

    await preferences.remove(_stateKeyV3);
    await preferences.remove(_stateKeyV2);
    await preferences.remove(_askedUserIdsKeyV1);
    await preferences.remove(_enabledUserIdsKeyV1);
    await preferences.remove(_lockedUserIdKeyV1);

    debugPrint(
      'QUICK ACCESS LEGACY STATE MIGRATED TO V4: '
      'old locks were intentionally cleared once',
    );
  }

  bool _restoreV4State(String rawState) {
    try {
      final decoded = jsonDecode(rawState);

      if (decoded is! Map) {
        return false;
      }

      final map =
          Map<String, dynamic>.from(decoded);

      final schemaVersion =
          _readSchemaVersion(map);

      if (schemaVersion != 4) {
        return false;
      }

      _askedUserIds = _readDynamicUserIdSet(
        map['askedUserIds'],
      );

      _enabledUserIds = _readDynamicUserIdSet(
        map['enabledUserIds'],
      );

      _lockedUserIds = _readDynamicUserIdSet(
        map['lockedUserIds'],
      );

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'QUICK ACCESS V4 STATE READ FAILED: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  void _restoreLegacyStateWithoutLocks(
    String rawState,
  ) {
    try {
      final decoded = jsonDecode(rawState);

      if (decoded is! Map) {
        _askedUserIds = <String>{};
        _enabledUserIds = <String>{};
        _lockedUserIds = <String>{};
        return;
      }

      final map =
          Map<String, dynamic>.from(decoded);

      _askedUserIds = _readDynamicUserIdSet(
        map['askedUserIds'],
      );

      _enabledUserIds = _readDynamicUserIdSet(
        map['enabledUserIds'],
      );

      _lockedUserIds = <String>{};
    } catch (error, stackTrace) {
      debugPrint(
        'QUICK ACCESS LEGACY STATE READ FAILED: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      _askedUserIds = <String>{};
      _enabledUserIds = <String>{};
      _lockedUserIds = <String>{};
    }
  }

  int _readSchemaVersion(
    Map<String, dynamic> map,
  ) {
    final rawValue = map['schemaVersion'];

    if (rawValue is int) {
      return rawValue;
    }

    return int.tryParse(
          rawValue?.toString() ?? '',
        ) ??
        0;
  }

  void _sanitizeState() {
    _askedUserIds =
        _askedUserIds.where(
      (userId) => userId.trim().isNotEmpty,
    ).toSet();

    _enabledUserIds =
        _enabledUserIds.where(
      (userId) => userId.trim().isNotEmpty,
    ).toSet();

    _lockedUserIds = _lockedUserIds
        .where(_enabledUserIds.contains)
        .toSet();
  }

  Future<void> _persistState() async {
    final preferences =
        await SharedPreferences.getInstance();

    final asked =
        _askedUserIds.toList()..sort();

    final enabled =
        _enabledUserIds.toList()..sort();

    final locked =
        _lockedUserIds.toList()..sort();

    final encoded = jsonEncode(
      <String, Object>{
        'schemaVersion': 4,
        'askedUserIds': asked,
        'enabledUserIds': enabled,
        'lockedUserIds': locked,
      },
    );

    final saved = await preferences.setString(
      _stateKey,
      encoded,
    );

    if (!saved) {
      throw StateError(
        'Schnellanmeldungs-Einstellungen konnten nicht gespeichert werden.',
      );
    }
  }

  Set<String> _readUserIdSet(
    List<String>? values,
  ) {
    if (values == null || values.isEmpty) {
      return <String>{};
    }

    return values
        .map(_cleanUserId)
        .whereType<String>()
        .toSet();
  }

  Set<String> _readDynamicUserIdSet(
    Object? values,
  ) {
    if (values is! List) {
      return <String>{};
    }

    return values
        .map(
          (value) =>
              _cleanUserId(value?.toString()),
        )
        .whereType<String>()
        .toSet();
  }

  String _requiredUserId(String userId) {
    final cleanedUserId =
        _cleanUserId(userId);

    if (cleanedUserId == null) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User-ID darf nicht leer sein.',
      );
    }

    return cleanedUserId;
  }

  String? _cleanUserId(String? userId) {
    final cleanedUserId =
        userId?.trim();

    if (cleanedUserId == null ||
        cleanedUserId.isEmpty) {
      return null;
    }

    return cleanedUserId;
  }
}
