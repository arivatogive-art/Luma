// Pfad: lib/application/pwa_update_service_web.dart

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class PwaUpdateService {
  PwaUpdateService();

  final StreamController<bool> _updateAvailableController =
      StreamController<bool>.broadcast();

  bool _initialized = false;

  Stream<bool> get updateAvailableStream =>
      _updateAvailableController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await checkForUpdate();
  }

  Future<void> checkForUpdate() async {
    final serviceWorker = web.window.navigator.serviceWorker;
    final registration = await serviceWorker.getRegistration().toDart;
    if (registration == null) return;

    await registration.update().toDart;

    if (registration.waiting != null) {
      _updateAvailableController.add(true);
    }
  }

  Future<void> activateUpdateAndReload() async {
    final serviceWorker = web.window.navigator.serviceWorker;
    final registration = await serviceWorker.getRegistration().toDart;
    final waiting = registration?.waiting;

    if (waiting != null) {
      waiting.postMessage(<String, String>{'type': 'SKIP_WAITING'}.jsify());
    }

    web.window.location.reload();
  }
}
