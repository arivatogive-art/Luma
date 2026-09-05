// Pfad: lib/features/search/application/profile_search_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/profile_search_repository.dart';
import '../domain/profile_search_result.dart';

enum ProfileSearchState {
  initial,
  loading,
  loaded,
  empty,
  error,
}

class ProfileSearchController extends ChangeNotifier {
  ProfileSearchController({ProfileSearchRepository? repository})
      : _repository = repository ?? ProfileSearchRepository();

  final ProfileSearchRepository _repository;

  ProfileSearchState _state = ProfileSearchState.initial;
  List<ProfileSearchResult> _results = const <ProfileSearchResult>[];
  String _query = '';
  String? _errorMessage;
  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  ProfileSearchState get state => _state;
  List<ProfileSearchResult> get results => _results;
  String get query => _query;
  String? get errorMessage => _errorMessage;

  void updateQuery(String value) {
    _query = value;
    _debounce?.cancel();

    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      _requestId++;
      _results = const <ProfileSearchResult>[];
      _errorMessage = null;
      _setState(ProfileSearchState.initial);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      search(cleaned);
    });
  }

  Future<void> search(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      _results = const <ProfileSearchResult>[];
      _errorMessage = null;
      _setState(ProfileSearchState.initial);
      return;
    }

    final requestId = ++_requestId;
    _query = cleaned;
    _errorMessage = null;
    _setState(ProfileSearchState.loading);

    try {
      final results = await _repository.searchProfiles(query: cleaned);
      if (_disposed || requestId != _requestId) return;

      _results = results;
      _setState(
        results.isEmpty ? ProfileSearchState.empty : ProfileSearchState.loaded,
      );
    } catch (error, stackTrace) {
      if (_disposed || requestId != _requestId) return;

      debugPrint('ProfileSearchController: Suche fehlgeschlagen.');
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      _results = const <ProfileSearchResult>[];
      _errorMessage = 'Die Suche konnte nicht geladen werden.';
      _setState(ProfileSearchState.error);
    }
  }

  Future<void> retry() async {
    final cleaned = _query.trim();
    if (cleaned.isEmpty) return;
    await search(cleaned);
  }

  void _setState(ProfileSearchState nextState) {
    if (_disposed) return;
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
