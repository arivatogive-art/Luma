// Pfad: lib/application/pwa_update_service_stub.dart

import 'dart:async';

class PwaUpdateService {
  const PwaUpdateService();

  Stream<bool> get updateAvailableStream => const Stream<bool>.empty();

  Future<void> initialize() async {}
  Future<void> checkForUpdate() async {}
  Future<void> activateUpdateAndReload() async {}
}
