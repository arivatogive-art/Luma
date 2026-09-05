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
  String? _markingNotificationId;
  bool _isMarkingAllAsRead = false;
  bool _disposed = false;

  LumaNotificationsLoadState get state => _state;
  List<LumaNotificationModel> get notifications => _notifications;
  String? get errorMessage => _errorMessage;
  String? get markingNotificationId => _markingNotificationId;
  bool get isMarkingAllAsRead => _isMarkingAllAsRead;

  int get unreadCount {
    var count = 0;
    for (final notification in _notifications) {
      if (notification.isUnread) count++;
    }
    return count;
  }

  bool isMarkingAsRead(String notificationId) {
    return _markingNotificationId == notificationId.trim();
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
    await _handleAuthUser(
      _firebaseAuth.currentUser,
      force: true,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    if (_disposed) return;

    final cleanedNotificationId = notificationId.trim();
    final userId = _activeUserId?.trim() ?? '';

    if (cleanedNotificationId.isEmpty || userId.isEmpty) {
      return;
    }

    LumaNotificationModel? notification;
    for (final current in _notifications) {
      if (current.id == cleanedNotificationId) {
        notification = current;
        break;
      }
    }

    if (notification == null || notification.isRead) {
      return;
    }

    if (_markingNotificationId != null || _isMarkingAllAsRead) {
      return;
    }

    _markingNotificationId = cleanedNotificationId;
    _errorMessage = null;
    _notifySafely();

    try {
      await _repository.markAsRead(
        userId: userId,
        notificationId: cleanedNotificationId,
      );
    } catch (error, stackTrace) {
      debugPrint('Luma mark notification as read failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = 'Die Benachrichtigung konnte nicht aktualisiert werden.';
    } finally {
      _markingNotificationId = null;
      _notifySafely();
    }
  }

  Future<void> markAllAsRead() async {
    if (_disposed || unreadCount == 0 || _isMarkingAllAsRead) {
      return;
    }

    final userId = _activeUserId?.trim() ?? '';
    if (userId.isEmpty) {
      return;
    }

    _isMarkingAllAsRead = true;
    _errorMessage = null;
    _notifySafely();

    try {
      await _repository.markAllAsRead(userId: userId);
    } catch (error, stackTrace) {
      debugPrint('Luma mark all notifications as read failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage =
          'Die Benachrichtigungen konnten nicht aktualisiert werden.';
    } finally {
      _isMarkingAllAsRead = false;
      _notifySafely();
    }
  }

  Future<void> _handleAuthUser(
    User? user, {
    bool force = false,
  }) async {
    if (_disposed) return;

    final userId = user?.uid.trim() ?? '';

    if (userId.isEmpty) {
      _activeUserId = null;
      _markingNotificationId = null;
      _isMarkingAllAsRead = false;
      await _notificationsSubscription?.cancel();
      _notificationsSubscription = null;
      _notifications = const <LumaNotificationModel>[];
      _errorMessage = null;
      _setState(LumaNotificationsLoadState.loaded);
      return;
    }

    if (!force &&
        _activeUserId == userId &&
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

  void _notifySafely() {
    if (_disposed) return;
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
