// Pfad: lib/features/notifications/application/notification_controller.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

enum LumaNotificationsLoadState {
  initial,
  loading,
  loaded,
  error,
}

class LumaNotificationController extends ChangeNotifier {
  LumaNotificationController({
    FirebaseAuth? firebaseAuth,
    LumaNotificationRepository? repository,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _repository = repository ?? LumaNotificationRepository();

  final FirebaseAuth _firebaseAuth;
  final LumaNotificationRepository _repository;

  LumaNotificationsLoadState _state = LumaNotificationsLoadState.initial;
  List<LumaNotificationModel> _notifications =
      const <LumaNotificationModel>[];
  String? _errorMessage;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<LumaNotificationModel>>?
      _notificationsSubscription;

  String? _activeUserId;
  bool _disposed = false;

  LumaNotificationsLoadState get state => _state;
  List<LumaNotificationModel> get notifications => _notifications;
  String? get errorMessage => _errorMessage;

  int get unreadCount {
    var count = 0;
    for (final notification in _notifications) {
      if (notification.isUnread) count++;
    }
    return count;
  }

  Future<void> initialize() async {
    if (_disposed) return;

    _authSubscription ??= _firebaseAuth.authStateChanges().listen(
      _handleAuthUser,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('LumaNotificationController auth stream failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _setError();
      },
    );

    await _handleAuthUser(_firebaseAuth.currentUser);
  }

  Future<void> reload() async {
    if (_disposed) return;
    await _handleAuthUser(_firebaseAuth.currentUser);
  }

  Future<void> _handleAuthUser(User? user) async {
    if (_disposed) return;

    final userId = user?.uid.trim() ?? '';

    if (userId.isEmpty) {
      _activeUserId = null;
      await _notificationsSubscription?.cancel();
      _notificationsSubscription = null;
      _notifications = const <LumaNotificationModel>[];
      _errorMessage = null;
      _setState(LumaNotificationsLoadState.loaded);
      return;
    }

    if (_activeUserId == userId &&
        _notificationsSubscription != null &&
        _state != LumaNotificationsLoadState.error) {
      return;
    }

    _activeUserId = userId;
    _errorMessage = null;
    _setState(LumaNotificationsLoadState.loading);

    await _notificationsSubscription?.cancel();
    _notificationsSubscription = null;

    _notificationsSubscription = _repository
        .watchNotifications(
          userId: userId,
          limit: 100,
        )
        .listen(
      (notifications) {
        if (_disposed || _activeUserId != userId) return;

        _notifications = notifications;
        _errorMessage = null;
        _setState(LumaNotificationsLoadState.loaded);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed || _activeUserId != userId) return;

        debugPrint('LumaNotificationController watch failed: $error');
        debugPrintStack(stackTrace: stackTrace);

        _notifications = const <LumaNotificationModel>[];
        _errorMessage = 'Benachrichtigungen konnten nicht geladen werden.';
        _setState(LumaNotificationsLoadState.error);
      },
    );
  }

  void _setError() {
    if (_disposed) return;
    _notifications = const <LumaNotificationModel>[];
    _errorMessage = 'Benachrichtigungen konnten nicht geladen werden.';
    _setState(LumaNotificationsLoadState.error);
  }

  void _setState(LumaNotificationsLoadState nextState) {
    if (_disposed) return;
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;

    unawaited(_authSubscription?.cancel());
    unawaited(_notificationsSubscription?.cancel());

    _authSubscription = null;
    _notificationsSubscription = null;

    super.dispose();
  }
}
