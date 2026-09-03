// Pfad: lib/application/logout_landing_destination_service_stub.dart

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
    _activeUnauthenticatedDestination = null;
  }

  void cancelPendingLogout() {
    _pendingLogout = false;
  }

  void clearUnauthenticatedDestination() {
    _pendingLogout = false;
    _activeUnauthenticatedDestination = null;
  }

  LogoutLandingDestination resolveUnauthenticatedDestination() {
    final activeDestination = _activeUnauthenticatedDestination;

    if (activeDestination != null) {
      return activeDestination;
    }

    if (_pendingLogout) {
      _pendingLogout = false;
      _activeUnauthenticatedDestination =
          LogoutLandingDestination.loginScreen;

      return LogoutLandingDestination.loginScreen;
    }

    _activeUnauthenticatedDestination =
        LogoutLandingDestination.startScreen;

    return LogoutLandingDestination.startScreen;
  }
}
