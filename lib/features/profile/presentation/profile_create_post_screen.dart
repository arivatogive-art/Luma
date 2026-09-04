// Pfad: lib/features/profile/presentation/profile_create_post_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../application/profile_posts_controller.dart';
import '../domain/profile_model.dart';
import '../domain/profile_post_model.dart';

class ProfileCreatePostScreen extends StatefulWidget {
  const ProfileCreatePostScreen({
    super.key,
    required this.profile,
    required this.controller,
  });

  final ProfileModel profile;
  final ProfilePostsController controller;

  @override
  State<ProfileCreatePostScreen> createState() =>
      _ProfileCreatePostScreenState();
}

class _ProfileCreatePostScreenState extends State<ProfileCreatePostScreen> {
  static const int _maxLength = 420;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  ProfilePostVisibility _visibility = ProfilePostVisibility.public;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isPickingImage = false;

  bool get _canPublish {
    final text = _textController.text.trim();
    final hasContent = text.isNotEmpty || _selectedImage != null;

    return hasContent &&
        text.length <= _maxLength &&
        !_isPickingImage &&
        !widget.controller.isCreating;
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleChanged);
    widget.controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_handleChanged);
    widget.controller.removeListener(_handleChanged);
    _textController.dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    if (_isPickingImage || widget.controller.isCreating) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        _showMessage('Das ausgewählte Bild ist leer.');
        return;
      }

      if (bytes.length > _maxImageBytes) {
        _showMessage('Das Bild darf maximal 10 MB groß sein.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (error, stackTrace) {
      debugPrint('ProfileCreatePostScreen: Bildauswahl fehlgeschlagen.');
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage('Das Bild konnte nicht ausgewählt werden.');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _removeImage() {
    if (widget.controller.isCreating) return;

    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  Future<void> _publish() async {
    if (!_canPublish) return;

    final selectedImage = _selectedImage;

    final didCreate = selectedImage == null
        ? await widget.controller.createTextPost(
            currentUserId: widget.profile.uid,
            username: widget.profile.displayName.trim().isNotEmpty
                ? widget.profile.displayName.trim()
                : widget.profile.username.trim(),
            userAvatarUrl: widget.profile.profileImageUrl,
            text: _textController.text,
            visibility: _visibility,
          )
        : await widget.controller.createImagePost(
            currentUserId: widget.profile.uid,
            username: widget.profile.displayName.trim().isNotEmpty
                ? widget.profile.displayName.trim()
                : widget.profile.username.trim(),
            userAvatarUrl: widget.profile.profileImageUrl,
            text: _textController.text,
            imageFile: selectedImage,
            visibility: _visibility,
          );

    if (!mounted) return;

    if (didCreate) {
      Navigator.of(context).pop(true);
      return;
    }

    final message = widget.controller.errorMessage ??
        'Dein Beitrag konnte gerade nicht veröffentlicht werden.';

    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  String _visibilityLabel(ProfilePostVisibility visibility) {
    switch (visibility) {
      case ProfilePostVisibility.public:
        return 'Öffentlich';
      case ProfilePostVisibility.friends:
        return 'Freunde';
      case ProfilePostVisibility.private:
        return 'Nur ich';
    }
  }

  IconData _visibilityIcon(ProfilePostVisibility visibility) {
    switch (visibility) {
      case ProfilePostVisibility.public:
        return Icons.public_rounded;
      case ProfilePostVisibility.friends:
        return Icons.people_alt_outlined;
      case ProfilePostVisibility.private:
        return Icons.lock_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final avatarUrl = profile.profileImageUrl.trim();
    final selectedImageBytes = _selectedImageBytes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beitrag erstellen'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                  child: avatarUrl.isEmpty
                      ? Text(
                          profile.displayName.trim().isEmpty
                              ? 'L'
                              : profile.displayName.trim()[0].toUpperCase(),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.displayName.trim().isEmpty
                            ? 'Luma Nutzer'
                            : profile.displayName.trim(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PopupMenuButton<ProfilePostVisibility>(
                        initialValue: _visibility,
                        onSelected: widget.controller.isCreating
                            ? null
                            : (value) {
                                setState(() {
                                  _visibility = value;
                                });
                              },
                        itemBuilder: (context) {
                          return ProfilePostVisibility.values
                              .map(
                                (value) =>
                                    PopupMenuItem<ProfilePostVisibility>(
                                  value: value,
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        _visibilityIcon(value),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(_visibilityLabel(value)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(growable: false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.dividerColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                _visibilityIcon(_visibility),
                                size: 17,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _visibilityLabel(_visibility),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _textController,
              autofocus: true,
              minLines: _selectedImage == null ? 6 : 3,
              maxLines: null,
              maxLength: _maxLength,
              enabled: !widget.controller.isCreating,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Was möchtest du teilen?',
                border: InputBorder.none,
                counterText: '',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_textController.text.length}/$_maxLength',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _textController.text.length > _maxLength
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_selectedImage != null && selectedImageBytes != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: <Widget>[
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.memory(
                        selectedImageBytes,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.92,
                        ),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Bild entfernen',
                          onPressed: widget.controller.isCreating
                              ? null
                              : _removeImage,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _isPickingImage || widget.controller.isCreating
                  ? null
                  : _pickImage,
              icon: _isPickingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _selectedImage == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.photo_outlined,
                    ),
              label: Text(
                _selectedImage == null
                    ? 'Foto hinzufügen'
                    : 'Anderes Foto auswählen',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _canPublish ? _publish : null,
                child: widget.controller.isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Posten',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
