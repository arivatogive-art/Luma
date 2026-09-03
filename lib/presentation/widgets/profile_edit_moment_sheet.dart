// Pfad: lib/presentation/widgets/profile_edit_moment_sheet.dart

import 'package:flutter/material.dart';

import 'profile_posts_preview_card.dart' as profile_posts;
import 'profile_sheet_action_button.dart';
import 'profile_sheet_handle.dart';

typedef ProfileEditMomentSaveCallback = Future<void> Function({
  required String text,
  required BuildContext actionContext,
  required BuildContext sheetContext,
});

class ProfileEditMomentSheet {
  const ProfileEditMomentSheet._();

  static void show({
    required BuildContext context,
    required profile_posts.ProfileMomentPreviewData moment,
    required ProfileEditMomentSaveCallback onSave,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = TextEditingController(text: moment.text);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final text = controller.text.trim();

            final canSave = text.isNotEmpty &&
                text.length <= 240 &&
                text != moment.text.trim();

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProfileSheetHandle(),
                    Text(
                      'Moment bearbeiten',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Passe deinen Profilmoment an. Die Änderung wird gespeichert.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.68),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: controller,
                      maxLength: 240,
                      maxLines: 5,
                      minLines: 3,
                      onChanged: (_) => setSheetState(() {}),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        counterStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.58),
                          fontSize: 12,
                        ),
                        hintText: 'Moment bearbeiten',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.48),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                        contentPadding: const EdgeInsets.all(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.10),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(color: colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: ProfileSheetActionButton(
                            label: 'Abbrechen',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: canSave
                                ? () async {
                                    await onSave(
                                      text: text,
                                      actionContext: context,
                                      sheetContext: sheetContext,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: colorScheme.onPrimary,
                              backgroundColor: colorScheme.primary,
                              disabledForegroundColor:
                                  colorScheme.onSurface.withValues(alpha: 0.42),
                              disabledBackgroundColor:
                                  colorScheme.surface.withValues(alpha: 0.78),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            child: const Text(
                              'Speichern',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }
}
