// Pfad: lib/features/profile/presentation/profile_edit_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../application/profile_edit_controller.dart';
import '../application/profile_media_controller.dart';
import '../domain/profile_model.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  @override
  State<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final ProfileEditController _controller;
  late final ProfileMediaController _mediaController;

  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _workController;
  late final TextEditingController _educationController;
  late final TextEditingController _websiteController;

  String _avatarUrl = '';
  String _coverUrl = '';
  Uint8List? _avatarPreviewBytes;
  Uint8List? _coverPreviewBytes;
  bool _profileChanged = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();

    _controller = ProfileEditController()
      ..addListener(_handleControllerChanged);

    _mediaController = ProfileMediaController()
      ..addListener(_handleControllerChanged);

    _avatarUrl = widget.profile.profileImageUrl.trim();
    _coverUrl = widget.profile.coverImageUrl.trim();

    _displayNameController =
        TextEditingController(text: widget.profile.displayName);
    _usernameController =
        TextEditingController(text: widget.profile.username);
    _bioController =
        TextEditingController(text: widget.profile.bio);
    _locationController =
        TextEditingController(text: widget.profile.location);
    _workController =
        TextEditingController(text: widget.profile.work);
    _educationController =
        TextEditingController(text: widget.profile.education);
    _websiteController =
        TextEditingController(text: widget.profile.website);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _mediaController.removeListener(_handleControllerChanged);

    _controller.dispose();
    _mediaController.dispose();

    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _workController.dispose();
    _educationController.dispose();
    _websiteController.dispose();

    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickAvatar() async {
    if (_mediaController.isBusy) return;

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );

    if (file == null) return;

    final previewBytes = await file.readAsBytes();
    final success = await _mediaController.uploadAvatar(file);
    if (!mounted) return;

    if (success) {
      setState(() {
        _avatarPreviewBytes = previewBytes;
        _profileChanged = true;
      });
      return;
    }

    _showMediaError();
  }

  Future<void> _pickCover() async {
    if (_mediaController.isBusy) return;

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2400,
    );

    if (file == null) return;

    final previewBytes = await file.readAsBytes();
    final success = await _mediaController.uploadCover(file);
    if (!mounted) return;

    if (success) {
      setState(() {
        _coverPreviewBytes = previewBytes;
        _profileChanged = true;
      });
      return;
    }

    _showMediaError();
  }

  Future<void> _removeAvatar() async {
    final success = await _mediaController.removeAvatar();
    if (!mounted) return;

    if (success) {
      setState(() {
        _avatarUrl = '';
        _avatarPreviewBytes = null;
        _profileChanged = true;
      });
      return;
    }

    _showMediaError();
  }

  Future<void> _removeCover() async {
    final success = await _mediaController.removeCover();
    if (!mounted) return;

    if (success) {
      setState(() {
        _coverUrl = '';
        _coverPreviewBytes = null;
        _profileChanged = true;
      });
      return;
    }

    _showMediaError();
  }

  void _showMediaError() {
    final message = _mediaController.errorMessage?.trim();
    if (message == null || message.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final success = await _controller.save(
      profile: widget.profile,
      displayName: _displayNameController.text,
      username: _usernameController.text,
      bio: _bioController.text,
      location: _locationController.text,
      work: _workController.text,
      education: _educationController.text,
      website: _websiteController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    final message = _controller.errorMessage?.trim();
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _closeEditor() {
    if (_allowPop) return;

    setState(() {
      _allowPop = true;
    });

    Navigator.of(context).pop(_profileChanged ? true : null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _controller.isSaving || _mediaController.isBusy;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeEditor();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: busy ? null : _closeEditor,
            tooltip: 'Zurück',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Profil bearbeiten'),
          actions: <Widget>[
            TextButton(
              onPressed: busy ? null : _save,
              child: _controller.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Speichern'),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: <Widget>[
              Text(
                'Bilder',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _ProfileMediaEditorCard(
                title: 'Profilbild',
                imageUrl: _avatarUrl,
                previewBytes: _avatarPreviewBytes,
                isBusy: _mediaController.operation ==
                    ProfileMediaOperation.uploadingAvatar,
                onChange: busy ? null : _pickAvatar,
                onRemove:
                    busy || _avatarUrl.isEmpty ? null : _removeAvatar,
                circular: true,
              ),
              const SizedBox(height: 12),
              _ProfileMediaEditorCard(
                title: 'Titelbild',
                imageUrl: _coverUrl,
                previewBytes: _coverPreviewBytes,
                isBusy: _mediaController.operation ==
                    ProfileMediaOperation.uploadingCover,
                onChange: busy ? null : _pickCover,
                onRemove:
                    busy || _coverUrl.isEmpty ? null : _removeCover,
                circular: false,
              ),
              const SizedBox(height: 28),
              Text(
                'Profil',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _ProfileEditField(
                controller: _displayNameController,
                label: 'Name',
                icon: Icons.badge_outlined,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              _ProfileEditField(
                controller: _usernameController,
                label: 'Benutzername',
                icon: Icons.alternate_email_rounded,
                maxLength: 40,
                prefixText: '@',
                autocorrect: false,
              ),
              const SizedBox(height: 14),
              _ProfileEditField(
                controller: _bioController,
                label: 'Bio',
                icon: Icons.notes_rounded,
                maxLength: 240,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 26),
              Text(
                'Info',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _ProfileEditField(
                controller: _locationController,
                label: 'Wohnort',
                icon: Icons.location_on_outlined,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              _ProfileEditField(
                controller: _workController,
                label: 'Arbeit',
                icon: Icons.work_outline_rounded,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              _ProfileEditField(
                controller: _educationController,
                label: 'Ausbildung',
                icon: Icons.school_outlined,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              _ProfileEditField(
                controller: _websiteController,
                label: 'Webseite',
                icon: Icons.language_rounded,
                maxLength: 240,
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: busy ? null : _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('Änderungen speichern'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMediaEditorCard extends StatelessWidget {
  const _ProfileMediaEditorCard({
    required this.title,
    required this.imageUrl,
    required this.previewBytes,
    required this.isBusy,
    required this.onChange,
    required this.onRemove,
    required this.circular,
  });

  final String title;
  final String imageUrl;
  final Uint8List? previewBytes;
  final bool isBusy;
  final VoidCallback? onChange;
  final VoidCallback? onRemove;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius:
                BorderRadius.circular(circular ? 999 : 12),
            child: SizedBox(
              width: circular ? 72 : 104,
              height: 72,
              child: previewBytes != null
                  ? Image.memory(
                      previewBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: Color(0x11000000),
                          child: Icon(Icons.broken_image_outlined),
                        );
                      },
                    )
                  : imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const ColoredBox(
                              color: Color(0x11000000),
                              child: Icon(Icons.broken_image_outlined),
                            );
                          },
                        )
                      : ColoredBox(
                          color:
                              theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image_outlined),
                        ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: onChange,
                      child: Text(
                        imageUrl.isEmpty && previewBytes == null
                            ? 'Hinzufügen'
                            : 'Ändern',
                      ),
                    ),
                    if (imageUrl.isNotEmpty || previewBytes != null)
                      TextButton(
                        onPressed: onRemove,
                        child: const Text('Entfernen'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileEditField extends StatelessWidget {
  const _ProfileEditField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.maxLength,
    this.maxLines = 1,
    this.prefixText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLength;
  final int maxLines;
  final String? prefixText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
