// Pfad: lib/application/update_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/update_repository.dart';
import 'pwa_update_service.dart';
import 'update_state.dart';

class UpdateController extends ChangeNotifier {
  UpdateController({
    UpdateRepository? updateRepository,
    PwaUpdateService? pwaUpdateService,
  })  : _updateRepository = updateRepository ?? UpdateRepository(),
        _pwaUpdateService = pwaUpdateService ?? PwaUpdateService();

  final UpdateRepository _updateRepository;
  final PwaUpdateService _pwaUpdateService;

  UpdateState _state = const UpdateState.initial();
  StreamSubscription<bool>? _pwaUpdateSubscription;

  bool _isDisposed = false;
  bool _softUpdateDismissed = false;

  UpdateState get state => _state;

  Future<void> initialize() async {
    _setState(
      _state.copyWith(
        status: LumaUpdateStatus.checking,
        currentVersion: UpdateRepository.currentAppVersion,
        clearErrorMessage: true,
      ),
    );

    _pwaUpdateSubscription ??=
        _pwaUpdateService.updateAvailableStream.listen((available) {
      if (!available) return;
      unawaited(checkForVersionUpdate());
    });

    try {
      await _pwaUpdateService.initialize().timeout(const Duration(seconds: 4));
    } catch (error) {
      debugPrint('UpdateController PWA initialize error: $error');
    }

    await checkForVersionUpdate();
  }

  Future<void> checkForVersionUpdate() async {
    _setState(
      _state.copyWith(
        status: LumaUpdateStatus.checking,
        currentVersion: UpdateRepository.currentAppVersion,
        clearErrorMessage: true,
      ),
    );

    try {
      final versionInfo =
          await _updateRepository.fetchLatestVersionInfo().timeout(
                const Duration(seconds: 6),
              );

      final current = UpdateRepository.currentAppVersion;
      final hard = versionInfo.isEnabled &&
          (_compareVersions(current, versionInfo.requiredVersion) < 0 ||
              versionInfo.isHardUpdate ||
              versionInfo.updateType == LumaUpdateType.required);
      final soft = versionInfo.isEnabled &&
          _compareVersions(current, versionInfo.latestVersion) < 0;

      if (hard) {
        _setState(
          _state.copyWith(
            status: LumaUpdateStatus.hardUpdateRequired,
            currentVersion: current,
            latestVersion: versionInfo.latestVersion,
            requiredVersion: versionInfo.requiredVersion,
            title: versionInfo.title,
            message: versionInfo.message,
            changelog: versionInfo.changelog,
            downloadSizeLabel: versionInfo.downloadSizeLabel,
            releaseDateLabel: versionInfo.releaseDateLabel,
            updateType: versionInfo.updateType,
            canSkip: false,
            storeUrl: versionInfo.storeUrl,
            lastCheckedAt: DateTime.now(),
            clearErrorMessage: true,
          ),
        );
        return;
      }

      if (soft && !_softUpdateDismissed) {
        _setState(
          _state.copyWith(
            status: LumaUpdateStatus.softUpdateAvailable,
            currentVersion: current,
            latestVersion: versionInfo.latestVersion,
            requiredVersion: versionInfo.requiredVersion,
            title: versionInfo.title,
            message: versionInfo.message,
            changelog: versionInfo.changelog,
            downloadSizeLabel: versionInfo.downloadSizeLabel,
            releaseDateLabel: versionInfo.releaseDateLabel,
            updateType: versionInfo.updateType,
            canSkip: true,
            storeUrl: versionInfo.storeUrl,
            lastCheckedAt: DateTime.now(),
            clearErrorMessage: true,
          ),
        );
        return;
      }

      _setState(
        _state.copyWith(
          status: LumaUpdateStatus.upToDate,
          currentVersion: current,
          latestVersion: versionInfo.latestVersion,
          requiredVersion: versionInfo.requiredVersion,
          title: versionInfo.title,
          message: versionInfo.message,
          updateType: versionInfo.updateType,
          storeUrl: versionInfo.storeUrl,
          lastCheckedAt: DateTime.now(),
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      debugPrint('UpdateController check failed: $error');
      _setState(
        _state.copyWith(
          status: LumaUpdateStatus.error,
          errorMessage: 'Die Update-Prüfung konnte nicht abgeschlossen werden.',
          lastCheckedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> updateNow() async {
    if (_state.isPwaUpdate) {
      _setState(
        _state.copyWith(
          status: LumaUpdateStatus.installing,
          isInstalling: true,
          installProgress: 0.5,
        ),
      );
      await _pwaUpdateService.activateUpdateAndReload();
      return;
    }

    final rawUrl = _state.storeUrl.trim();
    if (rawUrl.isEmpty) return;

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void remindLater() {
    if (!_state.canSkip) return;
    _softUpdateDismissed = true;
    _setState(
      _state.copyWith(
        status: LumaUpdateStatus.upToDate,
        clearErrorMessage: true,
      ),
    );
  }

  void continueAfterNonBlockingError() {
    _setState(
      _state.copyWith(
        status: LumaUpdateStatus.upToDate,
        clearErrorMessage: true,
      ),
    );
  }

  int _compareVersions(String a, String b) {
    final aa = _parts(a);
    final bb = _parts(b);
    final length = aa.length > bb.length ? aa.length : bb.length;

    for (var i = 0; i < length; i++) {
      final av = i < aa.length ? aa[i] : 0;
      final bv = i < bb.length ? bb[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  List<int> _parts(String value) {
    return value
        .trim()
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList(growable: false);
  }

  void _setState(UpdateState next) {
    if (_isDisposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_pwaUpdateSubscription?.cancel());
    _pwaUpdateSubscription = null;
    super.dispose();
  }
}
