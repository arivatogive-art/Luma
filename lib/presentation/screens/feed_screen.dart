// Pfad: lib/presentation/screens/feed_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../app/theme.dart';
import '../../application/feed_controller.dart';
import '../../application/feed_comment_preview_cache.dart';
import '../../application/feed_share_service.dart';
import '../../application/feed_remote_mode.dart';
import '../../application/feed_image_preload_service.dart';
import '../../application/feed_state.dart';
import '../../application/messenger_controller.dart';
import '../../application/messenger_remote_mode.dart';
import '../../application/user_identity_controller.dart';
import '../../data/feed_friend_provider.dart';
import '../../data/feed_post_repository.dart';
import '../../data/feed_storage_repository.dart';
import '../../data/user_profile_repository.dart';
import '../../domain/models/feed_contact_model.dart';
import '../../domain/models/feed_create_post_result.dart';
import '../../domain/models/feed_share_target.dart';
import '../../domain/models/chat_model.dart';
import '../../domain/models/message_model.dart';
import '../../domain/models/luma_user_profile_model.dart';
import '../../domain/models/post_model.dart';
import '../../features/stories/application/story_controller.dart';
import '../../features/stories/application/story_moderation_controller.dart';
import '../../features/stories/presentation/screens/create_story_screen.dart';
import '../../features/stories/presentation/screens/story_viewer_screen.dart';
import '../widgets/feed_composer_card.dart';
import 'feed_create_post_screen.dart';
import '../widgets/feed_contact_sidebar.dart';
import '../widgets/feed_remote_comment_bottom_sheet.dart';
import '../widgets/feed_screen_header.dart';
import '../widgets/feed_skeleton_post_card.dart';
import '../widgets/feed_pagination_footer.dart';
import '../widgets/feed_post_animated_entry.dart';
import '../widgets/feed_share_bottom_sheet.dart';
import '../widgets/feed_share_messenger_sheet.dart';
import '../widgets/post_card.dart';
import '../../features/stories/presentation/widgets/story_bar.dart';
import 'profile_screen.dart';

class FeedScreen extends StatefulWidget {
  final String? initialPostId;
  final String? initialCommentId;
  final bool openCommentsOnInitialPost;

  const FeedScreen({
    super.key,
    this.initialPostId,
    this.initialCommentId,
    this.openCommentsOnInitialPost = false,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const double _loadMoreScrollThreshold = 520;
  static const int _maxFeedImageBytes = 10 * 1024 * 1024;
  static const int _maxFeedVideoBytes = 100 * 1024 * 1024;
  static const int _maxOpenMiniChats = 3;

  static const Set<String> _blockedLegacyProfileIds = {
    'current_user',
    'developer_user',
    'mock_user',
    'unknown_user',
  };

  late final FeedController _feedController;
  late final FeedShareService _feedShareService;
  late final FeedFriendProvider _feedFriendProvider;
  late final FeedStorageRepository _feedStorageRepository;
  late final UserProfileRepository _userProfileRepository;
  late final StoryController _storyController;
  late final StoryModerationController _storyModerationController;
  late final TextEditingController _miniChatController;
  late final TextEditingController _contactSearchController;
  late final FocusNode _miniChatFocusNode;
  late final ScrollController _scrollController;
  late final ScrollController _miniChatScrollController;

  final FeedImagePreloadService _imagePreloadService =
      FeedImagePreloadService.instance;

  final UserIdentityController _identityController =
      UserIdentityController.instance;
  final MessengerController _messengerController = MessengerController.instance;

  Timer? _loadMoreDebounce;
  StreamSubscription<Set<String>>? _friendContactSubscription;

  Set<String> _friendContactIds = const <String>{};

  bool _isSubmittingPost = false;
  bool _isSharingPost = false;
  bool _isOpeningStoryComposer = false;
  bool _didHandleInitialTarget = false;
  bool _isLocatingInitialTarget = false;
  bool _didReportMissingInitialTarget = false;
  int _initialTargetLoadAttempts = 0;
  String _lastPreloadSignature = '';

  static const int _maxInitialTargetLoadAttempts = 8;

  final Map<String, GlobalKey> _postKeys = <String, GlobalKey>{};

  FeedContactModel? _selectedFeedContact;
  ChatModel? _selectedMiniChat;
  bool _isMiniChatMinimized = false;
  final List<FeedContactModel> _openMiniChatContacts = <FeedContactModel>[];
  final List<ChatModel> _openMiniChats = <ChatModel>[];
  final Set<String> _deletingPostIds = <String>{};

  FeedContactModel? _lastClosedFeedContact;
  ChatModel? _lastClosedMiniChat;

  @override
  void initState() {
    super.initState();

    _feedController = FeedController(
      remoteMode: FeedRemoteMode.remoteOnly,
    );
    _feedShareService = FeedShareService();
    _feedFriendProvider = FeedFriendProvider();
    _feedStorageRepository = FeedStorageRepository();
    _userProfileRepository = UserProfileRepository();
    _storyController = StoryController();
    _storyModerationController = StoryModerationController();
    _miniChatController = TextEditingController();
    _contactSearchController = TextEditingController();
    _miniChatFocusNode = FocusNode();
    _scrollController = ScrollController();
    _miniChatScrollController = ScrollController();

    _scrollController.addListener(_handleScrollChanged);
    _identityController.addListener(_handleIdentityChanged);
    _messengerController.addListener(_handleMessengerChanged);
    _storyController.addListener(_handleStoryChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _identityController.initialize();

      if (!mounted) return;

      await _configureMessengerRemoteMode();
      await _storyModerationController.initialize();
      await _initializeStoriesForCurrentUser();
      _startFriendContactWatch();
      await _feedController.loadFeed();
    });
  }

  @override
  void dispose() {
    _loadMoreDebounce?.cancel();
    unawaited(_friendContactSubscription?.cancel());
    _friendContactSubscription = null;

    _scrollController.removeListener(_handleScrollChanged);
    _identityController.removeListener(_handleIdentityChanged);
    _messengerController.removeListener(_handleMessengerChanged);
    _storyController.removeListener(_handleStoryChanged);

    _miniChatController.dispose();
    _contactSearchController.dispose();
    _miniChatFocusNode.dispose();
    _scrollController.dispose();
    _miniChatScrollController.dispose();
    _feedController.dispose();
    _storyController.dispose();
    _storyModerationController.dispose();

    super.dispose();
  }

  String get _currentUserId {
    return _identityController.currentUserId?.trim() ?? '';
  }

  String get _currentUsername {
    final profile = _identityController.currentProfile;

    final displayName = profile?.displayName.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final username = profile?.username.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }

    return 'Luma Nutzer';
  }

  String get _currentUserHandle {
    final profile = _identityController.currentProfile;
    final username = profile?.username.trim();

    if (username != null && username.isNotEmpty) {
      return username.startsWith('@') ? username.substring(1) : username;
    }

    final fallback = _currentUsername
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.|\.$'), '');

    return fallback.isEmpty ? 'luma.nutzer' : fallback;
  }

  Future<void> _initializeStoriesForCurrentUser() async {
    final currentUserId = _currentUserId;

    if (currentUserId.isEmpty) {
      return;
    }

    try {
      await _storyController.initialize(currentUserId: currentUserId);
    } catch (error, stackTrace) {
      debugPrint('Luma story initialize failed: $error');
      debugPrint('Luma story initialize stack: $stackTrace');
    }
  }

  String? get _currentUserAvatarUrl {
    final avatarUrl = _identityController.currentProfile?.avatarUrl?.trim();

    if (avatarUrl == null || avatarUrl.isEmpty) return null;

    return avatarUrl;
  }

  List<FeedContactModel> get _messengerFeedContacts {
    final currentUserId = _currentUserId;

    if (currentUserId.isEmpty) {
      return const <FeedContactModel>[];
    }

    if (_friendContactIds.isEmpty) {
      return const <FeedContactModel>[];
    }

    final now = DateTime.now();
    final participants = _messengerController.searchableContacts('');
    final contacts = <FeedContactModel>[];

    for (final participant in participants) {
      final participantUserId = participant.userId.trim();

      if (!_isUsableFirebaseProfileUserId(participantUserId)) continue;
      if (participantUserId == currentUserId) continue;
      if (!_friendContactIds.contains(participantUserId)) continue;

      final chat = _messengerController.directChatWithUser(participantUserId);

      if (chat == null) continue;

      final lastActiveAt = chat.lastMessageAt;
      final wasRecentlyActive =
          now.difference(lastActiveAt) < const Duration(hours: 24);

      final presenceStatus = participant.isOnline
          ? FeedContactPresenceStatus.online
          : wasRecentlyActive
              ? FeedContactPresenceStatus.recentlyActive
              : FeedContactPresenceStatus.offline;

      contacts.add(
        FeedContactModel(
          id: participantUserId,
          displayName: participant.displayName,
          avatarUrl: participant.avatarUrl,
          presenceStatus: presenceStatus,
          lastActiveAt: lastActiveAt,
          unreadCount: chat.unreadCount,
          isVerified: false,
          isAvailableForChat: true,
        ),
      );
    }

    contacts.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      if (a.isRecentlyActive != b.isRecentlyActive) {
        return a.isRecentlyActive ? -1 : 1;
      }
      return a.safeDisplayName.toLowerCase().compareTo(
            b.safeDisplayName.toLowerCase(),
          );
    });

    return List.unmodifiable(contacts);
  }

  void _startFriendContactWatch() {
    final currentUserId = _currentUserId;

    unawaited(_friendContactSubscription?.cancel());
    _friendContactSubscription = null;

    if (currentUserId.isEmpty) {
      if (_friendContactIds.isNotEmpty) {
        setState(() {
          _friendContactIds = const <String>{};
          _clearOpenMiniChatsBecauseFriendshipScopeChanged();
        });
      }
      return;
    }

    _friendContactSubscription = _feedFriendProvider
        .watchFriendUserIds(userId: currentUserId)
        .listen(
      (friendUserIds) {
        if (!mounted) return;

        final cleanedFriendUserIds = friendUserIds
            .map((userId) => userId.trim())
            .where(_isUsableFirebaseProfileUserId)
            .where((userId) => userId != currentUserId)
            .toSet();

        setState(() {
          _friendContactIds = Set.unmodifiable(cleanedFriendUserIds);
          _closeMiniChatsForRemovedFriends();
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Luma feed friend contact watch failed: $error');
        debugPrint('Luma feed friend contact watch stack: $stackTrace');

        if (!mounted) return;

        setState(() {
          _friendContactIds = const <String>{};
          _clearOpenMiniChatsBecauseFriendshipScopeChanged();
        });
      },
    );
  }

  void _clearOpenMiniChatsBecauseFriendshipScopeChanged() {
    for (final chat in _openMiniChats) {
      _messengerController.closeChat(chat.id);
    }

    _openMiniChatContacts.clear();
    _openMiniChats.clear();
    _selectedFeedContact = null;
    _selectedMiniChat = null;
    _lastClosedFeedContact = null;
    _lastClosedMiniChat = null;
    _isMiniChatMinimized = false;
  }

  void _closeMiniChatsForRemovedFriends() {
    for (var index = _openMiniChats.length - 1; index >= 0; index--) {
      final contact = _openMiniChatContacts[index];

      if (_friendContactIds.contains(contact.id)) continue;

      final chat = _openMiniChats[index];
      _messengerController.closeChat(chat.id);
      _openMiniChats.removeAt(index);
      _openMiniChatContacts.removeAt(index);

      if (_selectedMiniChat?.id == chat.id) {
        _selectedFeedContact = null;
        _selectedMiniChat = null;
        _isMiniChatMinimized = false;
      }

      if (_lastClosedMiniChat?.id == chat.id) {
        _lastClosedFeedContact = null;
        _lastClosedMiniChat = null;
      }
    }
  }

  void _handleIdentityChanged() {
    if (!mounted) return;

    unawaited(_configureMessengerRemoteMode());
    unawaited(_initializeStoriesForCurrentUser());
    _startFriendContactWatch();

    setState(() {});
  }

  Future<void> _configureMessengerRemoteMode() async {
    final currentUserId = _currentUserId;

    if (currentUserId.isEmpty) {
      await _messengerController.configureRemoteMode(
        mode: MessengerRemoteMode.remoteOnly,
      );
      return;
    }

    await _messengerController.configureRemoteMode(
      mode: MessengerRemoteMode.remoteOnly,
      currentUserId: currentUserId,
    );
  }

  void _handleStoryChanged() {
    if (!mounted) return;

    setState(() {});
  }

  void _handleMessengerChanged() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {});
      _scheduleMiniChatScrollToBottom();
    });
  }


  void _handleScrollChanged() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    if (_isSubmittingPost) return;
    if (_loadMoreDebounce?.isActive == true) return;

    final position = _scrollController.position;

    if (!position.hasPixels || !position.hasContentDimensions) return;

    final distanceToBottom = position.maxScrollExtent - position.pixels;

    if (distanceToBottom > _loadMoreScrollThreshold) return;
    if (!_feedController.hasMorePosts) return;
    if (_feedController.isLoadingMore) return;
    if (_feedController.state.isAnyLoading) return;

    _loadMoreDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      if (!_feedController.hasMorePosts) return;
      if (_feedController.isLoadingMore) return;
      if (_feedController.state.isAnyLoading) return;

      unawaited(_feedController.loadMorePosts());
    });
  }

  PostVisibility _postVisibilityFromCreateResult(FeedCreatePostResult result) {
    switch (result.visibilityLabel.trim().toLowerCase()) {
      case 'nur ich':
        return PostVisibility.private;
      case 'freunde':
        return PostVisibility.friends;
      case 'öffentlich':
      default:
        return PostVisibility.public;
    }
  }

  String _contentTypeForImageName(String? imageName) {
    final value = imageName?.trim().toLowerCase() ?? '';

    if (value.endsWith('.png')) return 'image/png';
    if (value.endsWith('.webp')) return 'image/webp';
    if (value.endsWith('.jpg') || value.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (value.isNotEmpty && value.contains('.')) {
      throw StateError('unsupported-feed-image-format');
    }

    return 'image/jpeg';
  }

  String _createPostErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unauthorized':
        case 'permission-denied':
          return 'Das Foto konnte wegen fehlender Berechtigung nicht '
              'hochgeladen werden. Bitte melde dich erneut an.';
        case 'canceled':
          return 'Der Upload wurde abgebrochen.';
        case 'retry-limit-exceeded':
          return 'Der Upload dauert zu lange. Prüfe deine Verbindung und '
              'versuche es erneut.';
        case 'quota-exceeded':
          return 'Der Bildspeicher ist momentan nicht verfügbar.';
        case 'object-not-found':
          return 'Das hochgeladene Foto konnte nicht mehr gefunden werden.';
        case 'upload-incomplete':
        case 'missing-download-url':
          return 'Das Foto wurde nicht vollständig hochgeladen. '
              'Bitte versuche es erneut.';
        default:
          return 'Das Foto konnte gerade nicht hochgeladen werden.';
      }
    }

    final message = error.toString();

    if (message.contains('unsupported-feed-image-format')) {
      return 'Dieses Bildformat wird noch nicht unterstützt. '
          'Bitte verwende JPG, PNG oder WebP.';
    }

    if (message.contains('exceeds local upload size limit') ||
        message.contains('maximal 10 MB')) {
      return 'Dieses Foto ist größer als 10 MB. '
          'Bitte wähle ein kleineres Foto.';
    }

    return 'Dein Beitrag konnte gerade nicht gespeichert werden.';
  }

  String _contentTypeForVideoName(String? videoName) {
    final value = videoName?.trim().toLowerCase() ?? '';

    if (value.endsWith('.mov')) return 'video/quicktime';
    if (value.endsWith('.webm')) return 'video/webm';
    if (value.endsWith('.mpeg')) return 'video/mpeg';
    if (value.endsWith('.mp4') || value.endsWith('.m4v')) return 'video/mp4';

    return 'video/mp4';
  }

  Future<void> _openCreatePostScreen() async {
    if (_isSubmittingPost) return;

    if (_currentUserId.isEmpty) {
      _showMessage('Melde dich an, um etwas zu teilen.');
      return;
    }

    final result = await Navigator.of(context).push<FeedCreatePostResult>(
      MaterialPageRoute<FeedCreatePostResult>(
        builder: (_) => FeedCreatePostScreen(
          currentUsername: _currentUsername,
          currentUserAvatarUrl: _currentUserAvatarUrl,
        ),
      ),
    );

    if (!mounted || result == null) return;

    await _submitCreatePostResult(result);
  }

  Future<FeedImageUploadResult?> _uploadCreatePostImage({
    required FeedCreatePostResult result,
    required String reservedPostId,
  }) async {
    final imageBytes = result.imageBytes;

    if (imageBytes == null || imageBytes.isEmpty) {
      return null;
    }

    if (imageBytes.length > _maxFeedImageBytes) {
      throw StateError('Feed image exceeds local upload size limit: 10 MB.');
    }

    return _feedStorageRepository.uploadFeedImageBytesWithResult(
      userId: _currentUserId,
      postId: reservedPostId,
      bytes: imageBytes,
      contentType: _contentTypeForImageName(result.imageName),
    );
  }

  Future<FeedMediaUploadResult?> _uploadCreatePostVideo({
    required FeedCreatePostResult result,
    required String reservedPostId,
  }) async {
    final videoBytes = result.videoBytes;

    if (videoBytes == null || videoBytes.isEmpty) {
      return null;
    }

    if (videoBytes.length > _maxFeedVideoBytes) {
      throw StateError('Feed video exceeds local upload size limit.');
    }

    return _feedStorageRepository.uploadFeedVideoBytesWithResult(
      userId: _currentUserId,
      postId: reservedPostId,
      bytes: videoBytes,
      contentType: _contentTypeForVideoName(result.videoName),
    );
  }

  Future<void> _submitCreatePostResult(FeedCreatePostResult result) async {
    if (_currentUserId.isEmpty) {
      _showMessage('Melde dich an, um etwas zu teilen.');
      return;
    }

    if (!result.hasText && !result.hasImage && !result.hasVideo) return;
    if (_isSubmittingPost) return;

    setState(() {
      _isSubmittingPost = true;
    });

    final reservedPostId = 'post_${DateTime.now().microsecondsSinceEpoch}';
    FeedImageUploadResult? uploadedImageResult;
    FeedMediaUploadResult? uploadedVideoResult;

    try {
      uploadedImageResult = await _uploadCreatePostImage(
        result: result,
        reservedPostId: reservedPostId,
      );
      uploadedVideoResult = await _uploadCreatePostVideo(
        result: result,
        reservedPostId: reservedPostId,
      );

      if (!mounted) return;

      final didCreatePost = await _feedController.createPost(
        postId: reservedPostId,
        text: result.text,
        imageUrl: uploadedImageResult?.downloadUrl,
        imageStoragePath: uploadedImageResult?.storagePath,
        videoUrl: uploadedVideoResult?.downloadUrl,
        videoStoragePath: uploadedVideoResult?.storagePath,
        mood: result.mood,
        taggedFriends: result.taggedFriends,
        locationLabel: result.locationLabel,
        visibility: _postVisibilityFromCreateResult(result),
      );

      if (!mounted) return;

      if (!didCreatePost) {
        if (uploadedImageResult != null &&
            uploadedImageResult.downloadUrl.trim().isNotEmpty) {
          unawaited(
            _feedStorageRepository.deleteFeedImage(
              userId: _currentUserId,
              postId: reservedPostId,
            ),
          );
        }
        if (uploadedVideoResult != null &&
            uploadedVideoResult.downloadUrl.trim().isNotEmpty) {
          unawaited(
            _feedStorageRepository.deleteFeedVideo(
              userId: _currentUserId,
              postId: reservedPostId,
            ),
          );
        }

        setState(() {
          _isSubmittingPost = false;
        });

        _showMessage('Dein Beitrag konnte gerade nicht veröffentlicht werden.');
        return;
      }

      setState(() {
        _isSubmittingPost = false;
      });

      _showMessage('Dein Beitrag ist online.');
    } catch (error, stackTrace) {
      debugPrint('Luma feed create post screen submit failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (uploadedImageResult != null &&
          uploadedImageResult.downloadUrl.trim().isNotEmpty) {
        unawaited(
          _feedStorageRepository.deleteFeedImage(
            userId: _currentUserId,
            postId: reservedPostId,
          ),
        );
      }
      if (uploadedVideoResult != null &&
          uploadedVideoResult.downloadUrl.trim().isNotEmpty) {
        unawaited(
          _feedStorageRepository.deleteFeedVideo(
            userId: _currentUserId,
            postId: reservedPostId,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _isSubmittingPost = false;
      });

      _showMessage(_createPostErrorMessage(error));
    }
  }

  Future<void> _refreshFeed() async {
    _loadMoreDebounce?.cancel();
    unawaited(_friendContactSubscription?.cancel());
    _friendContactSubscription = null;
    _startFriendContactWatch();

    final currentUserId = _currentUserId;
    if (currentUserId.isNotEmpty) {
      await _storyController.initialize(currentUserId: currentUserId);
    }

    await _feedController.loadFeed();
  }

  void _handleRemoteCommentCreated(String postId) {
    FeedCommentPreviewCache.instance.invalidatePost(postId);
  }

  void _handleRemoteCommentDeleted(String postId) {
    FeedCommentPreviewCache.instance.invalidatePost(postId);
  }

  Future<void> _loadMorePosts() async {
    _loadMoreDebounce?.cancel();

    if (_feedController.isLoadingMore) return;
    if (_feedController.state.isAnyLoading) return;
    if (!_feedController.hasMorePosts) return;

    await _feedController.loadMorePosts();
  }

  Future<void> _deleteFeedImageForDeletedOwnPost(PostModel post) async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty) return;

    final postOwnerId = post.userId.trim().isNotEmpty
        ? post.userId.trim()
        : post.authorId.trim();

    if (postOwnerId != currentUserId) return;

    final imageStoragePath = post.imageStoragePath?.trim();
    final imageUrl = post.imageUrl?.trim();
    final videoStoragePath = post.videoStoragePath?.trim();

    try {
      if (videoStoragePath != null && videoStoragePath.isNotEmpty) {
        await _feedStorageRepository.deleteFeedVideoByStoragePath(
          userId: currentUserId,
          storagePath: videoStoragePath,
        );
      }

      if (imageStoragePath != null && imageStoragePath.isNotEmpty) {
        final didDeleteByPath =
            await _feedStorageRepository.deleteFeedImageByStoragePath(
          userId: currentUserId,
          storagePath: imageStoragePath,
        );

        if (didDeleteByPath) return;
      }

      if (imageUrl == null || imageUrl.isEmpty) return;

      final didDeleteByUrl =
          await _feedStorageRepository.deleteFeedImageByDownloadUrl(
        userId: currentUserId,
        imageUrl: imageUrl,
      );

      if (!didDeleteByUrl) {
        debugPrint(
          'Luma feed image cleanup skipped: image is not an owned feed image.',
        );
      }
    } catch (error) {
      debugPrint('Luma feed image cleanup failed after post delete: $error');
    }
  }

  void _openRemoteComments(
    PostModel post, {
    String? highlightedCommentId,
  }) {
    if (_currentUserId.isEmpty) {
      _showMessage('Kommentare benötigen eine aktive Anmeldung.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return FeedRemoteCommentBottomSheet(
          postId: post.id,
          postUsername: post.username,
          postOwnerId: post.userId.trim().isNotEmpty
              ? post.userId.trim()
              : post.authorId.trim(),
          currentUserId: _currentUserId,
          currentUsername: _currentUsername,
          currentUserAvatarUrl: _currentUserAvatarUrl,
          highlightedCommentId: highlightedCommentId,
          onCommentCreated: () => _handleRemoteCommentCreated(post.id),
          onCommentDeleted: () => _handleRemoteCommentDeleted(post.id),
        );
      },
    );
  }


  String _buildMessengerPostShareText(PostModel post) {
    final rawAuthor = post.isRepost
        ? post.originalUsername?.trim()
        : post.username.trim();
    final author = rawAuthor == null || rawAuthor.isEmpty
        ? 'Luma Nutzer'
        : rawAuthor;

    final rawText = post.isRepost
        ? post.originalContentText?.trim()
        : post.contentText.trim();

    final preview = rawText == null || rawText.isEmpty
        ? post.hasImage || post.hasOriginalImage
            ? 'Fotobeitrag'
            : post.hasVideo || post.hasOriginalVideo
                ? 'Videobeitrag'
                : 'Beitrag'
        : rawText.length <= 180
            ? rawText
            : '${rawText.substring(0, 177)}...';

    final postUrl =
        'https://luma-social.com/?postId=${Uri.encodeComponent(post.id)}';

    return 'Beitrag von $author\n$preview\n$postUrl';
  }

  Future<void> _sharePostViaMessenger(PostModel post) async {
    final selectedChatIds = await FeedShareMessengerSheet.show(
      context,
      chats: _messengerController.chats,
    );

    if (!mounted || selectedChatIds == null || selectedChatIds.isEmpty) {
      return;
    }

    final sentCount = await _messengerController.sendTextToChats(
      chatIds: selectedChatIds,
      text: _buildMessengerPostShareText(post),
    );

    if (!mounted) return;

    _showMessage(
      sentCount <= 0
          ? 'Der Beitrag konnte an keinen Chat gesendet werden.'
          : sentCount == 1
              ? 'Beitrag wurde an 1 Chat gesendet.'
              : 'Beitrag wurde an $sentCount Chats gesendet.',
    );
  }

  FeedShareTarget _mapShareDestination(
    FeedShareDestination destination,
  ) {
    switch (destination) {
      case FeedShareDestination.feed:
        return FeedShareTarget.feed;
      case FeedShareDestination.profile:
        return FeedShareTarget.profile;
      case FeedShareDestination.messenger:
        throw StateError(
          'Messenger-Ziel darf nicht als Feed-Repost gespeichert werden.',
        );
    }
  }

  Future<void> _openShareOptions(PostModel post) async {
    if (_isSharingPost) return;

    if (_currentUserId.isEmpty) {
      _showMessage('Du musst angemeldet sein, um einen Beitrag zu teilen.');
      return;
    }

    final result = await FeedShareBottomSheet.show(
      context,
      post: post,
      currentUsername: _currentUsername,
      currentUserAvatarUrl: _currentUserAvatarUrl,
    );

    if (!mounted || result == null) return;

    if (result.destination == FeedShareDestination.messenger) {
      await _sharePostViaMessenger(post);
      return;
    }

    setState(() {
      _isSharingPost = true;
    });

    try {
      final shareTarget = _mapShareDestination(result.destination);

      final sharedPost = await _feedShareService.sharePost(
        sourcePost: post,
        currentUserId: _currentUserId,
        currentUsername: _currentUsername,
        currentUserAvatarUrl: _currentUserAvatarUrl,
        target: shareTarget,
        shareText: result.shareText,
        visibility: result.visibility,
      );

      if (!mounted) return;

      // Der erfolgreich gespeicherte Repost wird lokal sofort ganz oben
      // eingefügt. Ein vollständiger Feed-Reload ist nicht mehr nötig.
      _feedController.insertPostAtTop(sharedPost);

      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          ),
        );
      }

      _showMessage(
        'Beitrag wurde ${result.destination.successLabel} geteilt.',
      );
    } catch (error, stackTrace) {
      debugPrint('Luma share post error: $error');
      debugPrint('Luma share post stack: $stackTrace');

      if (!mounted) return;

      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'Der Beitrag konnte nicht gespeichert werden.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingPost = false;
        });
      }
    }
  }

  void _openPostLikes(PostModel post) {
    final postId = post.id.trim();

    if (postId.isEmpty || post.likeCount <= 0) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (sheetContext) {
        return _FeedPostLikesSheet(
          post: post,
          future: _feedController.loadPostLikeUsers(postId),
          onOpenProfile: (likeUser) {
            final userId = likeUser.userId.trim();

            if (!_isUsableFirebaseProfileUserId(userId)) {
              return;
            }

            Navigator.of(sheetContext).pop();

            _openProfile(
              isOwnProfile: userId == _currentUserId,
              userId: userId,
            );
          },
        );
      },
    );
  }

  void _openAuthorPreview(PostModel post) {
    final fallbackUsername =
        post.username.trim().isEmpty ? 'Luma Nutzer' : post.username.trim();

    final authorUserId = _resolveFirebaseProfileUserId(post);
    final canOpenFirebaseProfile = authorUserId != null;
    final isOwnProfile =
        canOpenFirebaseProfile && authorUserId == _currentUserId;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FutureBuilder<LumaUserProfileModel?>(
              future: canOpenFirebaseProfile
                  ? _userProfileRepository.fetchProfile(userId: authorUserId)
                  : Future<LumaUserProfileModel?>.value(null),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final isLoading = snapshot.connectionState ==
                        ConnectionState.waiting &&
                    canOpenFirebaseProfile;

                return _AuthorPreviewCard(
                  fallbackUsername: fallbackUsername,
                  fallbackAvatarUrl: post.userAvatarUrl,
                  profile: profile,
                  isLoading: isLoading,
                  isOwnProfile: isOwnProfile,
                  canOpenFirebaseProfile: canOpenFirebaseProfile,
                  onClose: () => Navigator.of(dialogContext).pop(),
                  onOpenProfile: !canOpenFirebaseProfile
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                          _openProfile(
                            isOwnProfile: isOwnProfile,
                            userId: authorUserId,
                          );
                        },
                );
              },
            ),
          ),
        );
      },
    );
  }

  String? _resolveFirebaseProfileUserId(PostModel post) {
    final authorId = post.authorId.trim();
    final userId = post.userId.trim();

    if (_isUsableFirebaseProfileUserId(authorId)) return authorId;
    if (_isUsableFirebaseProfileUserId(userId)) return userId;

    debugPrint(
      'Luma feed profile routing blocked invalid author id. '
      'postId=${post.id}, authorId=${post.authorId}, userId=${post.userId}',
    );

    return null;
  }

  bool _isUsableFirebaseProfileUserId(String value) {
    final cleanedValue = value.trim();

    if (cleanedValue.isEmpty) return false;
    if (_blockedLegacyProfileIds.contains(cleanedValue)) return false;

    if (cleanedValue.startsWith('user_')) return false;
    if (cleanedValue.startsWith('mock_')) return false;
    if (cleanedValue.startsWith('suggestion_')) return false;
    if (cleanedValue.startsWith('activity_')) return false;
    if (cleanedValue.startsWith('interest_')) return false;
    if (cleanedValue.startsWith('post_')) return false;
    if (cleanedValue.startsWith('shared_')) return false;

    return true;
  }

  String _buildInitials(String username) {
    final parts = username
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'LU';

    if (parts.length == 1) {
      final value = parts.first;

      return value.length >= 2
          ? value.substring(0, 2).toUpperCase()
          : value.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  void _openProfile({
    required bool isOwnProfile,
    required String userId,
  }) {
    if (!mounted) return;

    final cleanedUserId = userId.trim();
    if (!_isUsableFirebaseProfileUserId(cleanedUserId)) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          isOwnProfile: isOwnProfile,
          userId: cleanedUserId,
        ),
      ),
    );
  }

  GlobalKey _postKeyFor(String postId) {
    return _postKeys.putIfAbsent(
      postId,
      () => GlobalKey(debugLabel: 'feed-post-$postId'),
    );
  }

  void _handleInitialNotificationTarget(List<PostModel> posts) {
    if (_didHandleInitialTarget || _isLocatingInitialTarget) {
      return;
    }

    final initialPostId = widget.initialPostId?.trim() ?? '';

    if (initialPostId.isEmpty ||
        initialPostId == 'unknown' ||
        initialPostId == 'null') {
      _didHandleInitialTarget = true;
      return;
    }

    PostModel? targetPost;

    for (final post in posts) {
      if (post.id.trim() == initialPostId) {
        targetPost = post;
        break;
      }
    }

    if (targetPost != null) {
      _didHandleInitialTarget = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final targetContext = _postKeyFor(initialPostId).currentContext;

        if (targetContext != null) {
          await Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            alignment: 0.12,
          );
        }

        if (!mounted || !widget.openCommentsOnInitialPost) {
          return;
        }

        await Future<void>.delayed(
          const Duration(milliseconds: 160),
        );

        if (!mounted) return;

        _openRemoteComments(
          targetPost!,
          highlightedCommentId: widget.initialCommentId,
        );
      });
      return;
    }

    final canLoadMore = _feedController.hasMorePosts &&
        !_feedController.isLoadingMore &&
        !_feedController.state.isAnyLoading &&
        _initialTargetLoadAttempts < _maxInitialTargetLoadAttempts;

    if (canLoadMore) {
      _isLocatingInitialTarget = true;
      _initialTargetLoadAttempts++;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _feedController.loadMorePosts();
        } finally {
          _isLocatingInitialTarget = false;
        }
      });
      return;
    }

    if (_feedController.state.isAnyLoading ||
        _feedController.isLoadingMore) {
      return;
    }

    _didHandleInitialTarget = true;

    if (_didReportMissingInitialTarget) {
      return;
    }

    _didReportMissingInitialTarget = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _showMessage(
        widget.openCommentsOnInitialPost
            ? 'Der Beitrag oder Kommentar ist nicht mehr verfügbar.'
            : 'Dieser Beitrag ist nicht mehr verfügbar.',
      );
    });
  }

  Future<void> _openCreateStoryEntryPoint() async {
    if (_isOpeningStoryComposer) return;

    final currentUserId = _currentUserId;

    if (currentUserId.isEmpty) {
      _showMessage('Du musst angemeldet sein, um eine Story zu erstellen.');
      return;
    }

    setState(() {
      _isOpeningStoryComposer = true;
    });

    try {
      final didCreateStory = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => CreateStoryScreen(
            currentUserId: currentUserId,
            currentUserName: _currentUsername,
            currentUsername: _currentUserHandle,
            currentUserProfileImageUrl: _currentUserAvatarUrl,
            controller: _storyController,
          ),
        ),
      );

      if (!mounted) return;

      if (didCreateStory == true) {
        await _storyController.initialize(currentUserId: currentUserId);

        if (!mounted) return;

        _showMessage('Story wurde veröffentlicht.');
      }
    } catch (error, stackTrace) {
      debugPrint('Luma open/create story failed: $error');
      debugPrint('Luma open/create story stack: $stackTrace');

      if (!mounted) return;

      _showMessage('Story-Erstellung konnte nicht geöffnet werden.');
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningStoryComposer = false;
        });
      }
    }
  }

  Future<void> _openStoryPreviewFromHeader(int storyIndex) async {
    if (!mounted) return;

    final currentUserId = _currentUserId;

    if (currentUserId.isEmpty) {
      _showMessage('Du musst angemeldet sein, um Storys anzusehen.');
      return;
    }

    final groups = _storyController.state.storyGroups
        .where((group) => group.stories.isNotEmpty)
        .toList(growable: false);

    if (groups.isEmpty) {
      _showMessage('Aktuell sind keine Storys verfügbar.');
      return;
    }

    final safeIndex = storyIndex.clamp(0, groups.length - 1);

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StoryViewerScreen(
            storyGroups: groups,
            initialGroupIndex: safeIndex,
            currentUserId: currentUserId,
            controller: _storyController,
            moderationController: _storyModerationController,
          ),
        ),
      );

      if (!mounted) return;

      await _storyController.initialize(
        currentUserId: currentUserId,
      );
    } catch (error, stackTrace) {
      debugPrint('Luma open story viewer failed: $error');
      debugPrint('Luma open story viewer stack: $stackTrace');

      if (!mounted) return;

      _showMessage('Story konnte nicht geöffnet werden.');
    }
  }

  Future<bool> _confirmPermanentPostDeletion(
    PostModel post,
  ) async {
    final postId = post.id.trim();

    if (postId.isEmpty || _deletingPostIds.contains(postId)) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _DeletePostConfirmationDialog(
          post: post,
        );
      },
    );

    return result == true;
  }

  Future<void> _deletePostWithConfirmation(
    PostModel post,
  ) async {
    final postId = post.id.trim();

    if (postId.isEmpty || _deletingPostIds.contains(postId)) {
      return;
    }

    final confirmed = await _confirmPermanentPostDeletion(post);

    if (!mounted || !confirmed) return;

    setState(() {
      _deletingPostIds.add(postId);
    });

    try {
      final didDelete = await _feedController.deleteOwnPost(postId);

      if (didDelete) {
        unawaited(_deleteFeedImageForDeletedOwnPost(post));
      }

      if (!mounted) return;

      _showMessage(
        didDelete
            ? 'Beitrag wurde dauerhaft gelöscht.'
            : 'Beitrag konnte nicht gelöscht werden.',
      );
    } catch (error, stackTrace) {
      debugPrint('Luma feed delete post failed: $error');
      debugPrint('Luma feed delete post stack: $stackTrace');

      if (!mounted) return;

      _showMessage('Beitrag konnte nicht gelöscht werden.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingPostIds.remove(postId);
        });
      } else {
        _deletingPostIds.remove(postId);
      }
    }
  }

  void _showPostOptions(PostModel post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final isOwnPost =
            post.userId == _currentUserId || post.authorId == _currentUserId;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PostOptionTile(
                    icon: Icons.trending_up_rounded,
                    title: 'Mehr davon',
                    subtitle: 'Stärkt diesen Inhalt im lokalen Ranking.',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _feedController.registerMoreLikeThis(post.id);
                    },
                  ),
                  _PostOptionTile(
                    icon: Icons.trending_down_rounded,
                    title: 'Weniger davon',
                    subtitle: 'Reduziert ähnliche Inhalte im lokalen Ranking.',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _feedController.registerLessLikeThis(post.id);
                    },
                  ),
                  if (isOwnPost) ...[
                    const SizedBox(height: 6),
                    Divider(
                      height: 1,
                      color: colorScheme.outline.withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: 6),
                    _PostOptionTile(
                      icon: Icons.delete_forever_outlined,
                      title: _deletingPostIds.contains(post.id.trim())
                          ? 'Beitrag wird gelöscht ...'
                          : 'Beitrag löschen',
                      subtitle:
                          'Erfordert eine Bestätigung und kann nicht rückgängig gemacht werden.',
                      isDanger: true,
                      onTap: _deletingPostIds.contains(post.id.trim())
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(_deletePostWithConfirmation(post));
                            },
                    ),
                  ],
                  _PostOptionTile(
                    icon: Icons.visibility_off_rounded,
                    title: 'Beitrag ausblenden',
                    subtitle: 'Blendet den Beitrag lokal aus dem Feed aus.',
                    isDanger: true,
                    onTap: () {
                      Navigator.of(sheetContext).pop();

                      final result = _feedController.hidePost(post.id);
                      if (result == null || !mounted) return;

                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Beitrag wurde ausgeblendet.'),
                          action: SnackBarAction(
                            label: 'Rückgängig',
                            onPressed: () {
                              _feedController.restoreHiddenPost(result);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleFeedContactTap(FeedContactModel contact) async {
    if (!mounted) return;

    final contactId = contact.id.trim();

    if (!_isUsableFirebaseProfileUserId(contactId) ||
        !_friendContactIds.contains(contactId)) {
      _showMessage('Dieser Kontakt ist nicht mehr in deiner Freundesliste.');
      return;
    }

    setState(() {
      _selectedFeedContact = contact;
    });

    try {
      final chat = await _messengerController.openOrCreateDirectChat(
        ChatParticipantModel(
          userId: contact.id,
          displayName: contact.safeDisplayName,
          avatarUrl: contact.safeAvatarUrl ?? '',
          isOnline: contact.isOnline,
        ),
        currentUserPreview: ChatParticipantModel(
          userId: _currentUserId,
          displayName: _currentUsername,
          avatarUrl: _currentUserAvatarUrl ?? '',
          isOnline: true,
        ),
      );

      if (!mounted) return;

      _messengerController.openChat(chat.id);

      setState(() {
        _rememberOpenMiniChat(
          contact: contact,
          chat: chat,
        );
        _selectedFeedContact = contact;
        _selectedMiniChat = chat;
        _isMiniChatMinimized = false;
      });

      _scheduleMiniChatScrollToBottom();
      _focusMiniChatInput();
    } catch (error) {
      if (!mounted) return;

      debugPrint('Luma feed mini chat open failed: $error');
      _showMessage('Chat konnte nicht geöffnet werden.');
    }
  }

  void _rememberOpenMiniChat({
    required FeedContactModel contact,
    required ChatModel chat,
  }) {
    final existingIndex =
        _openMiniChats.indexWhere((openChat) => openChat.id == chat.id);

    if (existingIndex >= 0) {
      _openMiniChats.removeAt(existingIndex);
      _openMiniChatContacts.removeAt(existingIndex);
    }

    _openMiniChatContacts.add(contact);
    _openMiniChats.add(chat);

    while (_openMiniChats.length > _maxOpenMiniChats) {
      final removedChat = _openMiniChats.removeAt(0);
      _openMiniChatContacts.removeAt(0);

      if (_selectedMiniChat?.id != removedChat.id) {
        _messengerController.closeChat(removedChat.id);
      }
    }
  }

  List<_MiniChatStackEntry> get _openMiniChatEntries {
    final entries = <_MiniChatStackEntry>[];

    for (var index = 0; index < _openMiniChats.length; index++) {
      if (index >= _openMiniChatContacts.length) break;

      entries.add(
        _MiniChatStackEntry(
          contact: _openMiniChatContacts[index],
          chat: _openMiniChats[index],
        ),
      );
    }

    return entries;
  }

  List<_MiniChatStackEntry> get _collapsedMiniChatEntries {
    final selectedChatId = _selectedMiniChat?.id;

    return _openMiniChatEntries
        .where((entry) => entry.chat.id != selectedChatId)
        .toList(growable: false);
  }

  String _previewTextForChat(ChatModel chat) {
    if (_messengerController.isParticipantTypingInChat(chat.id)) {
      return 'schreibt gerade ...';
    }

    return _messengerController.conversationPreviewText(chat);
  }

  bool _isTypingForChat(ChatModel chat) {
    return _messengerController.isParticipantTypingInChat(chat.id);
  }

  void _activateMiniChatEntry(_MiniChatStackEntry entry) {
    if (!mounted) return;

    _messengerController.openChat(entry.chat.id);

    setState(() {
      _selectedFeedContact = entry.contact;
      _selectedMiniChat = entry.chat;
      _isMiniChatMinimized = false;
    });

    _scheduleMiniChatScrollToBottom();
    _focusMiniChatInput();
  }

  void _closeMiniChatEntry(_MiniChatStackEntry entry) {
    if (!mounted) return;

    _messengerController.closeChat(entry.chat.id);

    final closedContact = entry.contact;
    final closedChat = entry.chat;
    final wasSelected = _selectedMiniChat?.id == entry.chat.id;

    setState(() {
      final index = _openMiniChats.indexWhere(
        (openChat) => openChat.id == entry.chat.id,
      );

      if (index >= 0) {
        _openMiniChats.removeAt(index);
        _openMiniChatContacts.removeAt(index);
      }

      _lastClosedFeedContact = closedContact;
      _lastClosedMiniChat = closedChat;

      if (wasSelected) {
        if (_openMiniChats.isEmpty) {
          _selectedFeedContact = null;
          _selectedMiniChat = null;
          _isMiniChatMinimized = false;
        } else {
          final nextIndex = _openMiniChats.length - 1;
          _selectedFeedContact = _openMiniChatContacts[nextIndex];
          _selectedMiniChat = _openMiniChats[nextIndex];
          _isMiniChatMinimized = true;
        }
      }
    });
  }

  void _focusMiniChatInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _miniChatFocusNode.requestFocus();
    });
  }

  List<MessageModel> get _selectedMiniChatMessages {
    final chat = _selectedMiniChat;
    if (chat == null) return const <MessageModel>[];

    return _messengerController.messagesForChat(chat.id);
  }

  bool get _isSelectedMiniChatTyping {
    final chat = _selectedMiniChat;
    if (chat == null) return false;

    return _messengerController.isParticipantTypingInChat(chat.id);
  }

  String get _selectedMiniChatPreviewText {
    final chat = _selectedMiniChat;
    if (chat == null) return 'Chat öffnen';

    if (_messengerController.isParticipantTypingInChat(chat.id)) {
      return 'schreibt gerade ...';
    }

    return _messengerController.conversationPreviewText(chat);
  }

  void _scheduleMiniChatScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_miniChatScrollController.hasClients) return;

      final position = _miniChatScrollController.position;
      if (!position.hasContentDimensions) return;

      final targetOffset = position.maxScrollExtent;
      if (targetOffset <= 0) return;

      _miniChatScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _closeMiniChat() {
    if (!mounted) return;

    final contact = _selectedFeedContact;
    final chat = _selectedMiniChat;

    _miniChatController.clear();
    _miniChatFocusNode.unfocus();

    if (contact == null || chat == null) {
      setState(() {
        _selectedFeedContact = null;
        _selectedMiniChat = null;
        _isMiniChatMinimized = false;
      });
      return;
    }

    _closeMiniChatEntry(
      _MiniChatStackEntry(
        contact: contact,
        chat: chat,
      ),
    );
  }

  void _minimizeMiniChat() {
    if (!mounted) return;

    _miniChatFocusNode.unfocus();

    setState(() {
      _isMiniChatMinimized = true;
    });
  }

  void _restoreMiniChat() {
    if (!mounted) return;

    setState(() {
      _isMiniChatMinimized = false;
    });

    _scheduleMiniChatScrollToBottom();
    _miniChatFocusNode.requestFocus();
  }

  void _reopenLastMiniChat() {
    if (!mounted) return;

    final lastContact = _lastClosedFeedContact;
    final lastChat = _lastClosedMiniChat;

    if (lastContact == null || lastChat == null) {
      _showMessage('Kein zuletzt geschlossener Chat vorhanden.');
      return;
    }

    _messengerController.openChat(lastChat.id);

    setState(() {
      _rememberOpenMiniChat(
        contact: lastContact,
        chat: lastChat,
      );
      _selectedFeedContact = lastContact;
      _selectedMiniChat = lastChat;
      _isMiniChatMinimized = false;
      _lastClosedFeedContact = null;
      _lastClosedMiniChat = null;
    });

    _focusMiniChatInput();
    _scheduleMiniChatScrollToBottom();
  }

  void _sendMiniChatMessage() {
    final chat = _selectedMiniChat;
    if (chat == null) return;

    final text = _miniChatController.text.trim();
    if (text.isEmpty) return;

    _miniChatController.clear();

    unawaited(
      _messengerController.sendMessage(
        chatId: chat.id,
        text: text,
      ),
    );

    _scheduleMiniChatScrollToBottom();
  }

  void _openMessengerFromSidebar() {
    _showMessage('Messenger-Schnellzugriff wird später sauber verbunden.');
  }

  void _scheduleVisibleFeedImagePreload(List<PostModel> posts) {
    if (!mounted || posts.isEmpty) return;

    final signature = posts
        .take(8)
        .map((post) {
          return [
            post.id.trim(),
            post.imageUrl?.trim() ?? '',
            post.originalImageUrl?.trim() ?? '',
            post.userAvatarUrl?.trim() ?? '',
          ].join('|');
        })
        .join('||');

    if (signature == _lastPreloadSignature) return;

    _lastPreloadSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _imagePreloadService.preloadPosts(
        context,
        posts,
        postLimit: 8,
      );
    });
  }

  Widget _buildFeedList({
    required FeedState state,
    required List<PostModel> posts,
  }) {
    final storyState = _storyController.state;
    final isInitialLoading = state.isLoading && posts.isEmpty;
    final hasInitialError =
        !state.isLoading && posts.isEmpty && state.hasAnyError;
    final showEmptyState =
        !state.isLoading && posts.isEmpty && state.isEmptyState;

    final paginationErrorMessage =
        posts.isNotEmpty && !state.isLoadingMorePosts
            ? state.paginationErrorMessage
            : null;

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FeedScreenHeader(
                    onCreateStoryTap: _openCreateStoryEntryPoint,
                    onStoryTap: (storyIndex) {
                      unawaited(
                        _openStoryPreviewFromHeader(storyIndex),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FeedComposerCard(
                    onTap: _openCreatePostScreen,
                    currentUserAvatarUrl: _currentUserAvatarUrl,
                    currentUsername: _currentUsername,
                  ),
                  const SizedBox(height: 8),
                  StoryBar(
                    isLoading:
                        storyState.isLoading || _isOpeningStoryComposer,
                    errorMessage: null,
                    storyGroups: storyState.storyGroups,
                    currentUserName: _currentUsername,
                    currentUserProfileImageUrl: _currentUserAvatarUrl,
                    onCreateStoryTap: _openCreateStoryEntryPoint,
                    onRetry: _currentUserId.isEmpty
                        ? null
                        : () => unawaited(
                              _storyController.initialize(
                                currentUserId: _currentUserId,
                              ),
                            ),
                    onStoryGroupTap: (group) {
                      final groupIndex = storyState.storyGroups.indexWhere(
                        (item) => item.authorId == group.authorId,
                      );

                      unawaited(
                        _openStoryPreviewFromHeader(
                          groupIndex < 0 ? 0 : groupIndex,
                        ),
                      );
                    },
                  ),
                  if (_currentUserId.isEmpty) ...[
                    const SizedBox(height: 4),
                    const _FeedIdentityMissingCard(),
                  ],
                  if (_isSubmittingPost) ...[
                    const SizedBox(height: 4),
                    const _SubmittingPostCard(),
                  ],
                  const SizedBox(height: 2),
                  if (hasInitialError) ...[
                    _FeedStatusCard(
                      state: state,
                      postCount: posts.length,
                      onRetry: _refreshFeed,
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (showEmptyState) ...[
                    const _FeedEmptyCard(),
                    const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
          ),
          if (isInitialLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: FeedSkeletonPostCard(
                        showMedia: index != 1,
                      ),
                    );
                  },
                  childCount: 3,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                ),
              ),
            ),
          if (posts.isNotEmpty)
            const SliverToBoxAdapter(
              child: SizedBox(height: 10),
            ),
          if (posts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = posts[index];

                    return FeedPostAnimatedEntry(
                      key: _postKeyFor(post.id),
                      child: PostCard(
                        key: ValueKey<String>(post.id),
                        post: post,
                        reasons:
                            _feedController.buildPostReasons(post.id),
                        isHighlighted: widget.initialPostId == post.id,
                        onLikeTap: () =>
                            _feedController.toggleLike(post.id),
                        onReactionSelected: (reaction) =>
                            _feedController.setReaction(
                          post.id,
                          reaction,
                        ),
                        onLikeCountTap: () => _openPostLikes(post),
                        onCommentTap: () => _openRemoteComments(post),
                        onCommentPreviewTap: (commentId) =>
                            _openRemoteComments(
                          post,
                          highlightedCommentId: commentId,
                        ),
                        onShareTap: _isSharingPost
                            ? null
                            : () => unawaited(
                                  _openShareOptions(post),
                                ),
                        onSaveTap: () =>
                            _feedController.toggleSave(post.id),
                        onMoreTap: () => _showPostOptions(post),
                        onAuthorTap: () => _openAuthorPreview(post),
                      ),
                    );
                  },
                  childCount: posts.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: true,
                ),
              ),
            ),
          if (posts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              sliver: SliverToBoxAdapter(
                child: FeedPaginationFooter(
                  isLoading: _feedController.isLoadingMore,
                  hasMore: _feedController.hasMorePosts,
                  errorMessage: paginationErrorMessage,
                  onRetry: _loadMorePosts,
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveFeedBody({
    required FeedState state,
    required List<PostModel> posts,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showContactSidebar = constraints.maxWidth >= 980;

        final feedList = _buildFeedList(
          state: state,
          posts: posts,
        );

        if (!showContactSidebar) {
          return feedList;
        }

        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: feedList,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 12, 18),
                  child: FeedContactSidebar(
                    contacts: _messengerFeedContacts,
                    selectedContact: _selectedFeedContact,
                    currentUsername: _currentUsername,
                    currentUserAvatarUrl: _currentUserAvatarUrl,
                    searchController: _contactSearchController,
                    onContactTap: _handleFeedContactTap,
                    onOpenMessengerTap: _openMessengerFromSidebar,
                  ),
                ),
              ],
            ),
            if (_selectedFeedContact == null &&
                _lastClosedFeedContact != null &&
                _lastClosedMiniChat != null)
              Positioned(
                right: 334,
                bottom: 18,
                child: _MiniChatReopenPill(
                  contact: _lastClosedFeedContact!,
                  chat: _lastClosedMiniChat!,
                  onTap: _reopenLastMiniChat,
                ),
              ),
            for (final indexedEntry in _collapsedMiniChatEntries.asMap().entries)
              Positioned(
                right: 334.0 +
                    ((indexedEntry.key +
                            (_selectedFeedContact != null ? 1 : 0)) *
                        316.0),
                bottom: 18,
                child: _FeedMiniChatCollapsedBar(
                  contact: indexedEntry.value.contact,
                  unreadCount: indexedEntry.value.chat.unreadCount,
                  previewText: _previewTextForChat(indexedEntry.value.chat),
                  isTyping: _isTypingForChat(indexedEntry.value.chat),
                  onRestore: () => _activateMiniChatEntry(indexedEntry.value),
                  onClose: () => _closeMiniChatEntry(indexedEntry.value),
                ),
              ),
            if (_selectedFeedContact != null)
              Positioned(
                right: 334,
                bottom: 18,
                child: _isMiniChatMinimized
                    ? _FeedMiniChatCollapsedBar(
                        contact: _selectedFeedContact!,
                        unreadCount: _selectedMiniChat?.unreadCount ?? 0,
                        previewText: _selectedMiniChatPreviewText,
                        isTyping: _isSelectedMiniChatTyping,
                        onRestore: _restoreMiniChat,
                        onClose: _closeMiniChat,
                      )
                    : _FeedMiniChatWindow(
                        contact: _selectedFeedContact!,
                        messages: _selectedMiniChatMessages,
                        controller: _miniChatController,
                        scrollController: _miniChatScrollController,
                        focusNode: _miniChatFocusNode,
                        isTyping: _isSelectedMiniChatTyping,
                        onMinimize: _minimizeMiniChat,
                        onClose: _closeMiniChat,
                        onSend: _sendMiniChatMessage,
                      ),
              ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _feedController,
        _storyController,
      ]),
      builder: (context, child) {
        final state = _feedController.state;
        final posts = state.posts;

        _handleInitialNotificationTarget(posts);
        _scheduleVisibleFeedImagePreload(posts);

        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color(0xFFFEFCFA),
          body: SafeArea(
            child: _buildResponsiveFeedBody(
              state: state,
              posts: posts,
            ),
          ),
        );
      },
    );
  }
}



class _FeedMiniChatCollapsedBar extends StatelessWidget {
  final FeedContactModel contact;
  final int unreadCount;
  final String previewText;
  final bool isTyping;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  const _FeedMiniChatCollapsedBar({
    required this.contact,
    required this.unreadCount,
    required this.previewText,
    required this.isTyping,
    required this.onRestore,
    required this.onClose,
  });

  String _buildInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'LU';

    if (parts.length == 1) {
      final first = parts.first.trim();
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Color _presenceColor(ColorScheme colorScheme) {
    switch (contact.presenceStatus) {
      case FeedContactPresenceStatus.online:
        return const Color(0xFF34C759);
      case FeedContactPresenceStatus.recentlyActive:
        return LumaTheme.lumaOrange;
      case FeedContactPresenceStatus.offline:
        return const Color(0xFF756D65);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final avatarUrl = contact.safeAvatarUrl;
    final presenceColor = _presenceColor(colorScheme);

    final barColor = isDark
        ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.98)
        : const Color(0xFFFFFCF8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRestore,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: 318,
          height: 68,
          padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.09)
                  : const Color(0xFFE8DCCE),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.065),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : const Color(0xFFFFF8F1),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE8DCCE),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  _buildInitials(contact.safeDisplayName),
                                  style: TextStyle(
                                    color: LumaTheme.lumaOrange,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              _buildInitials(contact.safeDisplayName),
                              style: TextStyle(
                                color: LumaTheme.lumaOrange,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: presenceColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: barColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.safeDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF102033),
                        fontSize: 14.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.08,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isTyping) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: LumaTheme.lumaOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            previewText.trim().isEmpty
                                ? 'Chat öffnen'
                                : previewText.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isTyping
                                  ? LumaTheme.lumaOrange.withValues(alpha: 0.82)
                                  : const Color(0xFF756D65),
                              fontSize: 11.4,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.02,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LumaTheme.lumaOrange,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ],
              IconButton(
                onPressed: onRestore,
                tooltip: 'Mini-Chat öffnen',
                icon: Icon(
                  Icons.open_in_full_rounded,
                  color: const Color(0xFF756D65),
                  size: 17,
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: 'Mini-Chat schließen',
                icon: Icon(
                  Icons.close_rounded,
                  color: const Color(0xFF756D65),
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _MiniChatStackEntry {
  final FeedContactModel contact;
  final ChatModel chat;

  const _MiniChatStackEntry({
    required this.contact,
    required this.chat,
  });
}

class _MiniChatReopenPill extends StatelessWidget {
  final FeedContactModel contact;
  final ChatModel chat;
  final VoidCallback onTap;

  const _MiniChatReopenPill({
    required this.contact,
    required this.chat,
    required this.onTap,
  });

  String _previewText() {
    final preview = chat.lastMessagePreview.trim();
    if (preview.isEmpty || preview == 'Noch keine Nachrichten') {
      return 'Chat wieder aufnehmen';
    }

    return preview;
  }

  String _buildInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'LU';

    if (parts.length == 1) {
      final first = parts.first.trim();
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final avatarUrl = contact.safeAvatarUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 292,
          padding: const EdgeInsets.fromLTRB(9, 8, 11, 8),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.96)
                : const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.085)
                  : const Color(0xFFE8DCCE),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.095),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFFFF8F1),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarUrl != null
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              _buildInitials(contact.safeDisplayName),
                              style: TextStyle(
                                color: LumaTheme.lumaOrange,
                                fontSize: 10.8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          _buildInitials(contact.safeDisplayName),
                          style: TextStyle(
                            color: LumaTheme.lumaOrange,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.safeDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF102033),
                        fontSize: 12.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.04,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _previewText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF756D65),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: LumaTheme.lumaOrange.withValues(alpha: 0.78),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedMiniChatWindow extends StatelessWidget {
  final FeedContactModel contact;
  final List<MessageModel> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final bool isTyping;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final VoidCallback onSend;

  const _FeedMiniChatWindow({
    required this.contact,
    required this.messages,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    required this.isTyping,
    required this.onMinimize,
    required this.onClose,
    required this.onSend,
  });

  String _buildInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'LU';

    if (parts.length == 1) {
      final first = parts.first.trim();
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  String _presenceLabel() {
    switch (contact.presenceStatus) {
      case FeedContactPresenceStatus.online:
        return 'Jetzt verfügbar';
      case FeedContactPresenceStatus.recentlyActive:
      case FeedContactPresenceStatus.offline:
        final lastActiveAt = contact.lastActiveAt;
        if (lastActiveAt == null) {
          return contact.isRecentlyActive ? 'Kürzlich aktiv' : 'Nicht aktiv';
        }

        final difference = DateTime.now().difference(lastActiveAt);

        if (difference.inMinutes < 1) return 'Gerade aktiv';
        if (difference.inMinutes < 60) {
          return 'Vor ${difference.inMinutes} Min. aktiv';
        }
        if (difference.inHours < 24) {
          return 'Vor ${difference.inHours} Std. aktiv';
        }

        return 'Vor ${difference.inDays} Tg. aktiv';
    }
  }

  Color _presenceColor(ColorScheme colorScheme) {
    switch (contact.presenceStatus) {
      case FeedContactPresenceStatus.online:
        return const Color(0xFF34C759);
      case FeedContactPresenceStatus.recentlyActive:
        return LumaTheme.lumaOrange;
      case FeedContactPresenceStatus.offline:
        return const Color(0xFF756D65);
    }
  }

  String _messageTime(DateTime createdAt) {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final avatarUrl = contact.safeAvatarUrl;
    final presenceColor = _presenceColor(colorScheme);

    final windowColor = isDark
        ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.98)
        : const Color(0xFFFFFCF8);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 326,
        height: 462,
        decoration: BoxDecoration(
          color: windowColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.060)
                : const Color(0xFFE8DCCE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.070),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
            if (!isDark)
              BoxShadow(
                color: LumaTheme.lumaOrange.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(13, 8, 9, 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.030)
                    : const Color(0xFFFFF8F1),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.095) : const Color(0xFFE8DCCE),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(
                        alpha: isDark ? 0.12 : 0.09,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : const Color(0xFFFFF8F1),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE8DCCE),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: avatarUrl != null
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      _buildInitials(contact.safeDisplayName),
                                      style: TextStyle(
                                        color: LumaTheme.lumaOrange,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  _buildInitials(contact.safeDisplayName),
                                  style: TextStyle(
                                    color: LumaTheme.lumaOrange,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: presenceColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: windowColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                contact.safeDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF102033),
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.16,
                                ),
                              ),
                            ),
                            if (contact.isVerified) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified_rounded,
                                color: Colors.blue,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (isTyping) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: LumaTheme.lumaOrange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Expanded(
                              child: Text(
                                isTyping ? 'schreibt gerade ...' : _presenceLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isTyping
                                      ? LumaTheme.lumaOrange.withValues(alpha: 0.82)
                                      : const Color(0xFF756D65),
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _MiniChatHeaderButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Mini-Chat minimieren',
                    onPressed: onMinimize,
                  ),
                  const SizedBox(width: 4),
                  _MiniChatHeaderButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Mini-Chat schließen',
                    onPressed: onClose,
                  ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                color: isDark
                    ? colorScheme.surface.withValues(alpha: 0.15)
                    : const Color(0xFFFFF8F1),
                child: messages.isEmpty
                    ? _MiniChatEmptyState(contact: contact)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final topSpacer = messages.length <= 2
                              ? constraints.maxHeight * 0.34
                              : 14.0;

                          return SingleChildScrollView(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: topSpacer.clamp(14.0, 112.0),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    for (var index = 0; index < messages.length; index++) ...[
                                      _MiniChatBubble(
                                        message: messages[index],
                                        timeLabel: _messageTime(
                                          messages[index].createdAt,
                                        ),
                                      ),
                                      if (index < messages.length - 1)
                                        const SizedBox(height: 7),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              decoration: BoxDecoration(
                color: windowColor,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.095) : const Color(0xFFE8DCCE),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: 'Nachricht schreiben',
                        isDense: true,
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.030)
                            : const Color(0xFFFFF8F1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final canSend = value.text.trim().isNotEmpty;

                      return AnimatedOpacity(
                        opacity: canSend ? 1 : 0.42,
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        child: Material(
                          color: canSend
                              ? LumaTheme.lumaOrange.withValues(alpha: 0.82)
                              : colorScheme.onSurface.withValues(alpha: 0.095),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: canSend ? onSend : null,
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: canSend
                                    ? Colors.white
                                    : const Color(0xFF756D65),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _MiniChatHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MiniChatHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.020)
          : const Color(0xFFFFF8F1),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        splashColor: LumaTheme.lumaOrange.withValues(alpha: 0.026),
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              color: const Color(0xFF756D65),
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChatEmptyState extends StatelessWidget {
  final FeedContactModel contact;

  const _MiniChatEmptyState({
    required this.contact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.045)
              : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE8DCCE),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: LumaTheme.lumaOrange.withValues(alpha: 0.76),
              size: 24,
            ),
            const SizedBox(height: 10),
            Text(
              'Noch kein Verlauf',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF102033),
                fontSize: 13.7,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Schreibe direkt aus deinem Feed heraus.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF756D65),
                fontSize: 11.5,
                height: 1.32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChatBubble extends StatelessWidget {
  final MessageModel message;
  final String timeLabel;

  const _MiniChatBubble({
    required this.message,
    required this.timeLabel,
  });

  String get _messageText {
    if (message.isDeleted) return 'Diese Nachricht wurde gelöscht';

    if (message.isTextMessage) {
      final text = message.text.trim();
      return text.isEmpty ? 'Nachricht' : text;
    }

    if (message.isImageMessage) {
      if (message.isUploadFailed || message.isMediaFailed) {
        return 'Foto konnte nicht gesendet werden';
      }

      if (message.isUploadQueued) {
        return 'Foto wird vorbereitet ...';
      }

      if (message.isUploading || message.isMediaLoading) {
        return 'Foto wird hochgeladen ...';
      }

      return message.photoMessageSummaryLabel;
    }

    if (message.isAudioMessage) {
      if (message.isUploadFailed || message.isMediaFailed) {
        return 'Sprachnachricht konnte nicht gesendet werden';
      }

      if (message.isUploadQueued) {
        return 'Sprachnachricht wird vorbereitet ...';
      }

      if (message.isUploading || message.isMediaLoading) {
        return 'Sprachnachricht wird hochgeladen ...';
      }

      final duration = message.audioDuration;
      if (duration != null && duration.inSeconds > 0) {
        return '🎤 Sprachnachricht · ${duration.inSeconds}s';
      }

      return '🎤 Sprachnachricht';
    }

    return 'Nachricht';
  }

  IconData? get _leadingIcon {
    if (message.isDeleted) return Icons.block_rounded;
    if (message.isImageMessage) return Icons.image_rounded;
    if (message.isAudioMessage) return Icons.mic_rounded;
    return null;
  }

  IconData get _statusIcon {
    switch (message.deliveryStatus) {
      case MessageDeliveryStatus.sending:
        return Icons.schedule_rounded;
      case MessageDeliveryStatus.sent:
        return Icons.check_rounded;
      case MessageDeliveryStatus.delivered:
        return Icons.done_all_rounded;
      case MessageDeliveryStatus.read:
        return Icons.done_all_rounded;
      case MessageDeliveryStatus.failed:
        return Icons.error_outline_rounded;
    }
  }

  String get _statusLabel {
    switch (message.deliveryStatus) {
      case MessageDeliveryStatus.sending:
        return 'Wird gesendet';
      case MessageDeliveryStatus.sent:
        return 'Gesendet';
      case MessageDeliveryStatus.delivered:
        return 'Zugestellt';
      case MessageDeliveryStatus.read:
        return 'Gelesen';
      case MessageDeliveryStatus.failed:
        return 'Fehlgeschlagen';
    }
  }

  bool get _isFailed {
    return message.deliveryStatus == MessageDeliveryStatus.failed ||
        message.isUploadFailed ||
        message.isMediaFailed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = message.isOwnMessage
        ? _isFailed
            ? colorScheme.error.withValues(alpha: 0.92)
            : LumaTheme.lumaOrange.withValues(alpha: 0.82)
        : isDark
            ? Colors.white.withValues(alpha: 0.060)
            : const Color(0xFFFFFBF7);

    final textColor = message.isOwnMessage
        ? Colors.white
        : const Color(0xFF102033);

    final icon = _leadingIcon;

    return Align(
      alignment:
          message.isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 226),
        child: Column(
          crossAxisAlignment: message.isOwnMessage
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isOwnMessage ? 20 : 8),
                  bottomRight: Radius.circular(message.isOwnMessage ? 8 : 20),
                ),
                border: message.isOwnMessage
                    ? null
                    : Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.08),
                      ),
                boxShadow: [
                  if (!message.isOwnMessage && !isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 15,
                      color: textColor.withValues(alpha: 0.82),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      _messageText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontSize: 13.1,
                        height: 1.36,
                        fontWeight:
                            message.isDeleted ? FontWeight.w600 : FontWeight.w600,
                        fontStyle:
                            message.isDeleted ? FontStyle.italic : FontStyle.normal,
                        letterSpacing: -0.02,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF756D65),
                      fontSize: 10.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message.isOwnMessage) ...[
                    const SizedBox(width: 5),
                    Icon(
                      _statusIcon,
                      size: 12,
                      color: _isFailed
                          ? colorScheme.error.withValues(alpha: 0.72)
                          : const Color(0xFF756D65),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _statusLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _isFailed
                            ? colorScheme.error.withValues(alpha: 0.72)
                            : const Color(0xFF756D65),
                        fontSize: 10.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorPreviewCard extends StatelessWidget {
  final String fallbackUsername;
  final String? fallbackAvatarUrl;
  final LumaUserProfileModel? profile;
  final bool isLoading;
  final bool isOwnProfile;
  final bool canOpenFirebaseProfile;
  final VoidCallback onClose;
  final VoidCallback? onOpenProfile;

  const _AuthorPreviewCard({
    required this.fallbackUsername,
    required this.fallbackAvatarUrl,
    required this.profile,
    required this.isLoading,
    required this.isOwnProfile,
    required this.canOpenFirebaseProfile,
    required this.onClose,
    required this.onOpenProfile,
  });

  String get _displayName {
    final value = profile?.displayName.trim();

    if (value != null && value.isNotEmpty) return value;

    return fallbackUsername.trim().isEmpty ? 'Luma Nutzer' : fallbackUsername;
  }

  String get _username {
    final value = profile?.username.trim();

    if (value != null && value.isNotEmpty) {
      return value.startsWith('@') ? value : '@$value';
    }

    final cleaned = _displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.|\.$'), '');

    if (cleaned.isEmpty) return '@luma';
    return '@$cleaned';
  }

  String? get _avatarUrl {
    final profileAvatar = profile?.avatarUrl?.trim();
    if (profileAvatar != null && profileAvatar.isNotEmpty) {
      return profileAvatar;
    }

    final postAvatar = fallbackAvatarUrl?.trim();
    if (postAvatar != null && postAvatar.isNotEmpty) {
      return postAvatar;
    }

    return null;
  }

  String? get _coverUrl {
    final value = profile?.coverUrl?.trim();

    if (value == null || value.isEmpty) return null;

    return value;
  }

  String? get _bio {
    final value = profile?.bio?.trim();

    if (value == null || value.isEmpty) return null;

    return value;
  }

  String _buildInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'LU';

    if (parts.length == 1) {
      final first = parts.first;
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final avatarUrl = _avatarUrl;
    final coverUrl = _coverUrl;
    final bio = _bio;
    final canOpenProfileAction = onOpenProfile != null;

    final cardBackground = isDark
        ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.98)
        : const Color(0xFFFFFCF8);
    final premiumBorder = isDark
        ? Colors.white.withValues(alpha: 0.085)
        : const Color(0xFFE9DED2);
    final mutedText = colorScheme.onSurface.withValues(alpha: isDark ? 0.62 : 0.56);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.965, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(38),
          border: Border.all(color: premiumBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.18),
              blurRadius: 48,
              offset: const Offset(0, 24),
            ),
            if (!isDark)
              BoxShadow(
                color: LumaTheme.lumaOrange.withValues(alpha: 0.06),
                blurRadius: 42,
                offset: const Offset(0, 14),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                SizedBox(
                  height: 226,
                  width: double.infinity,
                  child: coverUrl != null
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _AuthorPreviewCoverFallback(
                              colorScheme: colorScheme,
                            );
                          },
                        )
                      : _AuthorPreviewCoverFallback(colorScheme: colorScheme),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.00),
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: isDark ? 0.46 : 0.38),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cardBackground.withValues(alpha: 0.00),
                          cardBackground.withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -66,
                  child: Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(5.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardBackground,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.88),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.18),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFFFF8F0),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: LumaTheme.lumaOrange.withValues(alpha: 0.14),
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                _buildInitials(_displayName),
                                style: TextStyle(
                                  color: LumaTheme.lumaOrange,
                                  fontSize: 31,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 86, 30, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isLoading) ...[
                    const _AuthorPreviewLoadingStrip(),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                            height: 1.01,
                            letterSpacing: -0.65,
                          ),
                        ),
                      ),
                      if (profile?.isVerified == true) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 21,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedText,
                      fontSize: 14.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.05,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 46,
                    height: 3,
                    decoration: BoxDecoration(
                      color: LumaTheme.lumaOrange.withValues(alpha: isDark ? 0.36 : 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 310,
                      height: 44,
                      child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: onOpenProfile,
                        borderRadius: BorderRadius.circular(999),
                        splashColor: canOpenProfileAction
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.transparent,
                        highlightColor: canOpenProfileAction
                            ? Colors.white.withValues(alpha: 0.032)
                            : Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            color: canOpenProfileAction
                                ? LumaTheme.lumaOrange
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.045)
                                    : const Color(0xFFF0E8DF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: canOpenProfileAction
                                  ? LumaTheme.lumaOrange
                                  : colorScheme.outline.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    canOpenProfileAction
                                        ? 'Profil ansehen'
                                        : 'Profil nicht verfügbar',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: canOpenProfileAction
                                          ? colorScheme.onSurface.withValues(
                                              alpha: 0.82,
                                            )
                                          : colorScheme.onSurface.withValues(
                                              alpha: 0.50,
                                            ),
                                      fontSize: 14.8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.12,
                                    ),
                                  ),
                                ),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        )
      ),
    );
  }
}

class _AuthorPreviewCoverFallback extends StatelessWidget {
  final ColorScheme colorScheme;

  const _AuthorPreviewCoverFallback({
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surfaceContainerHigh,
                  LumaTheme.lumaOrange.withValues(alpha: 0.20),
                ]
              : [
                  const Color(0xFFFFF8F0),
                  const Color(0xFFF3E6D8),
                  const Color(0xFFFFDDB4),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -62,
            right: -42,
            child: Container(
              width: 202,
              height: 202,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.09 : 0.36),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LumaTheme.lumaOrange.withValues(alpha: isDark ? 0.15 : 0.13),
              ),
            ),
          ),
          Positioned(
            top: 54,
            left: 34,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.28),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: LumaTheme.lumaOrange.withValues(alpha: isDark ? 0.28 : 0.22),
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorPreviewLoadingStrip extends StatelessWidget {
  const _AuthorPreviewLoadingStrip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: LumaTheme.lumaOrange.withValues(alpha: isDark ? 0.09 : 0.075),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LumaTheme.lumaOrange.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: LumaTheme.lumaOrange.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Profil wird geladen ...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
                fontSize: 12.6,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedStatusCard extends StatelessWidget {
  final FeedState state;
  final int postCount;
  final VoidCallback onRetry;

  const _FeedStatusCard({
    required this.state,
    required this.postCount,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = state.errorMessage?.trim();
    final remoteErrorMessage = state.remoteErrorMessage?.trim();

    if (errorMessage != null && errorMessage.isNotEmpty) {
      return _FeedErrorCard(
        message: errorMessage,
        onRetry: onRetry,
      );
    }

    if (remoteErrorMessage != null && remoteErrorMessage.isNotEmpty) {
      return _FeedErrorCard(
        message: remoteErrorMessage,
        onRetry: onRetry,
      );
    }

    if (postCount == 0) {
      return const _FeedEmptyCard();
    }

    return const SizedBox.shrink();
  }
}


class _DeletePostConfirmationDialog extends StatefulWidget {
  final PostModel post;

  const _DeletePostConfirmationDialog({
    required this.post,
  });

  @override
  State<_DeletePostConfirmationDialog> createState() =>
      _DeletePostConfirmationDialogState();
}

class _DeletePostConfirmationDialogState
    extends State<_DeletePostConfirmationDialog> {
  bool _hasAcknowledged = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      icon: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.delete_forever_outlined,
          color: colorScheme.error,
          size: 27,
        ),
      ),
      title: const Text(
        'Beitrag dauerhaft löschen?',
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dieser Beitrag wird dauerhaft aus Luma entfernt. '
              'Die Aktion kann nicht rückgängig gemacht werden.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.42,
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.12),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DeletePostConsequenceRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: 'Kommentare und Antworten werden entfernt.',
                  ),
                  SizedBox(height: 9),
                  _DeletePostConsequenceRow(
                    icon: Icons.favorite_border_rounded,
                    text: 'Reaktionen und gespeicherte Verweise gehen verloren.',
                  ),
                  SizedBox(height: 9),
                  _DeletePostConsequenceRow(
                    icon: Icons.undo_rounded,
                    text: 'Der Beitrag kann später nicht wiederhergestellt werden.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _hasAcknowledged,
              onChanged: (value) {
                setState(() {
                  _hasAcknowledged = value == true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Ich verstehe, dass der Beitrag dauerhaft gelöscht wird.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.28,
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: _hasAcknowledged
              ? () {
                  Navigator.of(context).pop(true);
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            disabledBackgroundColor:
                colorScheme.onSurface.withValues(alpha: 0.08),
            disabledForegroundColor:
                colorScheme.onSurface.withValues(alpha: 0.34),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          icon: const Icon(
            Icons.delete_forever_outlined,
            size: 19,
          ),
          label: const Text('Endgültig löschen'),
        ),
      ],
    );
  }
}

class _DeletePostConsequenceRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DeletePostConsequenceRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: colorScheme.error.withValues(alpha: 0.82),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.4,
              height: 1.30,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
      ],
    );
  }
}

class _PostOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDanger;
  final VoidCallback? onTap;

  const _PostOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isDanger ? colorScheme.error : colorScheme.onSurface;

    final isEnabled = onTap != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.56,
      child: ListTile(
        enabled: isEnabled,
        onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.58),
          fontWeight: FontWeight.w600,
        ),
      ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class _FeedIdentityMissingCard extends StatelessWidget {
  const _FeedIdentityMissingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        'Firebase-Identität wird geladen oder ist nicht verfügbar.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _SubmittingPostCard extends StatelessWidget {
  const _SubmittingPostCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: LumaTheme.lumaOrange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LumaTheme.lumaOrange.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: LumaTheme.lumaOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Beitrag wird gespeichert...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedLoadingCard extends StatelessWidget {
  const _FeedLoadingCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _FeedErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FeedErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Erneut laden'),
          ),
        ],
      ),
    );
  }
}

class _FeedEmptyCard extends StatelessWidget {
  const _FeedEmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark
        ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.96)
        : const Color(0xFFFFFCF8);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 0, 10),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.075)
              : const Color(0xFFEFE2D6),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LumaTheme.lumaOrange.withValues(
                alpha: isDark ? 0.17 : 0.11,
              ),
              border: Border.all(
                color: LumaTheme.lumaOrange.withValues(
                  alpha: isDark ? 0.20 : 0.13,
                ),
              ),
            ),
            child: Icon(
              Icons.dynamic_feed_rounded,
              color: LumaTheme.lumaOrange,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Noch keine Beiträge',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.92),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.22,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Hier erscheinen Beiträge von dir und deinen Freunden.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.64),
              fontSize: 13.4,
              fontWeight: FontWeight.w600,
              height: 1.46,
              letterSpacing: -0.04,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: LumaTheme.lumaOrange.withValues(
                alpha: isDark ? 0.105 : 0.075,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: LumaTheme.lumaOrange.withValues(
                  alpha: isDark ? 0.15 : 0.10,
                ),
              ),
            ),
            child: Text(
              'Ersten Beitrag erstellen',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: LumaTheme.lumaOrange.withValues(alpha: 0.88),
                fontSize: 11.6,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.02,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _FeedPostLikesSheet extends StatelessWidget {
  final PostModel post;
  final Future<List<FeedPostLikeUser>> future;
  final ValueChanged<FeedPostLikeUser> onOpenProfile;

  const _FeedPostLikesSheet({
    required this.post,
    required this.future,
    required this.onOpenProfile,
  });

  int get _safeLikeCount => post.likeCount < 0 ? 0 : post.likeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.13),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _safeLikeCount == 1
                          ? 'Gefällt 1 Person'
                          : 'Gefällt $_safeLikeCount Personen',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Schließen',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<FeedPostLikeUser>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 28, 16, 38),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const _FeedPostLikesState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Reaktionen konnten nicht geladen werden',
                      message: 'Bitte versuche es gleich erneut.',
                    );
                  }

                  final likeUsers = snapshot.data ?? const <FeedPostLikeUser>[];

                  if (likeUsers.isEmpty) {
                    return const _FeedPostLikesState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Keine sichtbaren Reaktionen',
                      message:
                          'Die Anzahl ist vorhanden, aber die Personen konnten gerade nicht geladen werden.',
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FeedPostReactionSummary(likeUsers: likeUsers),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                          itemCount: likeUsers.length,
                          separatorBuilder: (context, index) {
                            return Divider(
                              height: 1,
                              color:
                                  colorScheme.outline.withValues(alpha: 0.10),
                            );
                          },
                          itemBuilder: (context, index) {
                            final likeUser = likeUsers[index];

                            return _FeedPostLikeUserTile(
                              likeUser: likeUser,
                              onTap: () => onOpenProfile(likeUser),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedPostReactionSummary extends StatelessWidget {
  final List<FeedPostLikeUser> likeUsers;

  const _FeedPostReactionSummary({
    required this.likeUsers,
  });

  Map<String, int> get _reactionCounts {
    final result = <String, int>{};

    for (final user in likeUsers) {
      final reactionType = user.safeReactionType.trim().isEmpty
          ? 'heart'
          : user.safeReactionType.trim();

      result[reactionType] = (result[reactionType] ?? 0) + 1;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _reactionCounts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    if (counts.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleCounts = counts.take(6).toList(growable: false);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in visibleCounts)
            _FeedPostReactionSummaryChip(
              reactionType: entry.key,
              count: entry.value,
            ),
        ],
      ),
    );
  }
}

class _FeedPostReactionSummaryChip extends StatelessWidget {
  final String reactionType;
  final int count;

  const _FeedPostReactionSummaryChip({
    required this.reactionType,
    required this.count,
  });

  IconData get _icon {
    switch (reactionType) {
      case 'like':
        return Icons.thumb_up_alt_rounded;
      case 'haha':
        return Icons.sentiment_very_satisfied_rounded;
      case 'wow':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'sad':
        return Icons.sentiment_dissatisfied_rounded;
      case 'angry':
        return Icons.mood_bad_rounded;
      case 'love':
      case 'heart':
      default:
        return Icons.favorite_rounded;
    }
  }

  String get _label {
    switch (reactionType) {
      case 'like':
        return 'Gefällt mir';
      case 'haha':
        return 'Haha';
      case 'wow':
        return 'Wow';
      case 'sad':
        return 'Traurig';
      case 'angry':
        return 'Wütend';
      case 'love':
        return 'Liebe ich';
      case 'heart':
      default:
        return 'Herz';
    }
  }

  Color _color(ColorScheme colorScheme) {
    switch (reactionType) {
      case 'like':
        return Colors.blueAccent;
      case 'haha':
      case 'wow':
        return Colors.amber.shade700;
      case 'sad':
        return Colors.indigoAccent;
      case 'angry':
        return colorScheme.error;
      case 'love':
      case 'heart':
      default:
        return LumaTheme.lumaOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _color(colorScheme);

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 10, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            '$_label · $count',
            style: TextStyle(
              color: color,
              fontSize: 11.4,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPostLikesState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _FeedPostLikesState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: LumaTheme.lumaOrange,
            size: 31,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.58),
              height: 1.32,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPostLikeUserTile extends StatelessWidget {
  final FeedPostLikeUser likeUser;
  final VoidCallback onTap;

  const _FeedPostLikeUserTile({
    required this.likeUser,
    required this.onTap,
  });

  String get _displayName => likeUser.safeDisplayName;

  String get _username => likeUser.safeUsername;

  String get _avatarUrl => likeUser.safeAvatarUrl;

  String get _reactionType => likeUser.safeReactionType;

  IconData get _reactionIcon {
    switch (_reactionType) {
      case 'like':
        return Icons.thumb_up_alt_rounded;
      case 'haha':
        return Icons.sentiment_very_satisfied_rounded;
      case 'wow':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'sad':
        return Icons.sentiment_dissatisfied_rounded;
      case 'angry':
        return Icons.mood_bad_rounded;
      case 'love':
      case 'heart':
      default:
        return Icons.favorite_rounded;
    }
  }

  String get _reactionLabel {
    switch (_reactionType) {
      case 'like':
        return 'Gefällt mir';
      case 'haha':
        return 'Haha';
      case 'wow':
        return 'Wow';
      case 'sad':
        return 'Traurig';
      case 'angry':
        return 'Wütend';
      case 'love':
        return 'Liebe ich';
      case 'heart':
      default:
        return 'Herz';
    }
  }

  Color _reactionColor(ColorScheme colorScheme) {
    switch (_reactionType) {
      case 'like':
        return Colors.blueAccent;
      case 'haha':
      case 'wow':
        return Colors.amber.shade700;
      case 'sad':
        return Colors.indigoAccent;
      case 'angry':
        return colorScheme.error;
      case 'love':
      case 'heart':
      default:
        return LumaTheme.lumaOrange;
    }
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'LU';

    if (parts.length == 1) {
      final first = parts.first;
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reactionColor = _reactionColor(colorScheme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 11, 8, 11),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LumaTheme.lumaOrange.withValues(alpha: 0.10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _avatarUrl.isEmpty
                        ? Center(
                            child: Text(
                              _initials(_displayName),
                              style: TextStyle(
                                color: LumaTheme.lumaOrange,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        : Image.network(
                            _avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  _initials(_displayName),
                                  style: TextStyle(
                                    color: LumaTheme.lumaOrange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: reactionColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _reactionIcon,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (_username.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              _username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.54,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],
                        Text(
                          _reactionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: reactionColor,
                            fontSize: 11.7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.36),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}