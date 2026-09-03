// Pfad: lib/features/notifications/application/notification_controller.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/notification_repository.dart';
import '../../../data/friendship_repository.dart';
import '../domain/models/notification_model.dart';
import 'notification_service.dart';
import 'notification_state.dart';

enum LumaFriendRequestActionResult {
  success,
  notFound,
  invalidNotificationType,
  alreadyHandled,
}

class LumaNotificationController extends ChangeNotifier {
  final LumaNotificationService _notificationService;
  final LumaNotificationRepository _notificationRepository;
  final FriendshipRepository _friendshipRepository;
  final FirebaseAuth _firebaseAuth;

  LumaNotificationState _state = const LumaNotificationState.initial();
  StreamSubscription<List<LumaNotificationModel>>? _notificationsSubscription;

  String? _activeUserId;
  bool _isUsingMockFallback = false;

  LumaNotificationController({
    LumaNotificationService notificationService =
        const LumaNotificationService(),
    LumaNotificationRepository? notificationRepository,
    FriendshipRepository? friendshipRepository,
    FirebaseAuth? firebaseAuth,
  })  : _notificationService = notificationService,
        _notificationRepository =
            notificationRepository ?? LumaNotificationRepository(),
        _friendshipRepository =
            friendshipRepository ?? FriendshipRepository(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  LumaNotificationState get state => _state;

  bool get isUsingMockFallback => _isUsingMockFallback;

  String? get activeUserId => _activeUserId;

  Future<void> initialize() async {
    await _notificationsSubscription?.cancel();
    _notificationsSubscription = null;

    _setState(
      _state.copyWith(
        isLoading: true,
        processingFriendRequestNotificationIds: const <String>{},
        clearError: true,
      ),
    );

    final currentUserId = _firebaseAuth.currentUser?.uid.trim();

    if (currentUserId == null || currentUserId.isEmpty) {
      _activeUserId = null;
      _isUsingMockFallback = true;
      _loadMockNotifications();
      return;
    }

    _activeUserId = currentUserId;
    _isUsingMockFallback = false;

    _notificationsSubscription = _notificationRepository
        .watchNotifications(userId: currentUserId)
        .listen(
      (notifications) {
        _setState(
          _state.copyWith(
            isLoading: false,
            notifications: _sortNotifications(notifications),
            processingFriendRequestNotificationIds: const <String>{},
            clearError: true,
          ),
        );
      },
      onError: (Object error) {
        debugPrint('Luma notification watch failed: $error');

        _activeUserId = currentUserId;
        _isUsingMockFallback = true;

        _setState(
          _state.copyWith(
            isLoading: false,
            notifications: _sortNotifications(_buildMockNotifications()),
            processingFriendRequestNotificationIds: const <String>{},
            errorMessage: 'Benachrichtigungen konnten nicht geladen werden.',
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_notificationsSubscription?.cancel());
    _notificationsSubscription = null;
    super.dispose();
  }

  void receiveNotification(LumaNotificationModel notification) {
    if (_notificationService.shouldThrottleNotification(
      incomingNotification: notification,
      existingNotifications: _state.notifications,
    )) {
      return;
    }

    final existingIndex = _state.notifications.indexWhere(
      (existingNotification) {
        return existingNotification.id == notification.id ||
            _notificationService.isDuplicateNotification(
              incomingNotification: notification,
              existingNotifications: <LumaNotificationModel>[
                existingNotification,
              ],
            );
      },
    );

    if (existingIndex != -1) {
      _replaceExistingNotification(
        existingIndex: existingIndex,
        notification: notification,
      );
      return;
    }

    final normalizedNotification = _withDefaultFriendRequestStatus(
      notification.copyWith(
        priority: _notificationService.priorityForType(notification.type),
      ),
    );

    final updatedNotifications = <LumaNotificationModel>[
      normalizedNotification,
      ..._state.notifications,
    ];

    _setState(
      _state.copyWith(
        notifications: _sortNotifications(updatedNotifications),
        clearError: true,
      ),
    );

    _persistNotificationIfPossible(normalizedNotification);
  }

  void receiveNotificationByType({
    required String id,
    required String userId,
    required LumaNotificationType type,
    required LumaNotificationTargetType targetType,
    required String referenceId,
    String? secondaryReferenceId,
    required String title,
    required String body,
    DateTime? createdAt,
  }) {
    final notification = LumaNotificationModel(
      id: id.trim(),
      userId: userId.trim(),
      type: type,
      priority: _notificationService.priorityForType(type),
      targetType: targetType,
      referenceId: referenceId.trim(),
      secondaryReferenceId: _cleanNullableString(secondaryReferenceId),
      title: title.trim(),
      body: body.trim(),
      createdAt: createdAt ?? DateTime.now(),
      friendRequestStatus: _friendRequestStatusForType(type),
    );

    receiveNotification(notification);
  }

  LumaNotificationRouteTarget? openNotification(String notificationId) {
    final notification = _findNotificationById(notificationId);

    if (notification == null) return null;

    markAsRead(notificationId);

    return _notificationService.resolveRouteTarget(notification);
  }

  Future<LumaFriendRequestActionResult> acceptFriendRequest(
    String notificationId,
  ) async {
    if (_state.isProcessingFriendRequest(notificationId)) {
      return LumaFriendRequestActionResult.alreadyHandled;
    }

    final notification = _findNotificationById(notificationId);

    if (notification == null) {
      return LumaFriendRequestActionResult.notFound;
    }

    if (notification.type != LumaNotificationType.friendRequest) {
      return LumaFriendRequestActionResult.invalidNotificationType;
    }

    if (!notification.isPendingFriendRequest) {
      return LumaFriendRequestActionResult.alreadyHandled;
    }

    final friendshipId = _resolveFriendshipId(notification);

    if (!_isUsingMockFallback && friendshipId.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage:
              'Die zugehörige Freundschaftsanfrage wurde nicht gefunden.',
        ),
      );
      return LumaFriendRequestActionResult.notFound;
    }

    _startProcessingFriendRequest(notificationId);

    try {
      if (!_isUsingMockFallback) {
        await _friendshipRepository.acceptFriendRequest(
          friendshipId: friendshipId,
        );
      }

      final updatedNotifications = _state.notifications.map((current) {
        if (current.id != notificationId) return current;

        return current.copyWith(
          type: LumaNotificationType.friendRequestAccepted,
          priority: _notificationService.priorityForType(
            LumaNotificationType.friendRequestAccepted,
          ),
          title: 'Freundschaft bestätigt',
          body: current.safeActorDisplayName == 'Luma Nutzer'
              ? 'Ihr seid jetzt verbunden.'
              : 'Du und ${current.safeActorDisplayName} seid jetzt Freunde.',
          createdAt: DateTime.now(),
          isRead: true,
          friendRequestStatus: LumaFriendRequestStatus.accepted,
        );
      }).toList(growable: false);

      _setState(
        _state.copyWith(
          notifications: _sortNotifications(updatedNotifications),
          clearError: true,
        ),
      );

      if (!_isUsingMockFallback) {
        await _updateFriendRequestStatusIfPossible(
          notificationId: notificationId,
          status: LumaFriendRequestStatus.accepted,
        );
      }

      return LumaFriendRequestActionResult.success;
    } catch (error, stackTrace) {
      debugPrint(
        'Luma accept friend request notification failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      _setState(
        _state.copyWith(
          errorMessage: 'Die Anfrage konnte nicht bestätigt werden.',
        ),
      );

      return LumaFriendRequestActionResult.alreadyHandled;
    } finally {
      _stopProcessingFriendRequest(notificationId);
    }
  }

  Future<LumaFriendRequestActionResult> removeFriendRequest(
    String notificationId,
  ) async {
    if (_state.isProcessingFriendRequest(notificationId)) {
      return LumaFriendRequestActionResult.alreadyHandled;
    }

    final notification = _findNotificationById(notificationId);

    if (notification == null) {
      return LumaFriendRequestActionResult.notFound;
    }

    if (notification.type != LumaNotificationType.friendRequest) {
      return LumaFriendRequestActionResult.invalidNotificationType;
    }

    if (!notification.isPendingFriendRequest) {
      return LumaFriendRequestActionResult.alreadyHandled;
    }

    final friendshipId = _resolveFriendshipId(notification);

    if (!_isUsingMockFallback && friendshipId.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage:
              'Die zugehörige Freundschaftsanfrage wurde nicht gefunden.',
        ),
      );
      return LumaFriendRequestActionResult.notFound;
    }

    _startProcessingFriendRequest(notificationId);

    try {
      if (!_isUsingMockFallback) {
        await _friendshipRepository.declineFriendRequest(
          friendshipId: friendshipId,
        );
      }

      final updatedNotifications = _state.notifications.where((current) {
        return current.id != notificationId;
      }).toList(growable: false);

      final updatedProcessingIds = Set<String>.from(
        _state.processingFriendRequestNotificationIds,
      )..remove(notificationId);

      _setState(
        _state.copyWith(
          notifications: updatedNotifications,
          processingFriendRequestNotificationIds: updatedProcessingIds,
          clearError: true,
        ),
      );

      if (!_isUsingMockFallback) {
        await _updateFriendRequestStatusIfPossible(
          notificationId: notificationId,
          status: LumaFriendRequestStatus.removed,
        );

        await _removeNotificationFromRepositoryIfPossible(notificationId);
      }

      return LumaFriendRequestActionResult.success;
    } catch (error, stackTrace) {
      debugPrint(
        'Luma remove friend request notification failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      _setState(
        _state.copyWith(
          errorMessage: 'Die Anfrage konnte nicht entfernt werden.',
        ),
      );

      return LumaFriendRequestActionResult.alreadyHandled;
    } finally {
      _stopProcessingFriendRequest(notificationId);
    }
  }

  bool canNotificationTriggerPush(String notificationId) {
    final notification = _findNotificationById(notificationId);

    if (notification == null) return false;

    return _notificationService.canTriggerPush(notification);
  }

  void markAsRead(String notificationId) {
    final updatedNotifications = _state.notifications.map((notification) {
      if (notification.id != notificationId) return notification;

      return notification.markAsRead();
    }).toList(growable: false);

    _setState(
      _state.copyWith(
        notifications: updatedNotifications,
        clearError: true,
      ),
    );

    if (!_isUsingMockFallback) {
      final activeUserId = _activeUserId?.trim();

      if (activeUserId != null && activeUserId.isNotEmpty) {
        unawaited(
          _notificationRepository.markAsRead(
            userId: activeUserId,
            notificationId: notificationId,
          ),
        );
      }
    }
  }

  void markAllAsRead() {
    final updatedNotifications = _state.notifications.map((notification) {
      return notification.markAsRead();
    }).toList(growable: false);

    _setState(
      _state.copyWith(
        notifications: updatedNotifications,
        clearError: true,
      ),
    );

    if (!_isUsingMockFallback) {
      final activeUserId = _activeUserId?.trim();

      if (activeUserId != null && activeUserId.isNotEmpty) {
        unawaited(
          _notificationRepository.markAllAsRead(userId: activeUserId),
        );
      }
    }
  }

  void removeNotification(String notificationId) {
    final updatedNotifications = _state.notifications.where((notification) {
      return notification.id != notificationId;
    }).toList(growable: false);

    final updatedProcessingIds = Set<String>.from(
      _state.processingFriendRequestNotificationIds,
    )..remove(notificationId);

    _setState(
      _state.copyWith(
        notifications: updatedNotifications,
        processingFriendRequestNotificationIds: updatedProcessingIds,
        clearError: true,
      ),
    );

    unawaited(_removeNotificationFromRepositoryIfPossible(notificationId));
  }

  void clearAll() {
    _setState(
      _state.copyWith(
        notifications: const <LumaNotificationModel>[],
        processingFriendRequestNotificationIds: const <String>{},
        clearError: true,
      ),
    );

    if (!_isUsingMockFallback) {
      final activeUserId = _activeUserId?.trim();

      if (activeUserId != null && activeUserId.isNotEmpty) {
        unawaited(
          _notificationRepository.clearNotifications(userId: activeUserId),
        );
      }
    }
  }

  void clearError() {
    _setState(_state.copyWith(clearError: true));
  }

  void _loadMockNotifications() {
    _setState(
      _state.copyWith(
        isLoading: false,
        notifications: _sortNotifications(_buildMockNotifications()),
        processingFriendRequestNotificationIds: const <String>{},
        clearError: true,
      ),
    );
  }

  List<LumaNotificationModel> _buildMockNotifications() {
    final now = DateTime.now();

    return <LumaNotificationModel>[
      LumaNotificationModel(
        id: 'notification_comment_001',
        userId: 'current_user',
        type: LumaNotificationType.postComment,
        priority: _notificationService.priorityForType(
          LumaNotificationType.postComment,
        ),
        targetType: LumaNotificationTargetType.comment,
        referenceId: 'post_001',
        secondaryReferenceId: 'comment_001',
        title: 'Neuer Kommentar',
        body: 'Mara hat deinen Beitrag kommentiert.',
        createdAt: now.subtract(const Duration(minutes: 8)),
      ),
      LumaNotificationModel(
        id: 'notification_reply_001',
        userId: 'current_user',
        type: LumaNotificationType.commentReply,
        priority: _notificationService.priorityForType(
          LumaNotificationType.commentReply,
        ),
        targetType: LumaNotificationTargetType.comment,
        referenceId: 'post_001',
        secondaryReferenceId: 'comment_018',
        title: 'Neue Antwort',
        body: 'Noah hat auf deinen Kommentar geantwortet.',
        createdAt: now.subtract(const Duration(minutes: 26)),
      ),
      LumaNotificationModel(
        id: 'notification_like_001',
        userId: 'current_user',
        type: LumaNotificationType.postLike,
        priority: _notificationService.priorityForType(
          LumaNotificationType.postLike,
        ),
        targetType: LumaNotificationTargetType.post,
        referenceId: 'post_002',
        title: 'Neue Likes',
        body: 'Lea und 3 weitere Personen mögen deinen Beitrag.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      LumaNotificationModel(
        id: 'notification_friend_request_001',
        userId: 'current_user',
        type: LumaNotificationType.friendRequest,
        priority: _notificationService.priorityForType(
          LumaNotificationType.friendRequest,
        ),
        targetType: LumaNotificationTargetType.profile,
        referenceId: 'user_007',
        title: 'Neue Freundschaftsanfrage',
        body: 'Elias möchte sich mit dir verbinden.',
        createdAt: now.subtract(const Duration(hours: 4)),
        friendRequestStatus: LumaFriendRequestStatus.pending,
      ),
      LumaNotificationModel(
        id: 'notification_friend_accepted_001',
        userId: 'current_user',
        type: LumaNotificationType.friendRequestAccepted,
        priority: _notificationService.priorityForType(
          LumaNotificationType.friendRequestAccepted,
        ),
        targetType: LumaNotificationTargetType.profile,
        referenceId: 'user_002',
        title: 'Freundschaft bestätigt',
        body: 'Sofia hat deine Freundschaftsanfrage angenommen.',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
        friendRequestStatus: LumaFriendRequestStatus.accepted,
      ),
      LumaNotificationModel(
        id: 'notification_security_001',
        userId: 'current_user',
        type: LumaNotificationType.securityAlert,
        priority: _notificationService.priorityForType(
          LumaNotificationType.securityAlert,
        ),
        targetType: LumaNotificationTargetType.system,
        referenceId: 'security_login_001',
        title: 'Sicherheitsprüfung',
        body:
            'Neue Anmeldung erkannt. Bitte prüfe deine Sicherheitseinstellungen.',
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
  }

  void _startProcessingFriendRequest(String notificationId) {
    final updatedProcessingIds = Set<String>.from(
      _state.processingFriendRequestNotificationIds,
    )..add(notificationId);

    _setState(
      _state.copyWith(
        processingFriendRequestNotificationIds: updatedProcessingIds,
        clearError: true,
      ),
    );
  }

  void _stopProcessingFriendRequest(String notificationId) {
    final updatedProcessingIds = Set<String>.from(
      _state.processingFriendRequestNotificationIds,
    )..remove(notificationId);

    _setState(
      _state.copyWith(
        processingFriendRequestNotificationIds: updatedProcessingIds,
        clearError: true,
      ),
    );
  }

  void _replaceExistingNotification({
    required int existingIndex,
    required LumaNotificationModel notification,
  }) {
    final updatedNotifications = List<LumaNotificationModel>.from(
      _state.notifications,
    );

    final normalizedNotification = _withDefaultFriendRequestStatus(
      notification.copyWith(
        priority: _notificationService.priorityForType(notification.type),
        createdAt: DateTime.now(),
        isRead: false,
      ),
    );

    updatedNotifications[existingIndex] = normalizedNotification;

    _setState(
      _state.copyWith(
        notifications: _sortNotifications(updatedNotifications),
        clearError: true,
      ),
    );

    _persistNotificationIfPossible(normalizedNotification);
  }

  LumaNotificationModel _withDefaultFriendRequestStatus(
    LumaNotificationModel notification,
  ) {
    final status = _friendRequestStatusForType(notification.type);

    if (status == null || notification.friendRequestStatus != null) {
      return notification;
    }

    return notification.copyWith(friendRequestStatus: status);
  }

  LumaFriendRequestStatus? _friendRequestStatusForType(
    LumaNotificationType type,
  ) {
    switch (type) {
      case LumaNotificationType.friendRequest:
        return LumaFriendRequestStatus.pending;
      case LumaNotificationType.friendRequestAccepted:
        return LumaFriendRequestStatus.accepted;
      case LumaNotificationType.postLike:
      case LumaNotificationType.postComment:
      case LumaNotificationType.commentReply:
      case LumaNotificationType.directMessage:
      case LumaNotificationType.storyView:
      case LumaNotificationType.storyReaction:
      case LumaNotificationType.storyReply:
      case LumaNotificationType.mention:
      case LumaNotificationType.securityAlert:
      case LumaNotificationType.systemUpdate:
        return null;
    }
  }

  String _resolveFriendshipId(
    LumaNotificationModel notification,
  ) {
    final explicitFriendshipId = notification.friendshipId?.trim();

    if (explicitFriendshipId != null && explicitFriendshipId.isNotEmpty) {
      return explicitFriendshipId;
    }

    final notificationId = notification.id.trim();

    const acceptedPrefix = 'friend_request_accepted_';
    const requestPrefix = 'friend_request_';

    if (notificationId.startsWith(acceptedPrefix)) {
      return notificationId.substring(acceptedPrefix.length).trim();
    }

    if (notificationId.startsWith(requestPrefix)) {
      return notificationId.substring(requestPrefix.length).trim();
    }

    return '';
  }

  LumaNotificationModel? _findNotificationById(String notificationId) {
    final cleanedNotificationId = notificationId.trim();

    if (cleanedNotificationId.isEmpty) return null;

    for (final notification in _state.notifications) {
      if (notification.id == cleanedNotificationId) return notification;
    }

    return null;
  }

  List<LumaNotificationModel> _sortNotifications(
    List<LumaNotificationModel> notifications,
  ) {
    final sortedNotifications = List<LumaNotificationModel>.from(notifications);

    sortedNotifications.sort((first, second) {
      return second.createdAt.compareTo(first.createdAt);
    });

    return sortedNotifications;
  }

  void _persistNotificationIfPossible(LumaNotificationModel notification) {
    if (_isUsingMockFallback) return;

    final activeUserId = _activeUserId?.trim();

    if (activeUserId == null || activeUserId.isEmpty) return;
    if (notification.userId != activeUserId) return;

    unawaited(
      _notificationRepository.createNotification(notification: notification),
    );
  }

  Future<void> _updateFriendRequestStatusIfPossible({
    required String notificationId,
    required LumaFriendRequestStatus status,
  }) async {
    if (_isUsingMockFallback) return;

    final activeUserId = _activeUserId?.trim();

    if (activeUserId == null || activeUserId.isEmpty) return;

    await _notificationRepository.updateFriendRequestStatus(
      userId: activeUserId,
      notificationId: notificationId,
      status: status,
    );
  }

  Future<void> _removeNotificationFromRepositoryIfPossible(
    String notificationId,
  ) async {
    if (_isUsingMockFallback) return;

    final activeUserId = _activeUserId?.trim();

    if (activeUserId == null || activeUserId.isEmpty) return;

    await _notificationRepository.removeNotification(
      userId: activeUserId,
      notificationId: notificationId,
    );
  }

  void _setState(LumaNotificationState newState) {
    _state = newState;
    notifyListeners();
  }

  String? _cleanNullableString(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) return null;

    return cleaned;
  }
}
