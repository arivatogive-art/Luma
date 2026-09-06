// Pfad: lib/features/security/application/security_events_controller.dart
//
// Luma Core Rebuild 2.0 - Sicherheit & Anmeldung, Phase C1.
// Read-only Controller für bestehende Sicherheitsereignisse.

import 'package:flutter/foundation.dart';

import '../data/security_event_repository.dart';
import '../domain/security_event_model.dart';

class SecurityEventsController extends ChangeNotifier {
  SecurityEventsController({SecurityEventRepository? repository})
    : _repository = repository ?? SecurityEventRepository();

  final SecurityEventRepository _repository;

  List<SecurityEventModel> _events = const <SecurityEventModel>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<SecurityEventModel> get events => _events;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _events.where((event) => event.isUnread).length;

  Future<void> load({required String userId, int limit = 30}) async {
    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      _events = const <SecurityEventModel>[];
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _repository.loadRecentEvents(
        userId: cleanedUserId,
        limit: limit,
      );
    } catch (_) {
      _events = const <SecurityEventModel>[];
      _errorMessage =
          'Die Sicherheitsaktivitäten konnten gerade nicht geladen werden.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
