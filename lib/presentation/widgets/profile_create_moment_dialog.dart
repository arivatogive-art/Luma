// Pfad: lib/presentation/widgets/profile_create_moment_dialog.dart

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/profile_moment_repository.dart';
import '../../domain/models/private_profile_model.dart';
import '../../domain/models/profile_moment_model.dart';

class ProfileCreateMomentDialog {
  const ProfileCreateMomentDialog._();

  static const int _maxTextLength = 420;
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const String _momentMediaRoot = 'profile_moment_media';

  static void show({
    required BuildContext context,
    required String displayName,
    required String currentViewedUserId,
    required ProfileMomentRepository profileMomentRepository,
    required Future<List<PrivateProfileModel>?> Function({
      required List<PrivateProfileModel> selectedFriends,
    }) showTagFriendsPickerDialog,
    required ValueChanged<String> onTaggedFriendTap,
  }) {
    final controller = TextEditingController();
    final imagePicker = ImagePicker();
    final storage = FirebaseStorage.instance;

    List<PrivateProfileModel> selectedTaggedFriends =
        const <PrivateProfileModel>[];
    String selectedVisibilityLabel = 'Öffentlich';
    IconData selectedVisibilityIcon = Icons.public_rounded;
    String? selectedMoodLabel;
    String? selectedMoodIconKey;
    IconData? selectedMoodIcon;
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isPosting = false;

    Future<_ProfileMomentUploadResult> uploadMomentImage({
      required String userId,
      required String momentId,
      required Uint8List bytes,
      required String? imageName,
    }) async {
      final cleanedUserId = userId.trim();
      final cleanedMomentId = momentId.trim();

      if (cleanedUserId.isEmpty || cleanedMomentId.isEmpty) {
        throw ArgumentError('Profil oder Beitrag konnte nicht bestimmt werden.');
      }

      if (bytes.isEmpty) {
        throw ArgumentError('Das Foto konnte nicht gelesen werden.');
      }

      if (bytes.length > _maxImageBytes) {
        throw ArgumentError('Das Foto darf maximal 10 MB groß sein.');
      }

      final reference = storage
          .ref()
          .child(_momentMediaRoot)
          .child(cleanedUserId)
          .child(cleanedMomentId)
          .child('image.jpg');

      final metadata = SettableMetadata(
        contentType: _contentTypeForImageName(imageName),
        customMetadata: {
          'userId': cleanedUserId,
          'momentId': cleanedMomentId,
          'scope': 'profile_moment_image',
        },
      );

      final uploadTask = await reference.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return _ProfileMomentUploadResult(
        downloadUrl: downloadUrl,
        storagePath: uploadTask.ref.fullPath,
      );
    }

    Future<void> deleteUploadedMomentImage(String storagePath) async {
      final cleanedPath = storagePath.trim();
      if (cleanedPath.isEmpty) return;

      try {
        await storage.ref(cleanedPath).delete();
      } on FirebaseException catch (error) {
        if (error.code == 'object-not-found') return;
        rethrow;
      }
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final isDark = theme.brightness == Brightness.dark;
            final text = controller.text.trim();
            final hasImage = selectedImageBytes != null;
            final canPost = (text.isNotEmpty || hasImage) &&
                text.length <= _maxTextLength &&
                !isPosting;
            final cleanDisplayName =
                displayName.trim().isEmpty ? 'Du' : displayName.trim();
            final firstName = _firstNameFromDisplayName(cleanDisplayName);

            Future<void> pickPhoto() async {
              if (isPosting) return;

              try {
                final pickedImage = await imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 88,
                  maxWidth: 1800,
                  maxHeight: 1800,
                );

                if (pickedImage == null) return;

                final bytes = await pickedImage.readAsBytes();

                if (bytes.isEmpty) {
                  if (!context.mounted) return;
                  _showSnackBar(context, 'Dieses Foto konnte nicht gelesen werden.');
                  return;
                }

                if (bytes.length > _maxImageBytes) {
                  if (!context.mounted) return;
                  _showSnackBar(context, 'Das Foto darf maximal 10 MB groß sein.');
                  return;
                }

                setSheetState(() {
                  selectedImageBytes = bytes;
                  selectedImageName = pickedImage.name;
                });
              } catch (error) {
                if (!context.mounted) return;
                _showSnackBar(context, 'Foto konnte nicht ausgewählt werden.');
              }
            }

            Future<void> submitPost() async {
              if (!canPost) return;

              final userId = currentViewedUserId.trim();

              if (userId.isEmpty) {
                _showSnackBar(context, 'Profil konnte nicht bestimmt werden.');
                return;
              }

              setSheetState(() {
                isPosting = true;
              });

              final momentId =
                  'moment_${DateTime.now().microsecondsSinceEpoch}';
              _ProfileMomentUploadResult? uploadedImage;

              try {
                final imageBytes = selectedImageBytes;
                if (imageBytes != null) {
                  uploadedImage = await uploadMomentImage(
                    userId: userId,
                    momentId: momentId,
                    bytes: imageBytes,
                    imageName: selectedImageName,
                  );
                }

                await profileMomentRepository.createProfileMoment(
                  userId: userId,
                  momentId: momentId,
                  text: text,
                  moodLabel: selectedMoodLabel ?? '',
                  moodIconKey: selectedMoodIconKey ?? '',
                  mediaType: uploadedImage == null
                      ? ProfileMomentMediaType.none
                      : ProfileMomentMediaType.image,
                  mediaUrl: uploadedImage?.downloadUrl ?? '',
                  taggedFriendIds: selectedTaggedFriends
                      .map((friend) => friend.userId.trim())
                      .where((userId) => userId.isNotEmpty)
                      .toSet()
                      .toList(growable: false),
                );

                if (!context.mounted) return;

                Navigator.of(dialogContext).pop();

                _showSnackBar(context, 'Beitrag wurde veröffentlicht.');
              } catch (error) {
                if (uploadedImage != null) {
                  await deleteUploadedMomentImage(uploadedImage.storagePath);
                }

                if (!context.mounted) return;

                setSheetState(() {
                  isPosting = false;
                });

                _showSnackBar(
                  context,
                  'Beitrag konnte nicht veröffentlicht werden.',
                );
              }
            }

            return Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                  maxHeight: 760,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surfaceContainerHigh
                        : const Color(0xFFFFFCF8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? colorScheme.outline.withValues(alpha: 0.16)
                          : const Color(0xFFE7DBCF),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(
                          alpha: isDark ? 0.26 : 0.10,
                        ),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CreatePostDialogHeader(
                          title: 'Neuer Beitrag',
                          canPost: canPost,
                          isPosting: isPosting,
                          onClose: isPosting
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          onPost: submitPost,
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              14,
                              16,
                              16 + MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CreatePostAuthorRow(
                                  displayName: cleanDisplayName,
                                  selectedMoodLabel: selectedMoodLabel,
                                  selectedMoodIcon: selectedMoodIcon,
                                  visibilityLabel: selectedVisibilityLabel,
                                  visibilityIcon: selectedVisibilityIcon,
                                  onVisibilityChanged: ({
                                    required String label,
                                    required IconData icon,
                                  }) {
                                    setSheetState(() {
                                      selectedVisibilityLabel = label;
                                      selectedVisibilityIcon = icon;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                _CreatePostEditorCard(
                                  controller: controller,
                                  enabled: !isPosting,
                                  firstName: firstName,
                                  onChanged: () => setSheetState(() {}),
                                ),
                                _CreatePostSelectionSummary(
                                  moodLabel: selectedMoodLabel,
                                  moodIcon: selectedMoodIcon,
                                  taggedFriends: selectedTaggedFriends,
                                  onTaggedFriendTap: onTaggedFriendTap,
                                ),
                                if (hasImage) ...[
                                  const SizedBox(height: 12),
                                  _CreatePostPhotoPreview(
                                    imageBytes: selectedImageBytes!,
                                    imageName: selectedImageName,
                                    onRemove: isPosting
                                        ? null
                                        : () {
                                            setSheetState(() {
                                              selectedImageBytes = null;
                                              selectedImageName = null;
                                            });
                                          },
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _CreatePostCharacterLine(
                                  currentLength: controller.text.trim().length,
                                  maxLength: _maxTextLength,
                                ),
                                const SizedBox(height: 12),
                                _CreatePostAddOnsPanel(
                                  hasPhoto: hasImage,
                                  taggedFriendsCount:
                                      selectedTaggedFriends.length,
                                  selectedMoodLabel: selectedMoodLabel,
                                  selectedMoodIcon: selectedMoodIcon,
                                  onPhotoTap: pickPhoto,
                                  onTagFriendsTap: () async {
                                    if (isPosting) return;

                                    final selectedFriends =
                                        await showTagFriendsPickerDialog(
                                      selectedFriends: selectedTaggedFriends,
                                    );

                                    if (selectedFriends == null) return;

                                    setSheetState(() {
                                      selectedTaggedFriends = selectedFriends;
                                    });
                                  },
                                  onMoodSelected: (mood) {
                                    if (isPosting) return;

                                    setSheetState(() {
                                      selectedMoodLabel = mood.label;
                                      selectedMoodIconKey = mood.iconKey;
                                      selectedMoodIcon = mood.icon;
                                    });
                                  },
                                  onClearMood: () {
                                    if (isPosting) return;

                                    setSheetState(() {
                                      selectedMoodLabel = null;
                                      selectedMoodIconKey = null;
                                      selectedMoodIcon = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  static String _contentTypeForImageName(String? imageName) {
    final value = imageName?.trim().toLowerCase() ?? '';

    if (value.endsWith('.png')) return 'image/png';
    if (value.endsWith('.webp')) return 'image/webp';
    if (value.endsWith('.jpg') || value.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    return 'image/jpeg';
  }

  static String _firstNameFromDisplayName(String displayName) {
    final cleanName = displayName.trim();

    if (cleanName.isEmpty || cleanName == 'Du') return '';

    return cleanName.split(RegExp(r'\s+')).first.trim();
  }

  static void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }
}

class _ProfileMomentUploadResult {
  final String downloadUrl;
  final String storagePath;

  const _ProfileMomentUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });
}

class _CreatePostDialogHeader extends StatelessWidget {
  const _CreatePostDialogHeader({
    required this.title,
    required this.canPost,
    required this.isPosting,
    required this.onClose,
    required this.onPost,
  });

  final String title;
  final bool canPost;
  final bool isPosting;
  final VoidCallback? onClose;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh
            : const Color(0xFFFFFCF8),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? colorScheme.outline.withValues(alpha: 0.13)
                : const Color(0xFFE9DED2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: 'Zurück',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -0.16,
              ),
            ),
          ),
          TextButton(
            onPressed: canPost ? onPost : null,
            child: isPosting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colorScheme.primary,
                    ),
                  )
                : Text(
                    'Veröffentlichen',
                    style: TextStyle(
                      color: canPost
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.38),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostAuthorRow extends StatelessWidget {
  const _CreatePostAuthorRow({
    required this.displayName,
    required this.selectedMoodLabel,
    required this.selectedMoodIcon,
    required this.visibilityLabel,
    required this.visibilityIcon,
    required this.onVisibilityChanged,
  });

  final String displayName;
  final String? selectedMoodLabel;
  final IconData? selectedMoodIcon;
  final String visibilityLabel;
  final IconData visibilityIcon;
  final void Function({
    required String label,
    required IconData icon,
  }) onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cleanMoodLabel = selectedMoodLabel?.trim() ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreatePostAvatar(displayName: displayName),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 16.2,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        letterSpacing: -0.10,
                      ),
                    ),
                    if (cleanMoodLabel.isNotEmpty) ...[
                      Text(
                        'fühlt sich',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.58),
                          fontSize: 12.7,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      Icon(
                        selectedMoodIcon ?? Icons.emoji_emotions_outlined,
                        color: colorScheme.primary,
                        size: 16,
                      ),
                      Text(
                        cleanMoodLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 12.7,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                _CreatePostVisibilityChip(
                  label: visibilityLabel,
                  icon: visibilityIcon,
                  onChanged: onVisibilityChanged,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreatePostEditorCard extends StatelessWidget {
  const _CreatePostEditorCard({
    required this.controller,
    required this.enabled,
    required this.firstName,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String firstName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hint = firstName.trim().isEmpty
        ? 'Was möchtest du teilen?'
        : 'Was möchtest du teilen, $firstName?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 142,
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.16)
            : const Color(0xFFFFFCF8),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? colorScheme.outline.withValues(alpha: 0.10)
                : const Color(0xFFEDE4DA),
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLength: ProfileCreateMomentDialog._maxTextLength,
        maxLines: 8,
        minLines: 4,
        enabled: enabled,
        onChanged: (_) => onChanged(),
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        cursorColor: colorScheme.primary,
        cursorWidth: 2,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface,
          fontSize: 23,
          height: 1.26,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.18,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.62),
            fontSize: 23,
            height: 1.26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.18,
          ),
          counterText: '',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _CreatePostVisibilityChip extends StatelessWidget {
  const _CreatePostVisibilityChip({
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final void Function({
    required String label,
    required IconData icon,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<_VisibilityOption>(
      tooltip: 'Sichtbarkeit auswählen',
      onSelected: (option) {
        onChanged(label: option.label, icon: option.icon);
      },
      color: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      itemBuilder: (context) {
        return const [
          PopupMenuItem<_VisibilityOption>(
            value: _VisibilityOption(
              label: 'Öffentlich',
              description: 'Alle können diesen Profilbeitrag sehen.',
              icon: Icons.public_rounded,
            ),
            child: _VisibilityMenuItem(
              label: 'Öffentlich',
              description: 'Alle können diesen Profilbeitrag sehen.',
              icon: Icons.public_rounded,
            ),
          ),
          PopupMenuItem<_VisibilityOption>(
            value: _VisibilityOption(
              label: 'Freunde',
              description: 'Nur bestätigte Freunde können ihn sehen.',
              icon: Icons.group_rounded,
            ),
            child: _VisibilityMenuItem(
              label: 'Freunde',
              description: 'Nur bestätigte Freunde können ihn sehen.',
              icon: Icons.group_rounded,
            ),
          ),
          PopupMenuItem<_VisibilityOption>(
            value: _VisibilityOption(
              label: 'Nur ich',
              description: 'Nur du kannst diesen Beitrag sehen.',
              icon: Icons.lock_rounded,
            ),
            child: _VisibilityMenuItem(
              label: 'Nur ich',
              description: 'Nur du kannst diesen Beitrag sehen.',
              icon: Icons.lock_rounded,
            ),
          ),
        ];
      },
      child: _VisibilityChipBody(
        label: label,
        icon: icon,
      ),
    );
  }
}

class _VisibilityChipBody extends StatelessWidget {
  const _VisibilityChipBody({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.38)
            : const Color(0xFFF4EEE7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.10)
              : const Color(0xFFE2D6C9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: colorScheme.onSurface.withValues(alpha: 0.62),
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.72),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.52),
            size: 15,
          ),
        ],
      ),
    );
  }
}

class _VisibilityOption {
  const _VisibilityOption({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}

class _VisibilityMenuItem extends StatelessWidget {
  const _VisibilityMenuItem({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          color: colorScheme.primary,
          size: 18,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w600,
                  height: 1.22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreatePostAvatar extends StatelessWidget {
  const _CreatePostAvatar({
    required this.displayName,
  });

  final String displayName;

  String get _initial {
    final cleanName = displayName.trim();
    if (cleanName.isEmpty) return 'L';

    return String.fromCharCode(cleanName.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
      ),
    );
  }
}

class _CreatePostPhotoPreview extends StatelessWidget {
  const _CreatePostPhotoPreview({
    required this.imageBytes,
    required this.imageName,
    required this.onRemove,
  });

  final Uint8List imageBytes;
  final String? imageName;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Image.memory(
            imageBytes,
            width: double.infinity,
            height: 230,
            fit: BoxFit.cover,
          ),
          if (imageName != null && imageName!.trim().isNotEmpty)
            Positioned(
              left: 10,
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  imageName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: 9,
              right: 9,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.68),
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreatePostCharacterLine extends StatelessWidget {
  const _CreatePostCharacterLine({
    required this.currentLength,
    required this.maxLength,
  });

  final int currentLength;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOverLimit = currentLength > maxLength;

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            minHeight: 3,
            borderRadius: BorderRadius.circular(999),
            value: (currentLength / maxLength).clamp(0.0, 1.0),
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.07),
            valueColor: AlwaysStoppedAnimation<Color>(
              isOverLimit ? colorScheme.error : colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$currentLength/$maxLength',
          style: theme.textTheme.labelSmall?.copyWith(
            color: isOverLimit
                ? colorScheme.error
                : colorScheme.onSurface.withValues(alpha: 0.48),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CreatePostSelectionSummary extends StatelessWidget {
  const _CreatePostSelectionSummary({
    required this.moodLabel,
    required this.moodIcon,
    required this.taggedFriends,
    required this.onTaggedFriendTap,
  });

  final String? moodLabel;
  final IconData? moodIcon;
  final List<PrivateProfileModel> taggedFriends;
  final ValueChanged<String> onTaggedFriendTap;

  @override
  Widget build(BuildContext context) {
    final cleanMoodLabel = moodLabel?.trim() ?? '';
    final hasMood = cleanMoodLabel.isNotEmpty;
    final hasTaggedFriends = taggedFriends.isNotEmpty;

    if (!hasMood && !hasTaggedFriends) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 7, bottom: 2),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          if (hasMood)
            _CreatePostSummaryChip(
              icon: moodIcon ?? Icons.emoji_emotions_outlined,
              label: cleanMoodLabel,
            ),
          for (final friend in taggedFriends.take(4))
            _CreatePostSummaryChip(
              icon: Icons.person_outline_rounded,
              label: friend.displayName.trim().isEmpty
                  ? 'Freund'
                  : friend.displayName.trim(),
              onTap: () => onTaggedFriendTap(friend.userId),
            ),
          if (taggedFriends.length > 4)
            _CreatePostSummaryChip(
              icon: Icons.group_outlined,
              label: '+${taggedFriends.length - 4}',
            ),
        ],
      ),
    );
  }
}

class _CreatePostSummaryChip extends StatelessWidget {
  const _CreatePostSummaryChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.primary.withValues(alpha: 0.11)
            : colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.13),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontSize: 11.8,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }
}

class _CreatePostAddOnsPanel extends StatelessWidget {
  const _CreatePostAddOnsPanel({
    required this.hasPhoto,
    required this.taggedFriendsCount,
    required this.selectedMoodLabel,
    required this.selectedMoodIcon,
    required this.onPhotoTap,
    required this.onTagFriendsTap,
    required this.onMoodSelected,
    required this.onClearMood,
  });

  final bool hasPhoto;
  final int taggedFriendsCount;
  final String? selectedMoodLabel;
  final IconData? selectedMoodIcon;
  final VoidCallback onPhotoTap;
  final VoidCallback onTagFriendsTap;
  final ValueChanged<_CreatePostMoodOption> onMoodSelected;
  final VoidCallback onClearMood;

  static const List<_CreatePostMoodOption> _moodOptions = [
    _CreatePostMoodOption(
      label: 'glücklich',
      iconKey: 'happy',
      icon: Icons.sentiment_satisfied_alt_rounded,
    ),
    _CreatePostMoodOption(
      label: 'dankbar',
      iconKey: 'grateful',
      icon: Icons.favorite_border_rounded,
    ),
    _CreatePostMoodOption(
      label: 'nachdenklich',
      iconKey: 'thoughtful',
      icon: Icons.psychology_alt_outlined,
    ),
    _CreatePostMoodOption(
      label: 'unglücklich',
      iconKey: 'unhappy',
      icon: Icons.sentiment_dissatisfied_rounded,
    ),
    _CreatePostMoodOption(
      label: 'müde',
      iconKey: 'tired',
      icon: Icons.nightlight_round,
    ),
    _CreatePostMoodOption(
      label: 'motiviert',
      iconKey: 'motivated',
      icon: Icons.bolt_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final hasMood = selectedMoodLabel?.trim().isNotEmpty ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;

        return GridView.count(
          crossAxisCount: isWide ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: isWide ? 2.2 : 1.85,
          children: [
            _CreatePostActionCard(
              icon: Icons.photo_library_outlined,
              title: hasPhoto ? 'Foto ändern' : 'Foto',
              subtitle: hasPhoto ? 'Ausgewählt' : 'Aus Galerie wählen',
              selected: hasPhoto,
              onTap: onPhotoTap,
            ),
            _CreatePostActionCard(
              icon: Icons.person_add_alt_1_outlined,
              title: taggedFriendsCount > 0
                  ? '$taggedFriendsCount markiert'
                  : 'Freunde',
              subtitle: taggedFriendsCount > 0
                  ? 'Markierungen bearbeiten'
                  : 'Freunde markieren',
              selected: taggedFriendsCount > 0,
              onTap: onTagFriendsTap,
            ),
            PopupMenuButton<_CreatePostMoodOption>(
              tooltip: 'Gefühl auswählen',
              onSelected: onMoodSelected,
              itemBuilder: (context) {
                final colorScheme = Theme.of(context).colorScheme;

                return [
                  for (final mood in _moodOptions)
                    PopupMenuItem<_CreatePostMoodOption>(
                      value: mood,
                      child: Row(
                        children: [
                          Icon(
                            mood.icon,
                            color: colorScheme.primary,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Text('fühlt sich ${mood.label}'),
                        ],
                      ),
                    ),
                  if (hasMood)
                    PopupMenuItem<_CreatePostMoodOption>(
                      enabled: false,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          onClearMood();
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.close_rounded,
                              color: colorScheme.error,
                              size: 19,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Gefühl entfernen',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ),
                ];
              },
              child: _CreatePostActionCard(
                icon: selectedMoodIcon ?? Icons.emoji_emotions_outlined,
                title: hasMood ? selectedMoodLabel! : 'Stimmung',
                subtitle: hasMood ? 'Ausgewählt' : 'Gefühl hinzufügen',
                selected: hasMood,
                onTap: null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CreatePostActionCard extends StatelessWidget {
  const _CreatePostActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: colorScheme.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.10)
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.35)
                  : colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 13.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.58),
                        fontSize: 11.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePostMoodOption {
  const _CreatePostMoodOption({
    required this.label,
    required this.iconKey,
    required this.icon,
  });

  final String label;
  final String iconKey;
  final IconData icon;
}
