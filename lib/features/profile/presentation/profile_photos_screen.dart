// Pfad: lib/features/profile/presentation/profile_photos_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../application/profile_gallery_controller.dart';
import '../data/profile_photo_repository.dart';
import '../domain/profile_model.dart';
import '../domain/profile_photo_model.dart';

class ProfilePhotosScreen extends StatefulWidget {
  const ProfilePhotosScreen({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    this.initialPhoto,
  });

  final ProfileModel profile;
  final bool isOwnProfile;
  final ProfilePhotoModel? initialPhoto;

  @override
  State<ProfilePhotosScreen> createState() =>
      _ProfilePhotosScreenState();
}

class _ProfilePhotosScreenState extends State<ProfilePhotosScreen> {
  final ProfilePhotoRepository _repository =
      ProfilePhotoRepository();
  late final ProfileGalleryController _galleryController;
  final ImagePicker _picker = ImagePicker();

  List<ProfilePhotoModel> _photos = const <ProfilePhotoModel>[];
  bool _isLoading = true;
  bool _changed = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    _galleryController = ProfileGalleryController()
      ..addListener(_handleGalleryChanged);

    _loadPhotos(openInitial: true);
  }

  @override
  void dispose() {
    _galleryController.removeListener(_handleGalleryChanged);
    _galleryController.dispose();
    super.dispose();
  }

  void _handleGalleryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPhotos({
    bool openInitial = false,
  }) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final photos = await _repository.fetchProfilePhotos(
        userId: widget.profile.uid,
        limit: 120,
      );

      if (!mounted) return;

      setState(() {
        _photos = photos;
        _isLoading = false;
      });

      if (openInitial && widget.initialPhoto != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          final index = _photos.indexWhere(
            (photo) => photo.id == widget.initialPhoto!.id,
          );

          if (index >= 0) {
            _openViewer(index);
          }
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Fotos konnten nicht geladen werden.';
      });
    }
  }

  Future<void> _addPhoto() async {
    if (!widget.isOwnProfile || _galleryController.isBusy) return;

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );

    if (file == null) return;

    final caption = await _askForCaption();
    if (!mounted || caption == null) return;

    final success = await _galleryController.upload(
      profileUserId: widget.profile.uid,
      file: file,
      caption: caption,
    );

    if (!mounted) return;

    if (success) {
      _changed = true;
      await _loadPhotos();
      return;
    }

    _showError();
  }

  Future<String?> _askForCaption() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Foto hinzufügen'),
          content: TextField(
            controller: controller,
            maxLength: 280,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              hintText: 'Optional',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  controller.text.trim(),
                );
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _deletePhoto(ProfilePhotoModel photo) async {
    if (!widget.isOwnProfile || _galleryController.isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Foto entfernen?'),
          content: const Text(
            'Das Foto wird aus deinem Luma-Profil entfernt.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Entfernen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final success = await _galleryController.delete(
      profileUserId: widget.profile.uid,
      photo: photo,
    );

    if (!mounted) return;

    if (success) {
      _changed = true;
      await _loadPhotos();
      return;
    }

    _showError();
  }

  void _showError() {
    final message = _galleryController.errorMessage?.trim();
    if (message == null || message.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProfilePhotoViewer(
          profile: widget.profile,
          photos: _photos,
          initialIndex: index,
          isOwnProfile: widget.isOwnProfile,
          onDelete: widget.isOwnProfile
              ? (photo) async {
                  Navigator.of(context).pop();
                  await _deletePhoto(photo);
                }
              : null,
        ),
      ),
    );
  }

  Future<bool> _handleBack() async {
    Navigator.of(context).pop(_changed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fotos'),
          actions: <Widget>[
            if (widget.isOwnProfile)
              IconButton(
                onPressed:
                    _galleryController.isBusy ? null : _addPhoto,
                tooltip: 'Foto hinzufügen',
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  )
                : _photos.isEmpty
                    ? _EmptyPhotosView(
                        isOwnProfile: widget.isOwnProfile,
                        onAdd: widget.isOwnProfile
                            ? _addPhoto
                            : null,
                      )
                    : Stack(
                        children: <Widget>[
                          GridView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _photos.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                            itemBuilder: (context, index) {
                              final photo = _photos[index];

                              return Material(
                                color: theme.colorScheme
                                    .surfaceContainerHighest,
                                borderRadius:
                                    BorderRadius.circular(10),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () =>
                                      _openViewer(index),
                                  onLongPress:
                                      widget.isOwnProfile &&
                                              photo.isUpload
                                          ? () =>
                                              _deletePhoto(photo)
                                          : null,
                                  child: Hero(
                                    tag:
                                        'profile-photo-${photo.id}',
                                    child: Image.network(
                                      photo.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const Center(
                                          child: Icon(
                                            Icons
                                                .broken_image_outlined,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_galleryController.isBusy)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color(0x33000000),
                                child: Center(
                                  child:
                                      CircularProgressIndicator(),
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }
}

class _ProfilePhotoViewer extends StatefulWidget {
  const _ProfilePhotoViewer({
    required this.profile,
    required this.photos,
    required this.initialIndex,
    required this.isOwnProfile,
    required this.onDelete,
  });

  final ProfileModel profile;
  final List<ProfilePhotoModel> photos;
  final int initialIndex;
  final bool isOwnProfile;
  final Future<void> Function(ProfilePhotoModel photo)? onDelete;

  @override
  State<_ProfilePhotoViewer> createState() =>
      _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<_ProfilePhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;
    _pageController = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.profile.displayName.trim().isEmpty
              ? 'Foto'
              : widget.profile.displayName.trim(),
        ),
        actions: <Widget>[
          if (widget.isOwnProfile &&
              photo.isUpload &&
              widget.onDelete != null)
            IconButton(
              onPressed: () {
                widget.onDelete!(photo);
              },
              tooltip: 'Foto entfernen',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final item = widget.photos[index];

                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Hero(
                      tag: 'profile-photo-${item.id}',
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 48,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (photo.hasCaption)
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Text(
                  photo.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyPhotosView extends StatelessWidget {
  const _EmptyPhotosView({
    required this.isOwnProfile,
    required this.onAdd,
  });

  final bool isOwnProfile;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.photo_library_outlined,
              size: 42,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              isOwnProfile
                  ? 'Du hast noch keine Fotos hinzugefügt.'
                  : 'Noch keine Fotos vorhanden.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (isOwnProfile) ...<Widget>[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                ),
                label: const Text('Foto hinzufügen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
