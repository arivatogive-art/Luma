// Pfad: lib/features/notifications/presentation/notification_post_target_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profile/application/profile_posts_controller.dart';
import '../../profile/data/profile_post_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/domain/profile_post_model.dart';
import '../../profile/presentation/profile_edit_post_screen.dart';
import '../../profile/presentation/profile_post_detail_screen.dart';
import '../domain/notification_model.dart';

class NotificationPostTargetScreen extends StatefulWidget {
  const NotificationPostTargetScreen({
    super.key,
    required this.notification,
  });

  final LumaNotificationModel notification;

  @override
  State<NotificationPostTargetScreen> createState() =>
      _NotificationPostTargetScreenState();
}

class _NotificationPostTargetScreenState
    extends State<NotificationPostTargetScreen> {
  final ProfilePostRepository _postRepository = ProfilePostRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  late final ProfilePostsController _postsController;

  ProfilePostModel? _post;
  ProfileModel? _profile;
  String? _errorMessage;
  bool _isLoading = true;
  bool _canRetry = true;

  @override
  void initState() {
    super.initState();
    _postsController = ProfilePostsController();
    _load();
  }

  @override
  void dispose() {
    _postsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _canRetry = true;
      });
    }

    try {
      final post = await _resolvePost();
      if (post == null) {
        if (!mounted) return;
        setState(() {
          _post = null;
          _profile = null;
          _errorMessage = 'Dieser Beitrag ist nicht mehr verfügbar.';
          _isLoading = false;
          _canRetry = false;
        });
        return;
      }

      final authorId = post.authorId.trim();
      if (authorId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _post = null;
          _profile = null;
          _errorMessage = 'Der Beitrag konnte keinem Profil zugeordnet werden.';
          _isLoading = false;
          _canRetry = false;
        });
        return;
      }

      final profile = await _profileRepository.fetchProfile(uid: authorId);
      if (profile == null) {
        if (!mounted) return;
        setState(() {
          _post = null;
          _profile = null;
          _errorMessage = 'Das Profil zu diesem Beitrag ist nicht verfügbar.';
          _isLoading = false;
          _canRetry = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _post = post;
        _profile = profile;
        _errorMessage = null;
        _isLoading = false;
        _canRetry = true;
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'NotificationPostTargetScreen: Firebase-Ziel konnte nicht geladen werden.',
      );
      debugPrint('${error.code}: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      final isPermissionDenied = error.code == 'permission-denied';
      final isNotFound = error.code == 'not-found';

      setState(() {
        _post = null;
        _profile = null;
        _errorMessage = isPermissionDenied
            ? 'Du kannst diesen Beitrag nicht mehr ansehen.'
            : isNotFound
                ? 'Dieser Beitrag ist nicht mehr verfügbar.'
                : 'Der Beitrag konnte gerade nicht geöffnet werden.';
        _isLoading = false;
        _canRetry = !isPermissionDenied && !isNotFound;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationPostTargetScreen: Zielbeitrag konnte nicht geladen werden.',
      );
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      setState(() {
        _post = null;
        _profile = null;
        _errorMessage = 'Der Beitrag konnte gerade nicht geöffnet werden.';
        _isLoading = false;
        _canRetry = true;
      });
    }
  }

  Future<ProfilePostModel?> _resolvePost() async {
    final candidateIds = _candidatePostIds(widget.notification);

    for (final postId in candidateIds) {
      try {
        final post = await _postRepository.fetchPostById(postId: postId);
        if (post != null) return post;
      } on FirebaseException catch (error) {
        debugPrint(
          'NotificationPostTargetScreen: Firebase-Fehler für Kandidat '
          '$postId: ${error.code}',
        );

        // Ein echter Berechtigungs-, Netzwerk- oder Backendfehler darf nicht
        // als "Beitrag existiert nicht" verschluckt werden.
        rethrow;
      }
    }

    return null;
  }

  List<String> _candidatePostIds(LumaNotificationModel notification) {
    final result = <String>[];

    void addCandidate(String? value) {
      final cleaned = value?.trim() ?? '';
      if (cleaned.isEmpty || result.contains(cleaned)) return;
      result.add(cleaned);
    }

    switch (notification.targetType) {
      case LumaNotificationTargetType.comment:
        // Bestehende Daten können den Post entweder in referenceId oder
        // secondaryReferenceId führen. Wir lösen beide defensiv auf, ohne
        // die historische Writer-Semantik zu erfinden.
        addCandidate(notification.secondaryReferenceId);
        addCandidate(notification.referenceId);
        break;
      case LumaNotificationTargetType.post:
        addCandidate(notification.referenceId);
        addCandidate(notification.secondaryReferenceId);
        break;
      case LumaNotificationTargetType.profile:
      case LumaNotificationTargetType.story:
      case LumaNotificationTargetType.group:
      case LumaNotificationTargetType.page:
      case LumaNotificationTargetType.relationship:
      case LumaNotificationTargetType.system:
      case LumaNotificationTargetType.unknown:
        addCandidate(notification.referenceId);
        addCandidate(notification.secondaryReferenceId);
        break;
    }

    return List<String>.unmodifiable(result);
  }

  bool get _isOwnProfile {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final postAuthorId = _post?.authorId.trim() ?? '';

    return currentUserId.isNotEmpty &&
        postAuthorId.isNotEmpty &&
        currentUserId == postAuthorId;
  }

  Future<bool> _editPost(ProfilePostModel post) async {
    if (!_isOwnProfile ||
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

    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (currentUserId.isEmpty) return false;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditPostScreen(
          currentUserId: currentUserId,
          post: post,
          controller: _postsController,
        ),
      ),
    );

    if (!mounted || changed != true) return false;

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
    if (!_isOwnProfile || _postsController.isDeleting) return false;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (currentUserId.isEmpty) return false;

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

    if (confirmed != true || !mounted) return false;

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Beitrag'),
        ),
        body: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final post = _post;
    final profile = _profile;

    if (post == null || profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Beitrag'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.article_outlined,
                  size: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Der Beitrag konnte nicht geöffnet werden.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_canRetry)
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('Erneut versuchen'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Zurück'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ProfilePostDetailScreen(
      profile: profile,
      post: post,
      isOwnProfile: _isOwnProfile,
      onEditPost: _editPost,
      onDeletePost: _deletePost,
    );
  }
}
