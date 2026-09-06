// Pfad: lib/features/security/application/security_devices_controller.dart

import 'package:flutter/foundation.dart';

import '../data/security_device_repository.dart';
import '../domain/security_device_model.dart';

class SecurityDevicesController extends ChangeNotifier {
  SecurityDevicesController({
    SecurityDeviceRepository? repository,
  }) : _repository = repository ?? SecurityDeviceRepository();

  final SecurityDeviceRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  List<SecurityDeviceModel> _devices = const <SecurityDeviceModel>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<SecurityDeviceModel> get devices => _devices;

  List<SecurityDeviceModel> get activeDevices =>
      List<SecurityDeviceModel>.unmodifiable(
        _devices.where((device) => device.active),
      );

  List<SecurityDeviceModel> get inactiveDevices =>
      List<SecurityDeviceModel>.unmodifiable(
        _devices.where((device) => !device.active),
      );

  Future<void> load({
    required String userId,
  }) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      _devices = const <SecurityDeviceModel>[];
      _errorMessage = 'Keine aktive Anmeldung gefunden.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _devices = await _repository.loadDevices(userId: cleanedUserId);
    } catch (_) {
      _devices = const <SecurityDeviceModel>[];
      _errorMessage =
          'Die Geräteliste konnte gerade nicht geladen werden.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
