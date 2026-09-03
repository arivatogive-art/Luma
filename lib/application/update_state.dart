// Pfad: lib/application/update_state.dart

import 'package:flutter/foundation.dart';

enum LumaUpdateStatus {
  initial,
  checking,
  upToDate,
  softUpdateAvailable,
  hardUpdateRequired,
  pwaUpdateAvailable,
  installing,
  error,
}

enum LumaUpdateType {
  none,
  optional,
  recommended,
  required,
}

@immutable
class UpdateState {
  const UpdateState({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    required this.requiredVersion,
    required this.title,
    required this.message,
    required this.changelog,
    required this.downloadSizeLabel,
    required this.releaseDateLabel,
    required this.updateType,
    required this.canSkip,
    required this.isPwaUpdate,
    required this.isInstalling,
    required this.installProgress,
    required this.errorMessage,
    required this.lastCheckedAt,
    required this.storeUrl,
  });

  const UpdateState.initial()
      : status = LumaUpdateStatus.initial,
        currentVersion = '',
        latestVersion = '',
        requiredVersion = '',
        title = '',
        message = '',
        changelog = const <String>[],
        downloadSizeLabel = '',
        releaseDateLabel = '',
        updateType = LumaUpdateType.none,
        canSkip = true,
        isPwaUpdate = false,
        isInstalling = false,
        installProgress = 0,
        errorMessage = null,
        lastCheckedAt = null,
        storeUrl = '';

  final LumaUpdateStatus status;
  final String currentVersion;
  final String latestVersion;
  final String requiredVersion;
  final String title;
  final String message;
  final List<String> changelog;
  final String downloadSizeLabel;
  final String releaseDateLabel;
  final LumaUpdateType updateType;
  final bool canSkip;
  final bool isPwaUpdate;
  final bool isInstalling;
  final double installProgress;
  final String? errorMessage;
  final DateTime? lastCheckedAt;
  final String storeUrl;

  bool get isChecking => status == LumaUpdateStatus.checking;

  bool get hasVisibleUpdate =>
      status == LumaUpdateStatus.softUpdateAvailable ||
      status == LumaUpdateStatus.hardUpdateRequired ||
      status == LumaUpdateStatus.pwaUpdateAvailable ||
      status == LumaUpdateStatus.installing;

  bool get isBlockingUpdate =>
      status == LumaUpdateStatus.hardUpdateRequired ||
      (status == LumaUpdateStatus.pwaUpdateAvailable && !canSkip);

  bool get shouldBlockApp => isBlockingUpdate;

  bool get hasDownloadSize => downloadSizeLabel.trim().isNotEmpty;
  bool get hasReleaseDate => releaseDateLabel.trim().isNotEmpty;
  bool get hasChangelog => changelog.isNotEmpty;

  UpdateState copyWith({
    LumaUpdateStatus? status,
    String? currentVersion,
    String? latestVersion,
    String? requiredVersion,
    String? title,
    String? message,
    List<String>? changelog,
    String? downloadSizeLabel,
    String? releaseDateLabel,
    LumaUpdateType? updateType,
    bool? canSkip,
    bool? isPwaUpdate,
    bool? isInstalling,
    double? installProgress,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? lastCheckedAt,
    String? storeUrl,
  }) {
    return UpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      requiredVersion: requiredVersion ?? this.requiredVersion,
      title: title ?? this.title,
      message: message ?? this.message,
      changelog: changelog ?? this.changelog,
      downloadSizeLabel: downloadSizeLabel ?? this.downloadSizeLabel,
      releaseDateLabel: releaseDateLabel ?? this.releaseDateLabel,
      updateType: updateType ?? this.updateType,
      canSkip: canSkip ?? this.canSkip,
      isPwaUpdate: isPwaUpdate ?? this.isPwaUpdate,
      isInstalling: isInstalling ?? this.isInstalling,
      installProgress: installProgress ?? this.installProgress,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      storeUrl: storeUrl ?? this.storeUrl,
    );
  }
}

@immutable
class UpdateVersionInfo {
  const UpdateVersionInfo({
    required this.latestVersion,
    required this.requiredVersion,
    required this.title,
    required this.message,
    required this.changelog,
    required this.downloadSizeLabel,
    required this.releaseDateLabel,
    required this.updateType,
    required this.storeUrl,
    required this.isEnabled,
    required this.isHardUpdate,
  });

  factory UpdateVersionInfo.fallback() {
    return const UpdateVersionInfo(
      latestVersion: '1.0.0',
      requiredVersion: '1.0.0',
      title: 'Luma ist aktuell.',
      message: 'Du nutzt bereits die aktuelle Version von Luma.',
      changelog: <String>[],
      downloadSizeLabel: '',
      releaseDateLabel: '',
      updateType: LumaUpdateType.none,
      storeUrl: '',
      isEnabled: false,
      isHardUpdate: false,
    );
  }

  final String latestVersion;
  final String requiredVersion;
  final String title;
  final String message;
  final List<String> changelog;
  final String downloadSizeLabel;
  final String releaseDateLabel;
  final LumaUpdateType updateType;
  final String storeUrl;
  final bool isEnabled;
  final bool isHardUpdate;

  bool get hasStoreUrl => storeUrl.trim().isNotEmpty;
}
