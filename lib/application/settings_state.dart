import 'package:flutter/foundation.dart';

enum ContactPermission { nobody, friendsOnly, everyone }

enum ConnectionsVisibility { onlyMe, friendsOnly, everyone }

enum ProfileContentVisibility { onlyMe, friendsOnly, friendsOfFriends, everyone }

enum ProfileSearchVisibility { hidden, friendsOnly, platform }

enum ProfileTaggingPermission { nobody, friendsOnly, everyone }

enum NotificationPriorityMode { calm, balanced, importantOnly }

enum DigestDeliveryMode { off, daily, importantOnly }

enum NotificationGroupingMode { none, byType, smart }

enum AppAppearanceMode { system, dark, light }

enum AppAccentPreference { lumaOrange, warmGold, graphite }

enum AppInterfaceDensity { comfortable, compact }

enum TwoFactorMethod { none, sms, authenticator }

@immutable
class SecurityDeviceSummary {
  final int trustedDeviceCount;
  final int activeSessionCount;
  final DateTime? lastDeviceActivityAt;

  const SecurityDeviceSummary({
    this.trustedDeviceCount = 0,
    this.activeSessionCount = 1,
    this.lastDeviceActivityAt,
  });

  SecurityDeviceSummary copyWith({
    int? trustedDeviceCount,
    int? activeSessionCount,
    DateTime? lastDeviceActivityAt,
    bool clearLastDeviceActivityAt = false,
  }) {
    return SecurityDeviceSummary(
      trustedDeviceCount: trustedDeviceCount ?? this.trustedDeviceCount,
      activeSessionCount: activeSessionCount ?? this.activeSessionCount,
      lastDeviceActivityAt: clearLastDeviceActivityAt
          ? null
          : (lastDeviceActivityAt ?? this.lastDeviceActivityAt),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SecurityDeviceSummary &&
        other.trustedDeviceCount == trustedDeviceCount &&
        other.activeSessionCount == activeSessionCount &&
        other.lastDeviceActivityAt == lastDeviceActivityAt;
  }

  @override
  int get hashCode => Object.hash(
        trustedDeviceCount,
        activeSessionCount,
        lastDeviceActivityAt,
      );
}

@immutable
class SecurityTimelineSummary {
  final DateTime? lastSuccessfulLoginAt;
  final DateTime? lastPasswordChangedAt;
  final DateTime? lastSecurityEventAt;
  final int unreadSecurityEventCount;

  const SecurityTimelineSummary({
    this.lastSuccessfulLoginAt,
    this.lastPasswordChangedAt,
    this.lastSecurityEventAt,
    this.unreadSecurityEventCount = 0,
  });

  SecurityTimelineSummary copyWith({
    DateTime? lastSuccessfulLoginAt,
    DateTime? lastPasswordChangedAt,
    DateTime? lastSecurityEventAt,
    int? unreadSecurityEventCount,
    bool clearLastSuccessfulLoginAt = false,
    bool clearLastPasswordChangedAt = false,
    bool clearLastSecurityEventAt = false,
  }) {
    return SecurityTimelineSummary(
      lastSuccessfulLoginAt: clearLastSuccessfulLoginAt
          ? null
          : (lastSuccessfulLoginAt ?? this.lastSuccessfulLoginAt),
      lastPasswordChangedAt: clearLastPasswordChangedAt
          ? null
          : (lastPasswordChangedAt ?? this.lastPasswordChangedAt),
      lastSecurityEventAt: clearLastSecurityEventAt
          ? null
          : (lastSecurityEventAt ?? this.lastSecurityEventAt),
      unreadSecurityEventCount:
          unreadSecurityEventCount ?? this.unreadSecurityEventCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SecurityTimelineSummary &&
        other.lastSuccessfulLoginAt == lastSuccessfulLoginAt &&
        other.lastPasswordChangedAt == lastPasswordChangedAt &&
        other.lastSecurityEventAt == lastSecurityEventAt &&
        other.unreadSecurityEventCount == unreadSecurityEventCount;
  }

  @override
  int get hashCode => Object.hash(
        lastSuccessfulLoginAt,
        lastPasswordChangedAt,
        lastSecurityEventAt,
        unreadSecurityEventCount,
      );
}

enum SettingsSyncStatus {
  localOnly,
  syncing,
  synced,
  pending,
  failed,
}

@immutable
class SettingsState {
  final bool isLoading;
  final String? errorMessage;
  final SettingsSyncStatus syncStatus;
  final Set<String> dirtyFieldKeys;

  final bool isProfilePrivate;
  final bool isProfileDiscoverable;
  final bool showProfileInSuggestions;
  final bool allowPublicProfilePreview;
  final bool allowFriendRequests;
  final bool searchEngineIndexingEnabled;
  final bool twoFactorEnabled;
  final bool loginAlertsEnabled;
  final String? phoneNumber;
  final bool isPhoneNumberVerified;
  final DateTime? phoneNumberVerifiedAt;
  final DateTime? phoneNumberUpdatedAt;
  final TwoFactorMethod twoFactorMethod;
  final bool backupCodesGenerated;
  final DateTime? backupCodesGeneratedAt;
  final SecurityDeviceSummary securityDeviceSummary;
  final SecurityTimelineSummary securityTimelineSummary;

  final bool trustedDevicesEnabled;
  final bool deviceHistoryEnabled;
  final bool suspiciousLoginProtectionEnabled;
  final bool sessionRevocationPrepared;
  final bool remoteLogoutPrepared;
  final bool securityAuditTrailEnabled;

  final bool pushNotificationsEnabled;
  final bool inAppNotificationsEnabled;
  final bool commentNotificationsEnabled;
  final bool likeNotificationsEnabled;
  final bool replyNotificationsEnabled;
  final bool friendRequestNotificationsEnabled;
  final bool messageNotificationsEnabled;
  final bool mentionNotificationsEnabled;
  final bool quietModeEnabled;
  final bool dailySummaryEnabled;
  final bool securityNotificationsEnabled;
  final bool systemUpdateNotificationsEnabled;

  final bool adminSecurityPriorityNotificationsEnabled;
  final bool moderationNotificationsEnabled;
  final bool notificationHistoryEnabled;
  final bool notificationGroupingEnabled;
  final bool quietModeAllowSecurityAlerts;
  final NotificationPriorityMode notificationPriorityMode;
  final DigestDeliveryMode digestDeliveryMode;
  final NotificationGroupingMode notificationGroupingMode;

  final bool blockedUsersProtectionEnabled;
  final bool restrictedInteractionsEnabled;
  final bool mutedUsersHiddenFromFeed;
  final bool hideRestrictedUsersComments;

  final AppAppearanceMode appAppearanceMode;
  final AppAccentPreference appAccentPreference;
  final AppInterfaceDensity appInterfaceDensity;
  final bool reduceMotionEnabled;
  final bool highContrastModeEnabled;
  final bool useSystemTextScale;
  final bool showAppearancePreviewCards;

  final ContactPermission contactPermission;
  final ConnectionsVisibility connectionsVisibility;
  final ProfileContentVisibility profilePostsVisibility;
  final ProfileContentVisibility profilePhotosVisibility;
  final ProfileSearchVisibility profileSearchVisibility;
  final ProfileTaggingPermission profileTaggingPermission;

  final bool allowProfileScreenshotWarning;
  final bool allowProfileForwarding;
  final bool allowActivityStatusVisibility;
  final bool allowMutualFriendsPreview;
  final bool requireApprovalForProfileTags;

  const SettingsState({
    required this.isLoading,
    required this.errorMessage,
    required this.syncStatus,
    this.dirtyFieldKeys = const <String>{},
    required this.isProfilePrivate,
    required this.isProfileDiscoverable,
    required this.showProfileInSuggestions,
    required this.allowPublicProfilePreview,
    required this.allowFriendRequests,
    required this.searchEngineIndexingEnabled,
    required this.twoFactorEnabled,
    required this.loginAlertsEnabled,
    this.phoneNumber,
    this.isPhoneNumberVerified = false,
    this.phoneNumberVerifiedAt,
    this.phoneNumberUpdatedAt,
    this.twoFactorMethod = TwoFactorMethod.none,
    this.backupCodesGenerated = false,
    this.backupCodesGeneratedAt,
    this.securityDeviceSummary = const SecurityDeviceSummary(),
    this.securityTimelineSummary = const SecurityTimelineSummary(),
    required this.trustedDevicesEnabled,
    required this.deviceHistoryEnabled,
    required this.suspiciousLoginProtectionEnabled,
    required this.sessionRevocationPrepared,
    required this.remoteLogoutPrepared,
    required this.securityAuditTrailEnabled,
    required this.pushNotificationsEnabled,
    required this.inAppNotificationsEnabled,
    required this.commentNotificationsEnabled,
    required this.likeNotificationsEnabled,
    required this.replyNotificationsEnabled,
    required this.friendRequestNotificationsEnabled,
    required this.messageNotificationsEnabled,
    required this.mentionNotificationsEnabled,
    required this.quietModeEnabled,
    required this.dailySummaryEnabled,
    required this.securityNotificationsEnabled,
    required this.systemUpdateNotificationsEnabled,
    required this.adminSecurityPriorityNotificationsEnabled,
    required this.moderationNotificationsEnabled,
    required this.notificationHistoryEnabled,
    required this.notificationGroupingEnabled,
    required this.quietModeAllowSecurityAlerts,
    required this.notificationPriorityMode,
    required this.digestDeliveryMode,
    required this.notificationGroupingMode,
    required this.blockedUsersProtectionEnabled,
    required this.restrictedInteractionsEnabled,
    required this.mutedUsersHiddenFromFeed,
    required this.hideRestrictedUsersComments,
    required this.appAppearanceMode,
    required this.appAccentPreference,
    required this.appInterfaceDensity,
    required this.reduceMotionEnabled,
    required this.highContrastModeEnabled,
    required this.useSystemTextScale,
    required this.showAppearancePreviewCards,
    required this.contactPermission,
    required this.connectionsVisibility,
    required this.profilePostsVisibility,
    required this.profilePhotosVisibility,
    required this.profileSearchVisibility,
    required this.profileTaggingPermission,
    required this.allowProfileScreenshotWarning,
    required this.allowProfileForwarding,
    required this.allowActivityStatusVisibility,
    required this.allowMutualFriendsPreview,
    required this.requireApprovalForProfileTags,
  });

  const SettingsState.initial()
      : isLoading = false,
        errorMessage = null,
        syncStatus = SettingsSyncStatus.localOnly,
        dirtyFieldKeys = const <String>{},
        isProfilePrivate = true,
        isProfileDiscoverable = true,
        showProfileInSuggestions = true,
        allowPublicProfilePreview = true,
        allowFriendRequests = true,
        searchEngineIndexingEnabled = false,
        twoFactorEnabled = false,
        loginAlertsEnabled = true,
        phoneNumber = null,
        isPhoneNumberVerified = false,
        phoneNumberVerifiedAt = null,
        phoneNumberUpdatedAt = null,
        twoFactorMethod = TwoFactorMethod.none,
        backupCodesGenerated = false,
        backupCodesGeneratedAt = null,
        securityDeviceSummary = const SecurityDeviceSummary(),
        securityTimelineSummary = const SecurityTimelineSummary(),
        trustedDevicesEnabled = true,
        deviceHistoryEnabled = true,
        suspiciousLoginProtectionEnabled = true,
        sessionRevocationPrepared = true,
        remoteLogoutPrepared = true,
        securityAuditTrailEnabled = true,
        pushNotificationsEnabled = true,
        inAppNotificationsEnabled = true,
        commentNotificationsEnabled = true,
        likeNotificationsEnabled = false,
        replyNotificationsEnabled = true,
        friendRequestNotificationsEnabled = true,
        messageNotificationsEnabled = true,
        mentionNotificationsEnabled = true,
        quietModeEnabled = false,
        dailySummaryEnabled = true,
        securityNotificationsEnabled = true,
        systemUpdateNotificationsEnabled = true,
        adminSecurityPriorityNotificationsEnabled = true,
        moderationNotificationsEnabled = true,
        notificationHistoryEnabled = true,
        notificationGroupingEnabled = true,
        quietModeAllowSecurityAlerts = true,
        notificationPriorityMode = NotificationPriorityMode.balanced,
        digestDeliveryMode = DigestDeliveryMode.daily,
        notificationGroupingMode = NotificationGroupingMode.smart,
        blockedUsersProtectionEnabled = true,
        restrictedInteractionsEnabled = true,
        mutedUsersHiddenFromFeed = true,
        hideRestrictedUsersComments = true,
        appAppearanceMode = AppAppearanceMode.system,
        appAccentPreference = AppAccentPreference.lumaOrange,
        appInterfaceDensity = AppInterfaceDensity.comfortable,
        reduceMotionEnabled = false,
        highContrastModeEnabled = false,
        useSystemTextScale = true,
        showAppearancePreviewCards = true,
        contactPermission = ContactPermission.friendsOnly,
        connectionsVisibility = ConnectionsVisibility.onlyMe,
        profilePostsVisibility = ProfileContentVisibility.friendsOnly,
        profilePhotosVisibility = ProfileContentVisibility.friendsOnly,
        profileSearchVisibility = ProfileSearchVisibility.platform,
        profileTaggingPermission = ProfileTaggingPermission.friendsOnly,
        allowProfileScreenshotWarning = true,
        allowProfileForwarding = false,
        allowActivityStatusVisibility = false,
        allowMutualFriendsPreview = true,
        requireApprovalForProfileTags = true;

  bool get hasDirtyFields => dirtyFieldKeys.isNotEmpty;

  bool isFieldDirty(String fieldKey) => dirtyFieldKeys.contains(fieldKey);

  bool get hasPhoneNumber => phoneNumber != null && phoneNumber!.trim().isNotEmpty;

  bool get hasVerifiedPhoneNumber => hasPhoneNumber && isPhoneNumberVerified;

  bool get hasConfiguredTwoFactor =>
      twoFactorEnabled && twoFactorMethod != TwoFactorMethod.none;

  bool get hasRecoverableSecuritySetup =>
      hasVerifiedPhoneNumber && hasConfiguredTwoFactor && backupCodesGenerated;

  bool get hasSecurityTimelineSignals =>
      securityTimelineSummary.lastSuccessfulLoginAt != null ||
      securityTimelineSummary.lastPasswordChangedAt != null ||
      securityTimelineSummary.lastSecurityEventAt != null ||
      securityTimelineSummary.unreadSecurityEventCount > 0;

  bool get showFriendsList => connectionsVisibility != ConnectionsVisibility.onlyMe;

  bool get allowDirectMessagesFromEveryone =>
      contactPermission == ContactPermission.everyone;

  bool get hasSessionProtectionPrepared =>
      trustedDevicesEnabled ||
      deviceHistoryEnabled ||
      suspiciousLoginProtectionEnabled ||
      sessionRevocationPrepared ||
      remoteLogoutPrepared ||
      securityAuditTrailEnabled;

  bool get hasStrongSessionProtection =>
      trustedDevicesEnabled &&
      deviceHistoryEnabled &&
      suspiciousLoginProtectionEnabled &&
      sessionRevocationPrepared &&
      remoteLogoutPrepared &&
      securityAuditTrailEnabled;

  bool get isStrictPrivateProfile =>
      isProfilePrivate &&
      !allowPublicProfilePreview &&
      !allowProfileForwarding &&
      profilePostsVisibility == ProfileContentVisibility.friendsOnly &&
      profilePhotosVisibility == ProfileContentVisibility.friendsOnly;

  bool get hasAnyNotificationEnabled =>
      pushNotificationsEnabled ||
      inAppNotificationsEnabled ||
      commentNotificationsEnabled ||
      likeNotificationsEnabled ||
      replyNotificationsEnabled ||
      friendRequestNotificationsEnabled ||
      messageNotificationsEnabled ||
      mentionNotificationsEnabled ||
      dailySummaryEnabled ||
      securityNotificationsEnabled ||
      systemUpdateNotificationsEnabled ||
      adminSecurityPriorityNotificationsEnabled ||
      moderationNotificationsEnabled;

  bool get hasImportantNotificationsEnabled =>
      friendRequestNotificationsEnabled ||
      messageNotificationsEnabled ||
      mentionNotificationsEnabled ||
      replyNotificationsEnabled ||
      securityNotificationsEnabled ||
      adminSecurityPriorityNotificationsEnabled ||
      moderationNotificationsEnabled;

  bool get hasSocialNotificationsEnabled =>
      commentNotificationsEnabled ||
      likeNotificationsEnabled ||
      replyNotificationsEnabled ||
      mentionNotificationsEnabled;

  bool get hasDirectContactNotificationsEnabled =>
      friendRequestNotificationsEnabled || messageNotificationsEnabled;

  bool get hasCriticalNotificationChannel =>
      securityNotificationsEnabled ||
      adminSecurityPriorityNotificationsEnabled ||
      moderationNotificationsEnabled;

  bool get isNotificationSystemCalm =>
      notificationPriorityMode == NotificationPriorityMode.calm &&
      digestDeliveryMode != DigestDeliveryMode.off &&
      notificationGroupingMode == NotificationGroupingMode.smart;

  bool get hasProtectionControlsEnabled =>
      blockedUsersProtectionEnabled ||
      restrictedInteractionsEnabled ||
      mutedUsersHiddenFromFeed ||
      hideRestrictedUsersComments;

  bool get hasOpenVisibility =>
      isProfileDiscoverable ||
      showProfileInSuggestions ||
      allowPublicProfilePreview ||
      searchEngineIndexingEnabled ||
      profileSearchVisibility == ProfileSearchVisibility.platform;

  bool get hasRestrictedVisibility =>
      !isProfileDiscoverable &&
      !showProfileInSuggestions &&
      !allowPublicProfilePreview &&
      !searchEngineIndexingEnabled &&
      profileSearchVisibility == ProfileSearchVisibility.hidden;

  bool get usesDefaultAppearance =>
      appAppearanceMode == AppAppearanceMode.system &&
      appAccentPreference == AppAccentPreference.lumaOrange &&
      appInterfaceDensity == AppInterfaceDensity.comfortable &&
      !reduceMotionEnabled &&
      !highContrastModeEnabled &&
      useSystemTextScale &&
      showAppearancePreviewCards;

  bool get isSyncedWithFirebase => syncStatus == SettingsSyncStatus.synced;

  bool get hasPendingSync => syncStatus == SettingsSyncStatus.pending;

  bool get hasFailedSync => syncStatus == SettingsSyncStatus.failed;

  bool get isSyncing => syncStatus == SettingsSyncStatus.syncing;

  SettingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    SettingsSyncStatus? syncStatus,
    Set<String>? dirtyFieldKeys,
    bool clearDirtyFieldKeys = false,
    bool? isProfilePrivate,
    bool? isProfileDiscoverable,
    bool? showProfileInSuggestions,
    bool? allowPublicProfilePreview,
    bool? allowFriendRequests,
    bool? searchEngineIndexingEnabled,
    bool? twoFactorEnabled,
    bool? loginAlertsEnabled,
    String? phoneNumber,
    bool clearPhoneNumber = false,
    bool? isPhoneNumberVerified,
    DateTime? phoneNumberVerifiedAt,
    bool clearPhoneNumberVerifiedAt = false,
    DateTime? phoneNumberUpdatedAt,
    bool clearPhoneNumberUpdatedAt = false,
    TwoFactorMethod? twoFactorMethod,
    bool? backupCodesGenerated,
    DateTime? backupCodesGeneratedAt,
    bool clearBackupCodesGeneratedAt = false,
    SecurityDeviceSummary? securityDeviceSummary,
    SecurityTimelineSummary? securityTimelineSummary,
    bool? trustedDevicesEnabled,
    bool? deviceHistoryEnabled,
    bool? suspiciousLoginProtectionEnabled,
    bool? sessionRevocationPrepared,
    bool? remoteLogoutPrepared,
    bool? securityAuditTrailEnabled,
    bool? pushNotificationsEnabled,
    bool? inAppNotificationsEnabled,
    bool? commentNotificationsEnabled,
    bool? likeNotificationsEnabled,
    bool? replyNotificationsEnabled,
    bool? friendRequestNotificationsEnabled,
    bool? messageNotificationsEnabled,
    bool? mentionNotificationsEnabled,
    bool? quietModeEnabled,
    bool? dailySummaryEnabled,
    bool? securityNotificationsEnabled,
    bool? systemUpdateNotificationsEnabled,
    bool? adminSecurityPriorityNotificationsEnabled,
    bool? moderationNotificationsEnabled,
    bool? notificationHistoryEnabled,
    bool? notificationGroupingEnabled,
    bool? quietModeAllowSecurityAlerts,
    NotificationPriorityMode? notificationPriorityMode,
    DigestDeliveryMode? digestDeliveryMode,
    NotificationGroupingMode? notificationGroupingMode,
    bool? blockedUsersProtectionEnabled,
    bool? restrictedInteractionsEnabled,
    bool? mutedUsersHiddenFromFeed,
    bool? hideRestrictedUsersComments,
    AppAppearanceMode? appAppearanceMode,
    AppAccentPreference? appAccentPreference,
    AppInterfaceDensity? appInterfaceDensity,
    bool? reduceMotionEnabled,
    bool? highContrastModeEnabled,
    bool? useSystemTextScale,
    bool? showAppearancePreviewCards,
    ContactPermission? contactPermission,
    ConnectionsVisibility? connectionsVisibility,
    ProfileContentVisibility? profilePostsVisibility,
    ProfileContentVisibility? profilePhotosVisibility,
    ProfileSearchVisibility? profileSearchVisibility,
    ProfileTaggingPermission? profileTaggingPermission,
    bool? allowProfileScreenshotWarning,
    bool? allowProfileForwarding,
    bool? allowActivityStatusVisibility,
    bool? allowMutualFriendsPreview,
    bool? requireApprovalForProfileTags,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      syncStatus: syncStatus ?? this.syncStatus,
      dirtyFieldKeys: clearDirtyFieldKeys
          ? const <String>{}
          : Set<String>.unmodifiable(dirtyFieldKeys ?? this.dirtyFieldKeys),
      isProfilePrivate: isProfilePrivate ?? this.isProfilePrivate,
      isProfileDiscoverable: isProfileDiscoverable ?? this.isProfileDiscoverable,
      showProfileInSuggestions: showProfileInSuggestions ?? this.showProfileInSuggestions,
      allowPublicProfilePreview: allowPublicProfilePreview ?? this.allowPublicProfilePreview,
      allowFriendRequests: allowFriendRequests ?? this.allowFriendRequests,
      searchEngineIndexingEnabled:
          searchEngineIndexingEnabled ?? this.searchEngineIndexingEnabled,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      loginAlertsEnabled: loginAlertsEnabled ?? this.loginAlertsEnabled,
      phoneNumber: clearPhoneNumber ? null : (phoneNumber ?? this.phoneNumber),
      isPhoneNumberVerified:
          isPhoneNumberVerified ?? this.isPhoneNumberVerified,
      phoneNumberVerifiedAt: clearPhoneNumberVerifiedAt
          ? null
          : (phoneNumberVerifiedAt ?? this.phoneNumberVerifiedAt),
      phoneNumberUpdatedAt: clearPhoneNumberUpdatedAt
          ? null
          : (phoneNumberUpdatedAt ?? this.phoneNumberUpdatedAt),
      twoFactorMethod: twoFactorMethod ?? this.twoFactorMethod,
      backupCodesGenerated:
          backupCodesGenerated ?? this.backupCodesGenerated,
      backupCodesGeneratedAt: clearBackupCodesGeneratedAt
          ? null
          : (backupCodesGeneratedAt ?? this.backupCodesGeneratedAt),
      securityDeviceSummary:
          securityDeviceSummary ?? this.securityDeviceSummary,
      securityTimelineSummary:
          securityTimelineSummary ?? this.securityTimelineSummary,
      trustedDevicesEnabled: trustedDevicesEnabled ?? this.trustedDevicesEnabled,
      deviceHistoryEnabled: deviceHistoryEnabled ?? this.deviceHistoryEnabled,
      suspiciousLoginProtectionEnabled:
          suspiciousLoginProtectionEnabled ?? this.suspiciousLoginProtectionEnabled,
      sessionRevocationPrepared:
          sessionRevocationPrepared ?? this.sessionRevocationPrepared,
      remoteLogoutPrepared: remoteLogoutPrepared ?? this.remoteLogoutPrepared,
      securityAuditTrailEnabled:
          securityAuditTrailEnabled ?? this.securityAuditTrailEnabled,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      inAppNotificationsEnabled:
          inAppNotificationsEnabled ?? this.inAppNotificationsEnabled,
      commentNotificationsEnabled:
          commentNotificationsEnabled ?? this.commentNotificationsEnabled,
      likeNotificationsEnabled: likeNotificationsEnabled ?? this.likeNotificationsEnabled,
      replyNotificationsEnabled:
          replyNotificationsEnabled ?? this.replyNotificationsEnabled,
      friendRequestNotificationsEnabled:
          friendRequestNotificationsEnabled ?? this.friendRequestNotificationsEnabled,
      messageNotificationsEnabled:
          messageNotificationsEnabled ?? this.messageNotificationsEnabled,
      mentionNotificationsEnabled:
          mentionNotificationsEnabled ?? this.mentionNotificationsEnabled,
      quietModeEnabled: quietModeEnabled ?? this.quietModeEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      securityNotificationsEnabled:
          securityNotificationsEnabled ?? this.securityNotificationsEnabled,
      systemUpdateNotificationsEnabled:
          systemUpdateNotificationsEnabled ?? this.systemUpdateNotificationsEnabled,
      adminSecurityPriorityNotificationsEnabled:
          adminSecurityPriorityNotificationsEnabled ??
              this.adminSecurityPriorityNotificationsEnabled,
      moderationNotificationsEnabled:
          moderationNotificationsEnabled ?? this.moderationNotificationsEnabled,
      notificationHistoryEnabled:
          notificationHistoryEnabled ?? this.notificationHistoryEnabled,
      notificationGroupingEnabled:
          notificationGroupingEnabled ?? this.notificationGroupingEnabled,
      quietModeAllowSecurityAlerts:
          quietModeAllowSecurityAlerts ?? this.quietModeAllowSecurityAlerts,
      notificationPriorityMode:
          notificationPriorityMode ?? this.notificationPriorityMode,
      digestDeliveryMode: digestDeliveryMode ?? this.digestDeliveryMode,
      notificationGroupingMode:
          notificationGroupingMode ?? this.notificationGroupingMode,
      blockedUsersProtectionEnabled:
          blockedUsersProtectionEnabled ?? this.blockedUsersProtectionEnabled,
      restrictedInteractionsEnabled:
          restrictedInteractionsEnabled ?? this.restrictedInteractionsEnabled,
      mutedUsersHiddenFromFeed:
          mutedUsersHiddenFromFeed ?? this.mutedUsersHiddenFromFeed,
      hideRestrictedUsersComments:
          hideRestrictedUsersComments ?? this.hideRestrictedUsersComments,
      appAppearanceMode: appAppearanceMode ?? this.appAppearanceMode,
      appAccentPreference: appAccentPreference ?? this.appAccentPreference,
      appInterfaceDensity: appInterfaceDensity ?? this.appInterfaceDensity,
      reduceMotionEnabled: reduceMotionEnabled ?? this.reduceMotionEnabled,
      highContrastModeEnabled:
          highContrastModeEnabled ?? this.highContrastModeEnabled,
      useSystemTextScale: useSystemTextScale ?? this.useSystemTextScale,
      showAppearancePreviewCards:
          showAppearancePreviewCards ?? this.showAppearancePreviewCards,
      contactPermission: contactPermission ?? this.contactPermission,
      connectionsVisibility: connectionsVisibility ?? this.connectionsVisibility,
      profilePostsVisibility: profilePostsVisibility ?? this.profilePostsVisibility,
      profilePhotosVisibility: profilePhotosVisibility ?? this.profilePhotosVisibility,
      profileSearchVisibility: profileSearchVisibility ?? this.profileSearchVisibility,
      profileTaggingPermission:
          profileTaggingPermission ?? this.profileTaggingPermission,
      allowProfileScreenshotWarning:
          allowProfileScreenshotWarning ?? this.allowProfileScreenshotWarning,
      allowProfileForwarding:
          allowProfileForwarding ?? this.allowProfileForwarding,
      allowActivityStatusVisibility:
          allowActivityStatusVisibility ?? this.allowActivityStatusVisibility,
      allowMutualFriendsPreview:
          allowMutualFriendsPreview ?? this.allowMutualFriendsPreview,
      requireApprovalForProfileTags:
          requireApprovalForProfileTags ?? this.requireApprovalForProfileTags,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SettingsState && other.hashCode == hashCode;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      isLoading,
      errorMessage,
      syncStatus,
      Object.hashAll(dirtyFieldKeys.toList()..sort()),
      isProfilePrivate,
      isProfileDiscoverable,
      showProfileInSuggestions,
      allowPublicProfilePreview,
      allowFriendRequests,
      searchEngineIndexingEnabled,
      twoFactorEnabled,
      loginAlertsEnabled,
      phoneNumber,
      isPhoneNumberVerified,
      phoneNumberVerifiedAt,
      phoneNumberUpdatedAt,
      twoFactorMethod,
      backupCodesGenerated,
      backupCodesGeneratedAt,
      securityDeviceSummary,
      securityTimelineSummary,
      trustedDevicesEnabled,
      deviceHistoryEnabled,
      suspiciousLoginProtectionEnabled,
      sessionRevocationPrepared,
      remoteLogoutPrepared,
      securityAuditTrailEnabled,
      pushNotificationsEnabled,
      inAppNotificationsEnabled,
      commentNotificationsEnabled,
      likeNotificationsEnabled,
      replyNotificationsEnabled,
      friendRequestNotificationsEnabled,
      messageNotificationsEnabled,
      mentionNotificationsEnabled,
      quietModeEnabled,
      dailySummaryEnabled,
      securityNotificationsEnabled,
      systemUpdateNotificationsEnabled,
      adminSecurityPriorityNotificationsEnabled,
      moderationNotificationsEnabled,
      notificationHistoryEnabled,
      notificationGroupingEnabled,
      quietModeAllowSecurityAlerts,
      notificationPriorityMode,
      digestDeliveryMode,
      notificationGroupingMode,
      blockedUsersProtectionEnabled,
      restrictedInteractionsEnabled,
      mutedUsersHiddenFromFeed,
      hideRestrictedUsersComments,
      appAppearanceMode,
      appAccentPreference,
      appInterfaceDensity,
      reduceMotionEnabled,
      highContrastModeEnabled,
      useSystemTextScale,
      showAppearancePreviewCards,
      contactPermission,
      connectionsVisibility,
      profilePostsVisibility,
      profilePhotosVisibility,
      profileSearchVisibility,
      profileTaggingPermission,
      allowProfileScreenshotWarning,
      allowProfileForwarding,
      allowActivityStatusVisibility,
      allowMutualFriendsPreview,
      requireApprovalForProfileTags,
    ]);
  }
}