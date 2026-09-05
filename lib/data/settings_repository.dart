// Pfad: lib/data/settings_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../application/settings_state.dart';

class SettingsRemoteSnapshot {
  final SettingsState state;
  final DateTime? updatedAt;

  const SettingsRemoteSnapshot({
    required this.state,
    required this.updatedAt,
  });
}

class SettingsRepository {
  SettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _usersCollection = 'users';
  static const String _settingsCollection = 'settings';
  static const String _appSettingsDocument = 'app';

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _settingsRef(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_settingsCollection)
        .doc(_appSettingsDocument);
  }

  Stream<SettingsRemoteSnapshot?> watchSettings(String userId) {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) {
      return Stream<SettingsRemoteSnapshot?>.value(null);
    }

    return _settingsRef(cleanedUserId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) return null;

      return SettingsRemoteSnapshot(
        state: _fromMap(data),
        updatedAt: _readDateTime(data['updatedAt']),
      );
    });
  }

  Future<SettingsRemoteSnapshot?> loadSettings(String userId) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return null;

    final snapshot = await _settingsRef(cleanedUserId).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return SettingsRemoteSnapshot(
      state: _fromMap(data),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  Future<void> saveSettings({
    required String userId,
    required SettingsState state,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    await _settingsRef(cleanedUserId).set(
      {
        ..._toMap(state),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveAppearanceMode({
    required String userId,
    required AppAppearanceMode mode,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    await _settingsRef(cleanedUserId).set(
      {
        'appAppearanceMode': mode.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<SettingsRemoteSnapshot?> saveSettingsAndLoad({
    required String userId,
    required SettingsState state,
  }) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return null;

    await saveSettings(userId: cleanedUserId, state: state);
    return loadSettings(cleanedUserId);
  }

  Future<void> resetSettings(String userId) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    const defaultState = SettingsState.initial();

    await _settingsRef(cleanedUserId).set(
      {
        ..._toMap(defaultState),
        'updatedAt': FieldValue.serverTimestamp(),
        'resetAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<SettingsRemoteSnapshot?> resetSettingsAndLoad(String userId) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return null;

    await resetSettings(cleanedUserId);
    return loadSettings(cleanedUserId);
  }

  Map<String, dynamic> _toMap(SettingsState state) {
    return {
      'isProfilePrivate': state.isProfilePrivate,
      'isProfileDiscoverable': state.isProfileDiscoverable,
      'showProfileInSuggestions': state.showProfileInSuggestions,
      'allowPublicProfilePreview': state.allowPublicProfilePreview,
      'allowFriendRequests': state.allowFriendRequests,
      'searchEngineIndexingEnabled': state.searchEngineIndexingEnabled,
      'twoFactorEnabled': state.twoFactorEnabled,
      'loginAlertsEnabled': state.loginAlertsEnabled,
      'phoneNumber': state.phoneNumber,
      'isPhoneNumberVerified': state.isPhoneNumberVerified,
      'phoneNumberVerifiedAt': _dateTimeToTimestamp(state.phoneNumberVerifiedAt),
      'phoneNumberUpdatedAt': _dateTimeToTimestamp(state.phoneNumberUpdatedAt),
      'twoFactorMethod': state.twoFactorMethod.name,
      'backupCodesGenerated': state.backupCodesGenerated,
      'backupCodesGeneratedAt':
          _dateTimeToTimestamp(state.backupCodesGeneratedAt),
      'securityDeviceSummary':
          _securityDeviceSummaryToMap(state.securityDeviceSummary),
      'securityTimelineSummary':
          _securityTimelineSummaryToMap(state.securityTimelineSummary),
      'trustedDevicesEnabled': state.trustedDevicesEnabled,
      'deviceHistoryEnabled': state.deviceHistoryEnabled,
      'suspiciousLoginProtectionEnabled':
          state.suspiciousLoginProtectionEnabled,
      'sessionRevocationPrepared': state.sessionRevocationPrepared,
      'remoteLogoutPrepared': state.remoteLogoutPrepared,
      'securityAuditTrailEnabled': state.securityAuditTrailEnabled,
      'pushNotificationsEnabled': state.pushNotificationsEnabled,
      'inAppNotificationsEnabled': state.inAppNotificationsEnabled,
      'commentNotificationsEnabled': state.commentNotificationsEnabled,
      'likeNotificationsEnabled': state.likeNotificationsEnabled,
      'replyNotificationsEnabled': state.replyNotificationsEnabled,
      'friendRequestNotificationsEnabled':
          state.friendRequestNotificationsEnabled,
      'messageNotificationsEnabled': state.messageNotificationsEnabled,
      'mentionNotificationsEnabled': state.mentionNotificationsEnabled,
      'quietModeEnabled': state.quietModeEnabled,
      'dailySummaryEnabled': state.dailySummaryEnabled,
      'securityNotificationsEnabled': state.securityNotificationsEnabled,
      'systemUpdateNotificationsEnabled':
          state.systemUpdateNotificationsEnabled,
      'adminSecurityPriorityNotificationsEnabled':
          state.adminSecurityPriorityNotificationsEnabled,
      'moderationNotificationsEnabled': state.moderationNotificationsEnabled,
      'notificationHistoryEnabled': state.notificationHistoryEnabled,
      'notificationGroupingEnabled': state.notificationGroupingEnabled,
      'quietModeAllowSecurityAlerts': state.quietModeAllowSecurityAlerts,
      'notificationPriorityMode': state.notificationPriorityMode.name,
      'digestDeliveryMode': state.digestDeliveryMode.name,
      'notificationGroupingMode': state.notificationGroupingMode.name,
      'blockedUsersProtectionEnabled': state.blockedUsersProtectionEnabled,
      'restrictedInteractionsEnabled': state.restrictedInteractionsEnabled,
      'mutedUsersHiddenFromFeed': state.mutedUsersHiddenFromFeed,
      'hideRestrictedUsersComments': state.hideRestrictedUsersComments,
      'appAppearanceMode': state.appAppearanceMode.name,
      'appAccentPreference': state.appAccentPreference.name,
      'appInterfaceDensity': state.appInterfaceDensity.name,
      'reduceMotionEnabled': state.reduceMotionEnabled,
      'highContrastModeEnabled': state.highContrastModeEnabled,
      'useSystemTextScale': state.useSystemTextScale,
      'showAppearancePreviewCards': state.showAppearancePreviewCards,
      'contactPermission': state.contactPermission.name,
      'connectionsVisibility': state.connectionsVisibility.name,
      'profilePostsVisibility': state.profilePostsVisibility.name,
      'profilePhotosVisibility': state.profilePhotosVisibility.name,
      'profileSearchVisibility': state.profileSearchVisibility.name,
      'profileTaggingPermission': state.profileTaggingPermission.name,
      'allowProfileScreenshotWarning': state.allowProfileScreenshotWarning,
      'allowProfileForwarding': state.allowProfileForwarding,
      'allowActivityStatusVisibility': state.allowActivityStatusVisibility,
      'allowMutualFriendsPreview': state.allowMutualFriendsPreview,
      'requireApprovalForProfileTags': state.requireApprovalForProfileTags,
    };
  }

  SettingsState _fromMap(Map<String, dynamic> data) {
    const fallback = SettingsState.initial();

    return SettingsState(
      isLoading: false,
      errorMessage: null,
      syncStatus: SettingsSyncStatus.synced,
      isProfilePrivate:
          _readBool(data, 'isProfilePrivate', fallback.isProfilePrivate),
      isProfileDiscoverable: _readBool(
        data,
        'isProfileDiscoverable',
        fallback.isProfileDiscoverable,
      ),
      showProfileInSuggestions: _readBool(
        data,
        'showProfileInSuggestions',
        fallback.showProfileInSuggestions,
      ),
      allowPublicProfilePreview: _readBool(
        data,
        'allowPublicProfilePreview',
        fallback.allowPublicProfilePreview,
      ),
      allowFriendRequests:
          _readBool(data, 'allowFriendRequests', fallback.allowFriendRequests),
      searchEngineIndexingEnabled: _readBool(
        data,
        'searchEngineIndexingEnabled',
        fallback.searchEngineIndexingEnabled,
      ),
      twoFactorEnabled:
          _readBool(data, 'twoFactorEnabled', fallback.twoFactorEnabled),
      loginAlertsEnabled:
          _readBool(data, 'loginAlertsEnabled', fallback.loginAlertsEnabled),
      phoneNumber: _readNullableString(data['phoneNumber']),
      isPhoneNumberVerified: _readBool(
        data,
        'isPhoneNumberVerified',
        fallback.isPhoneNumberVerified,
      ),
      phoneNumberVerifiedAt: _readDateTime(data['phoneNumberVerifiedAt']),
      phoneNumberUpdatedAt: _readDateTime(data['phoneNumberUpdatedAt']),
      twoFactorMethod: _readEnum(
        data['twoFactorMethod'],
        TwoFactorMethod.values,
        fallback.twoFactorMethod,
      ),
      backupCodesGenerated: _readBool(
        data,
        'backupCodesGenerated',
        fallback.backupCodesGenerated,
      ),
      backupCodesGeneratedAt: _readDateTime(data['backupCodesGeneratedAt']),
      securityDeviceSummary: _readSecurityDeviceSummary(
        data['securityDeviceSummary'],
        fallback.securityDeviceSummary,
      ),
      securityTimelineSummary: _readSecurityTimelineSummary(
        data['securityTimelineSummary'],
        fallback.securityTimelineSummary,
      ),
      trustedDevicesEnabled: _readBool(
        data,
        'trustedDevicesEnabled',
        fallback.trustedDevicesEnabled,
      ),
      deviceHistoryEnabled: _readBool(
        data,
        'deviceHistoryEnabled',
        fallback.deviceHistoryEnabled,
      ),
      suspiciousLoginProtectionEnabled: _readBool(
        data,
        'suspiciousLoginProtectionEnabled',
        fallback.suspiciousLoginProtectionEnabled,
      ),
      sessionRevocationPrepared: _readBool(
        data,
        'sessionRevocationPrepared',
        fallback.sessionRevocationPrepared,
      ),
      remoteLogoutPrepared: _readBool(
        data,
        'remoteLogoutPrepared',
        fallback.remoteLogoutPrepared,
      ),
      securityAuditTrailEnabled: _readBool(
        data,
        'securityAuditTrailEnabled',
        fallback.securityAuditTrailEnabled,
      ),
      pushNotificationsEnabled: _readBool(
        data,
        'pushNotificationsEnabled',
        fallback.pushNotificationsEnabled,
      ),
      inAppNotificationsEnabled: _readBool(
        data,
        'inAppNotificationsEnabled',
        fallback.inAppNotificationsEnabled,
      ),
      commentNotificationsEnabled: _readBool(
        data,
        'commentNotificationsEnabled',
        fallback.commentNotificationsEnabled,
      ),
      likeNotificationsEnabled: _readBool(
        data,
        'likeNotificationsEnabled',
        fallback.likeNotificationsEnabled,
      ),
      replyNotificationsEnabled: _readBool(
        data,
        'replyNotificationsEnabled',
        fallback.replyNotificationsEnabled,
      ),
      friendRequestNotificationsEnabled: _readBool(
        data,
        'friendRequestNotificationsEnabled',
        fallback.friendRequestNotificationsEnabled,
      ),
      messageNotificationsEnabled: _readBool(
        data,
        'messageNotificationsEnabled',
        fallback.messageNotificationsEnabled,
      ),
      mentionNotificationsEnabled: _readBool(
        data,
        'mentionNotificationsEnabled',
        fallback.mentionNotificationsEnabled,
      ),
      quietModeEnabled:
          _readBool(data, 'quietModeEnabled', fallback.quietModeEnabled),
      dailySummaryEnabled:
          _readBool(data, 'dailySummaryEnabled', fallback.dailySummaryEnabled),
      securityNotificationsEnabled: _readBool(
        data,
        'securityNotificationsEnabled',
        fallback.securityNotificationsEnabled,
      ),
      systemUpdateNotificationsEnabled: _readBool(
        data,
        'systemUpdateNotificationsEnabled',
        fallback.systemUpdateNotificationsEnabled,
      ),
      adminSecurityPriorityNotificationsEnabled: _readBool(
        data,
        'adminSecurityPriorityNotificationsEnabled',
        fallback.adminSecurityPriorityNotificationsEnabled,
      ),
      moderationNotificationsEnabled: _readBool(
        data,
        'moderationNotificationsEnabled',
        fallback.moderationNotificationsEnabled,
      ),
      notificationHistoryEnabled: _readBool(
        data,
        'notificationHistoryEnabled',
        fallback.notificationHistoryEnabled,
      ),
      notificationGroupingEnabled: _readBool(
        data,
        'notificationGroupingEnabled',
        fallback.notificationGroupingEnabled,
      ),
      quietModeAllowSecurityAlerts: _readBool(
        data,
        'quietModeAllowSecurityAlerts',
        fallback.quietModeAllowSecurityAlerts,
      ),
      notificationPriorityMode: _readEnum(
        data['notificationPriorityMode'],
        NotificationPriorityMode.values,
        fallback.notificationPriorityMode,
      ),
      digestDeliveryMode: _readEnum(
        data['digestDeliveryMode'],
        DigestDeliveryMode.values,
        fallback.digestDeliveryMode,
      ),
      notificationGroupingMode: _readEnum(
        data['notificationGroupingMode'],
        NotificationGroupingMode.values,
        fallback.notificationGroupingMode,
      ),
      blockedUsersProtectionEnabled: _readBool(
        data,
        'blockedUsersProtectionEnabled',
        fallback.blockedUsersProtectionEnabled,
      ),
      restrictedInteractionsEnabled: _readBool(
        data,
        'restrictedInteractionsEnabled',
        fallback.restrictedInteractionsEnabled,
      ),
      mutedUsersHiddenFromFeed: _readBool(
        data,
        'mutedUsersHiddenFromFeed',
        fallback.mutedUsersHiddenFromFeed,
      ),
      hideRestrictedUsersComments: _readBool(
        data,
        'hideRestrictedUsersComments',
        fallback.hideRestrictedUsersComments,
      ),
      appAppearanceMode: _readEnum(
        data['appAppearanceMode'],
        AppAppearanceMode.values,
        fallback.appAppearanceMode,
      ),
      appAccentPreference: _readEnum(
        data['appAccentPreference'],
        AppAccentPreference.values,
        fallback.appAccentPreference,
      ),
      appInterfaceDensity: _readEnum(
        data['appInterfaceDensity'],
        AppInterfaceDensity.values,
        fallback.appInterfaceDensity,
      ),
      reduceMotionEnabled: _readBool(
        data,
        'reduceMotionEnabled',
        fallback.reduceMotionEnabled,
      ),
      highContrastModeEnabled: _readBool(
        data,
        'highContrastModeEnabled',
        fallback.highContrastModeEnabled,
      ),
      useSystemTextScale:
          _readBool(data, 'useSystemTextScale', fallback.useSystemTextScale),
      showAppearancePreviewCards: _readBool(
        data,
        'showAppearancePreviewCards',
        fallback.showAppearancePreviewCards,
      ),
      contactPermission: _readEnum(
        data['contactPermission'],
        ContactPermission.values,
        fallback.contactPermission,
      ),
      connectionsVisibility: _readEnum(
        data['connectionsVisibility'],
        ConnectionsVisibility.values,
        fallback.connectionsVisibility,
      ),
      profilePostsVisibility: _readEnum(
        data['profilePostsVisibility'],
        ProfileContentVisibility.values,
        fallback.profilePostsVisibility,
      ),
      profilePhotosVisibility: _readEnum(
        data['profilePhotosVisibility'],
        ProfileContentVisibility.values,
        fallback.profilePhotosVisibility,
      ),
      profileSearchVisibility: _readEnum(
        data['profileSearchVisibility'],
        ProfileSearchVisibility.values,
        fallback.profileSearchVisibility,
      ),
      profileTaggingPermission: _readEnum(
        data['profileTaggingPermission'],
        ProfileTaggingPermission.values,
        fallback.profileTaggingPermission,
      ),
      allowProfileScreenshotWarning: _readBool(
        data,
        'allowProfileScreenshotWarning',
        fallback.allowProfileScreenshotWarning,
      ),
      allowProfileForwarding: _readBool(
        data,
        'allowProfileForwarding',
        fallback.allowProfileForwarding,
      ),
      allowActivityStatusVisibility: _readBool(
        data,
        'allowActivityStatusVisibility',
        fallback.allowActivityStatusVisibility,
      ),
      allowMutualFriendsPreview: _readBool(
        data,
        'allowMutualFriendsPreview',
        fallback.allowMutualFriendsPreview,
      ),
      requireApprovalForProfileTags: _readBool(
        data,
        'requireApprovalForProfileTags',
        fallback.requireApprovalForProfileTags,
      ),
    );
  }

  Map<String, Object?> _securityDeviceSummaryToMap(
    SecurityDeviceSummary summary,
  ) {
    return <String, Object?>{
      'trustedDeviceCount': summary.trustedDeviceCount,
      'activeSessionCount': summary.activeSessionCount,
      'lastDeviceActivityAt': _dateTimeToTimestamp(
        summary.lastDeviceActivityAt,
      ),
    };
  }

  Map<String, Object?> _securityTimelineSummaryToMap(
    SecurityTimelineSummary summary,
  ) {
    return <String, Object?>{
      'lastSuccessfulLoginAt': _dateTimeToTimestamp(
        summary.lastSuccessfulLoginAt,
      ),
      'lastPasswordChangedAt': _dateTimeToTimestamp(
        summary.lastPasswordChangedAt,
      ),
      'lastSecurityEventAt': _dateTimeToTimestamp(
        summary.lastSecurityEventAt,
      ),
      'unreadSecurityEventCount': summary.unreadSecurityEventCount,
    };
  }

  SecurityDeviceSummary _readSecurityDeviceSummary(
    Object? value,
    SecurityDeviceSummary fallback,
  ) {
    if (value is! Map) {
      return fallback;
    }

    final data = value.cast<String, Object?>();

    return SecurityDeviceSummary(
      trustedDeviceCount: _readInt(
        data['trustedDeviceCount'],
        fallback.trustedDeviceCount,
      ),
      activeSessionCount: _readInt(
        data['activeSessionCount'],
        fallback.activeSessionCount,
      ),
      lastDeviceActivityAt: _readDateTime(data['lastDeviceActivityAt']),
    );
  }

  SecurityTimelineSummary _readSecurityTimelineSummary(
    Object? value,
    SecurityTimelineSummary fallback,
  ) {
    if (value is! Map) {
      return fallback;
    }

    final data = value.cast<String, Object?>();

    return SecurityTimelineSummary(
      lastSuccessfulLoginAt: _readDateTime(data['lastSuccessfulLoginAt']),
      lastPasswordChangedAt: _readDateTime(data['lastPasswordChangedAt']),
      lastSecurityEventAt: _readDateTime(data['lastSecurityEventAt']),
      unreadSecurityEventCount: _readInt(
        data['unreadSecurityEventCount'],
        fallback.unreadSecurityEventCount,
      ),
    );
  }

  bool _readBool(
    Map<String, dynamic> data,
    String key,
    bool fallback,
  ) {
    final value = data[key];
    return value is bool ? value : fallback;
  }

  int _readInt(
    Object? value,
    int fallback,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return fallback;
  }

  T _readEnum<T extends Enum>(
    Object? rawValue,
    List<T> values,
    T fallback,
  ) {
    if (rawValue is! String) return fallback;

    for (final value in values) {
      if (value.name == rawValue) return value;
    }

    return fallback;
  }

  String? _readNullableString(Object? value) {
    if (value is! String) return null;

    final cleanedValue = value.trim();

    if (cleanedValue.isEmpty) {
      return null;
    }

    return cleanedValue;
  }

  Timestamp? _dateTimeToTimestamp(DateTime? value) {
    if (value == null) {
      return null;
    }

    return Timestamp.fromDate(value);
  }

  DateTime? _readDateTime(Object? value) {
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
