// Pfad: lib/features/profile/presentation/profile_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../application/messenger_controller.dart';
import '../../../application/messenger_remote_mode.dart';
import '../../../domain/models/chat_model.dart';
import '../../messenger/presentation/chat_screen.dart';
import '../application/profile_controller.dart';
import '../application/profile_friendship_controller.dart';
import '../application/profile_photos_controller.dart';
import '../application/profile_posts_controller.dart';
import '../domain/profile_friendship_model.dart';
import '../domain/profile_model.dart';
import '../domain/profile_photo_model.dart';
import '../domain/profile_post_model.dart';
import 'profile_create_post_screen.dart';
import 'profile_edit_screen.dart';
import 'profile_edit_post_screen.dart';
import 'profile_photos_screen.dart';
import 'profile_post_detail_screen.dart';
import 'widgets/profile_about_section.dart';
import 'widgets/profile_action_bar.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_photos_section.dart';
import 'widgets/profile_posts_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.userId,
  });

  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _profileController;
  late final ProfileFriendshipController _friendshipController;
  late final ProfilePhotosController _photosController;
  late final ProfilePostsController _postsController;

  final MessengerController _messengerController =
      MessengerController.instance;

  bool _isOpeningChat = false;

  @override
  void initState() {
    super.initState();

    _profileController = ProfileController();
    _friendshipController = ProfileFriendshipController();
    _photosController = ProfilePhotosController();
    _postsController = ProfilePostsController();

    _profileController.addListener(_handleControllerChanged);
    _friendshipController.addListener(_handleControllerChanged);
    _photosController.addListener(_handleControllerChanged);
    _postsController.addListener(_handleControllerChanged);

    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId?.trim() != widget.userId?.trim()) {
      _load();
    }
  }

  @override
  void dispose() {
    _profileController.removeListener(_handleControllerChanged);
    _friendshipController.removeListener(_handleControllerChanged);
    _photosController.removeListener(_handleControllerChanged);
    _postsController.removeListener(_handleControllerChanged);

    _profileController.dispose();
    _friendshipController.dispose();
    _photosController.dispose();
    _postsController.dispose();

    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    await _profileController.loadProfile(
      userId: widget.userId,
    );

    final profile = _profileController.profile;
    if (profile == null) return;

    await _friendshipController.loadForProfile(
      viewedUserId: profile.uid,
    );

    await _loadProfileContent(profile);
  }

  Future<void> _loadProfileContent(ProfileModel profile) async {
    final currentUserId = _profileController.currentUserId;
    if (currentUserId.isEmpty) return;

    final isOwnProfile = _profileController.isOwnProfile;
    final areFriends =
        _friendshipController.relationship.status ==
            ProfileFriendshipStatus.friends;

    final canViewPhotos = isOwnProfile || areFriends;

    await Future.wait<void>([
      _photosController.load(
        userId: profile.uid,
        canView: canViewPhotos,
      ),
      _postsController.load(
        profileUserId: profile.uid,
        currentUserId: currentUserId,
        areFriends: areFriends,
      ),
    ]);
  }

  Future<void> _refresh() async {
    await _profileController.reload();

    final profile = _profileController.profile;
    if (profile == null) return;

    await _friendshipController.reload(
      viewedUserId: profile.uid,
    );

    await _loadProfileContent(profile);
  }

  Future<void> _openCreatePost() async {
    final profile = _profileController.profile;

    if (profile == null || !_profileController.isOwnProfile) {
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileCreatePostScreen(
          profile: profile,
          controller: _postsController,
        ),
      ),
    );

    if (!mounted || changed != true) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Dein Beitrag ist online.'),
        ),
      );
  }

  Future<void> _openAllPhotos() async {
    final profile = _profileController.profile;
    if (profile == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfilePhotosScreen(
          profile: profile,
          isOwnProfile: _profileController.isOwnProfile,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadProfileContent(profile);
    }
  }

  Future<void> _openPhoto(ProfilePhotoModel photo) async {
    final profile = _profileController.profile;
    if (profile == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfilePhotosScreen(
          profile: profile,
          isOwnProfile: _profileController.isOwnProfile,
          initialPhoto: photo,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadProfileContent(profile);
    }
  }

  Future<void> _openPost(ProfilePostModel post) async {
    final profile = _profileController.profile;
    if (profile == null) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfilePostDetailScreen(
          profile: profile,
          post: post,
          isOwnProfile: _profileController.isOwnProfile,
          onEditPost: _editPost,
          onDeletePost: _deletePost,
        ),
      ),
    );
  }

  Future<bool> _editPost(ProfilePostModel post) async {
    if (!_profileController.isOwnProfile ||
        _postsController.isEditing ||
        _postsController.isDeleting) {
      return false;
    }

    if (post.isRepost) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Geteilte Beiträge können hier noch nicht bearbeitet werden.',
            ),
          ),
        );
      return false;
    }

    final currentUserId = _profileController.currentUserId.trim();
    if (currentUserId.isEmpty) {
      return false;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditPostScreen(
          currentUserId: currentUserId,
          post: post,
          controller: _postsController,
        ),
      ),
    );

    if (!mounted || changed != true) {
      return false;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Beitrag wurde aktualisiert.'),
        ),
      );

    return true;
  }

  Future<bool> _deletePost(ProfilePostModel post) async {
    if (!_profileController.isOwnProfile || _postsController.isDeleting) {
      return false;
    }

    final currentUserId = _profileController.currentUserId.trim();
    if (currentUserId.isEmpty) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: const Text('Beitrag löschen?'),
          content: const Text(
            'Möchtest du diesen Beitrag wirklich löschen? '
            'Das kann nicht rückgängig gemacht werden.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return false;
    }

    final deleted = await _postsController.deletePost(
      currentUserId: currentUserId,
      post: post,
    );

    if (!mounted) return deleted;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? 'Beitrag wurde gelöscht.'
                : (_postsController.errorMessage ??
                    'Beitrag konnte nicht gelöscht werden.'),
          ),
        ),
      );

    return deleted;
  }

  Future<void> _openEditProfile() async {
    final profile = _profileController.profile;
    if (profile == null || !_profileController.isOwnProfile) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditScreen(
          profile: profile,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _refresh();
    }
  }

  void _showFriendshipInfo() {
    final status = _friendshipController.relationship.status;

    final message = switch (status) {
      ProfileFriendshipStatus.self =>
        'Das ist dein eigenes Profil.',
      ProfileFriendshipStatus.notFriends =>
        'Freundschaftsanfragen werden im nächsten Schritt aktiviert.',
      ProfileFriendshipStatus.requestSent =>
        'Deine Freundschaftsanfrage ist noch offen.',
      ProfileFriendshipStatus.requestReceived =>
        'Du hast von diesem Nutzer eine Freundschaftsanfrage erhalten.',
      ProfileFriendshipStatus.friends =>
        'Ihr seid bereits Freunde.',
      ProfileFriendshipStatus.blocked =>
        'Für dieses Profil ist keine Freundschaftsaktion verfügbar.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _openMessage() async {
    if (_isOpeningChat) return;

    final profile = _profileController.profile;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (profile == null || currentUser == null) return;

    if (profile.uid.trim().isEmpty ||
        profile.uid.trim() == currentUser.uid.trim()) {
      return;
    }

    setState(() {
      _isOpeningChat = true;
    });

    try {
      await _messengerController.configureRemoteMode(
        mode: MessengerRemoteMode.remoteOnly,
        currentUserId: currentUser.uid,
      );

      final participant = ChatParticipantModel(
        userId: profile.uid,
        displayName: profile.displayName.trim().isEmpty
            ? 'Luma Nutzer'
            : profile.displayName.trim(),
        avatarUrl: profile.profileImageUrl.trim(),
        isOnline: false,
      );

      final chat = await _messengerController.openOrCreateDirectChat(
        participant,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            chat: chat,
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        'ProfileScreen: Chat konnte nicht geöffnet werden: $error',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unterhaltung konnte nicht geöffnet werden.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningChat = false;
        });
      }
    }
  }

  void _showProfileOptionsInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Weitere Profiloptionen werden später angebunden.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_profileController.state) {
      case ProfileLoadState.initial:
      case ProfileLoadState.loading:
        return const _ProfileLoadingView();

      case ProfileLoadState.loaded:
        final profile = _profileController.profile;

        if (profile == null) {
          return _ProfileMessageView(
            title: 'Profil nicht verfügbar',
            message: 'Das Profil konnte nicht angezeigt werden.',
            onRetry: _refresh,
          );
        }

        return _ProfileContent(
          profile: profile,
          isOwnProfile: _profileController.isOwnProfile,
          friendshipStatus:
              _friendshipController.relationship.status,
          isFriendshipLoading:
              _friendshipController.state ==
                      ProfileFriendshipLoadState.initial ||
                  _friendshipController.state ==
                      ProfileFriendshipLoadState.loading,
          friendsCount: _friendshipController.friendsCount,
          photosController: _photosController,
          postsController: _postsController,
          onRefresh: _refresh,
          onEditProfile: () {
            _openEditProfile();
          },
          onCreatePost: () {
            _openCreatePost();
          },
          onFriendshipAction: _showFriendshipInfo,
          onMessage: () {
            if (!_isOpeningChat) {
              _openMessage();
            }
          },
          onOpenOptions: _showProfileOptionsInfo,
          onOpenAllPhotos: () {
            _openAllPhotos();
          },
          onOpenPhoto: (photo) {
            _openPhoto(photo);
          },
          onOpenPost: (post) {
            _openPost(post);
          },
          onEditPost: _editPost,
          onDeletePost: _deletePost,
        );

      case ProfileLoadState.notFound:
        return _ProfileMessageView(
          title: 'Profil nicht gefunden',
          message: 'Dieses Luma-Profil wurde nicht gefunden.',
          onRetry: _refresh,
        );

      case ProfileLoadState.error:
        return _ProfileMessageView(
          title: 'Profil konnte nicht geladen werden',
          message: _profileController.errorMessage ??
              'Bitte versuche es noch einmal.',
          onRetry: _refresh,
        );
    }
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.isOwnProfile,
    required this.friendshipStatus,
    required this.isFriendshipLoading,
    required this.friendsCount,
    required this.photosController,
    required this.postsController,
    required this.onRefresh,
    required this.onEditProfile,
    required this.onCreatePost,
    required this.onFriendshipAction,
    required this.onMessage,
    required this.onOpenOptions,
    required this.onOpenAllPhotos,
    required this.onOpenPhoto,
    required this.onOpenPost,
    required this.onEditPost,
    required this.onDeletePost,
  });

  final ProfileModel profile;
  final bool isOwnProfile;
  final ProfileFriendshipStatus friendshipStatus;
  final bool isFriendshipLoading;
  final int friendsCount;
  final ProfilePhotosController photosController;
  final ProfilePostsController postsController;

  final Future<void> Function() onRefresh;
  final VoidCallback onEditProfile;
  final VoidCallback onCreatePost;
  final VoidCallback onFriendshipAction;
  final VoidCallback onMessage;
  final VoidCallback onOpenOptions;
  final VoidCallback onOpenAllPhotos;
  final ValueChanged<ProfilePhotoModel> onOpenPhoto;
  final ValueChanged<ProfilePostModel> onOpenPost;
  final Future<bool> Function(ProfilePostModel post) onEditPost;
  final Future<bool> Function(ProfilePostModel post) onDeletePost;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            ProfileHeader(
              profile: profile,
            ),
            const SizedBox(height: 16),
            ProfileActionBar(
              isOwnProfile: isOwnProfile,
              friendshipStatus: friendshipStatus,
              isFriendshipLoading: isFriendshipLoading,
              onEditProfile: onEditProfile,
              onFriendshipAction: onFriendshipAction,
              onMessage: onMessage,
              onOpenOptions: onOpenOptions,
            ),
            if (!isFriendshipLoading) ...<Widget>[
              const SizedBox(height: 14),
              _FriendsSummary(
                count: friendsCount,
              ),
            ],
            ProfileAboutSection(
              profile: profile,
            ),
            if (isOwnProfile)
              _ProfileCreatePostEntry(
                onTap: onCreatePost,
                isCreating: postsController.isCreating,
              ),
            ProfilePhotosSection(
              state: photosController.state,
              photos: photosController.photos,
              errorMessage: photosController.errorMessage,
              onOpenAll: onOpenAllPhotos,
              onOpenPhoto: onOpenPhoto,
            ),
            ProfilePostsSection(
              profile: profile,
              state: postsController.state,
              posts: postsController.posts,
              isOwnProfile: isOwnProfile,
              editingPostId: postsController.editingPostId,
              deletingPostId: postsController.deletingPostId,
              errorMessage: postsController.errorMessage,
              onOpenPost: onOpenPost,
              onEditPost: (post) async {
                await onEditPost(post);
              },
              onDeletePost: (post) async {
                await onDeletePost(post);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCreatePostEntry extends StatelessWidget {
  const _ProfileCreatePostEntry({
    required this.onTap,
    required this.isCreating,
  });

  final VoidCallback onTap;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: isCreating ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.edit_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    isCreating
                        ? 'Beitrag wird veröffentlicht ...'
                        : 'Was möchtest du teilen?',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendsSummary extends StatelessWidget {
  const _FriendsSummary({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = count == 1 ? '1 Freund' : '$count Freunde';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.people_outline_rounded,
              size: 21,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ProfileMessageView extends StatelessWidget {
  const _ProfileMessageView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
