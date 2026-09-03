// Pfad: lib/application/logout_landing_destination_service_web.dart

import 'dart:js_interop';

import 'package:web/web.dart' as web;

extension type _NavigatorStandalone(JSObject _) implements JSObject {
  external bool? get standalone;
}

enum LogoutLandingDestination {
  startScreen,
  loginScreen,
}

class LogoutLandingDestinationService {
  LogoutLandingDestinationService._();

  static final LogoutLandingDestinationService instance =
      LogoutLandingDestinationService._();

  bool _pendingLogout = false;
  LogoutLandingDestination? _activeUnauthenticatedDestination;

  void markLogoutStarted() {
    _pendingLogout = true;
  }

  void cancelPendingLogout() {
    _pendingLogout = false;
  }

  void clearUnauthenticatedDestination() {
    _pendingLogout = false;
    _activeUnauthenticatedDestination = null;
  }

  LogoutLandingDestination resolveUnauthenticatedDestination() {
    if (_activeUnauthenticatedDestination != null) {
      return _activeUnauthenticatedDestination!;
    }

    if (!_pendingLogout) {
      _activeUnauthenticatedDestination = LogoutLandingDestination.startScreen;
      return _activeUnauthenticatedDestination!;
    }

    _pendingLogout = false;

    _activeUnauthenticatedDestination = _shouldUseAppLogoutLanding()
        ? LogoutLandingDestination.startScreen
        : LogoutLandingDestination.loginScreen;

    return _activeUnauthenticatedDestination!;
  }

  bool _shouldUseAppLogoutLanding() {
    return _isRunningAsInstalledPwa() || _isRunningInsideAndroidAppShell();
  }

  bool _isRunningAsInstalledPwa() {
    final standaloneDisplayMode =
        web.window.matchMedia('(display-mode: standalone)').matches;

    final fullscreenDisplayMode =
        web.window.matchMedia('(display-mode: fullscreen)').matches;

    final minimalUiDisplayMode =
        web.window.matchMedia('(display-mode: minimal-ui)').matches;

    final windowControlsOverlayDisplayMode = web.window
        .matchMedia('(display-mode: window-controls-overlay)')
        .matches;

    final navigator = _NavigatorStandalone(web.window.navigator as JSObject);
    final navigatorStandalone = navigator.standalone == true;

    return standaloneDisplayMode ||
        fullscreenDisplayMode ||
        minimalUiDisplayMode ||
        windowControlsOverlayDisplayMode ||
        navigatorStandalone;
  }

  bool _isRunningInsideAndroidAppShell() {
    final referrer = web.document.referrer.toLowerCase();
    final userAgent = web.window.navigator.userAgent.toLowerCase();

    final launchedFromAndroidApp = referrer.startsWith('android-app://');

    final likelyWebView = userAgent.contains('; wv') ||
        userAgent.contains('version/4.0 chrome') ||
        userAgent.contains('luma');

    return launchedFromAndroidApp || likelyWebView;
  }
}
