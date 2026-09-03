// Pfad: lib/application/pwa_update_service.dart

export 'pwa_update_service_stub.dart'
    if (dart.library.html) 'pwa_update_service_web.dart';
