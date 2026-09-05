// Pfad: lib/features/profile/presentation/profile_edit_post_screen.dart

import 'package:flutter/material.dart';

import '../application/profile_posts_controller.dart';
import '../domain/profile_post_model.dart';

class ProfileEditPostScreen extends StatefulWidget {
  const ProfileEditPostScreen({
    super.key,
    required this.currentUserId,
    required this.post,
    required this.controller,
  });

  final String currentUserId;
  final ProfilePostModel post;
  final ProfilePostsController controller;

  @override
  State<ProfileEditPostScreen> createState() => _ProfileEditPostScreenState();
}

class _ProfileEditPostScreenState extends State<ProfileEditPostScreen> {
  late final TextEditingController _textController;
  late ProfilePostVisibility _visibility;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.post.contentText);
    _visibility = widget.post.visibility;
    _textController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSave {
    if (_isSaving) return false;

    final text = _textController.text.trim();
    if (text.length > 420) return false;

    final hasExistingMedia = widget.post.hasImage || widget.post.hasVideo;
    if (text.isEmpty && !hasExistingMedia) return false;

    return text != widget.post.contentText.trim() ||
        _visibility != widget.post.visibility;
  }

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() {
      _isSaving = true;
    });

    final saved = await widget.controller.updatePost(
      currentUserId: widget.currentUserId,
      post: widget.post,
      text: _textController.text,
      visibility: _visibility,
    );

    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.errorMessage ??
                'Der Beitrag konnte gerade nicht gespeichert werden.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = 420 - _textController.text.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beitrag bearbeiten'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            PopupMenuButton<ProfilePostVisibility>(
              initialValue: _visibility,
              onSelected: (value) {
                setState(() {
                  _visibility = value;
                });
              },
              itemBuilder: (context) => const <PopupMenuEntry<ProfilePostVisibility>>[
                PopupMenuItem(
                  value: ProfilePostVisibility.public,
                  child: Text('Öffentlich'),
                ),
                PopupMenuItem(
                  value: ProfilePostVisibility.friends,
                  child: Text('Freunde'),
                ),
                PopupMenuItem(
                  value: ProfilePostVisibility.private,
                  child: Text('Nur ich'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _visibilityIcon(_visibility),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _visibilityLabel(_visibility),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              autofocus: true,
              minLines: 5,
              maxLines: null,
              maxLength: 420,
              decoration: const InputDecoration(
                hintText: 'Was möchtest du teilen?',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$remaining',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: remaining < 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (widget.post.hasImage) ...<Widget>[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  widget.post.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Das vorhandene Bild bleibt unverändert.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (widget.post.hasVideo) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                height: 96,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.play_circle_outline_rounded),
                    SizedBox(width: 8),
                    Text('Vorhandenes Video bleibt unverändert'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _visibilityLabel(ProfilePostVisibility visibility) {
    switch (visibility) {
      case ProfilePostVisibility.public:
        return 'Öffentlich';
      case ProfilePostVisibility.friends:
        return 'Freunde';
      case ProfilePostVisibility.private:
        return 'Nur ich';
    }
  }

  static IconData _visibilityIcon(ProfilePostVisibility visibility) {
    switch (visibility) {
      case ProfilePostVisibility.public:
        return Icons.public_rounded;
      case ProfilePostVisibility.friends:
        return Icons.people_outline_rounded;
      case ProfilePostVisibility.private:
        return Icons.lock_outline_rounded;
    }
  }
}
