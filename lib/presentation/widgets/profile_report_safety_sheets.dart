// Pfad: lib/presentation/widgets/profile_report_safety_sheets.dart

import 'package:flutter/material.dart';

import 'profile_sheet_action_button.dart';
import 'profile_sheet_handle.dart';

class ProfileReportSafetySheets {
  const ProfileReportSafetySheets._();

  static Future<void> showReportProfileSheet({
    required BuildContext context,
    required bool isViewingOwnProfile,
    required ValueChanged<String> onShowSnackBar,
  }) async {
    Navigator.of(context).maybePop();

    if (isViewingOwnProfile) {
      onShowSnackBar('Dein eigenes Profil kann nicht gemeldet werden.');
      return;
    }

    final reasons = <String>[
      'Belästigung oder Mobbing',
      'Fake-Profil oder Identitätsmissbrauch',
      'Hass, Gewalt oder Bedrohung',
      'Sexuelle oder unangemessene Inhalte',
      'Spam oder Betrug',
      'Etwas anderes',
    ];

    String selectedReason = reasons.first;
    final detailsController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ProfileSheetHandle(),
                      Text(
                        'Profil melden',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Wähle den passendsten Grund. Meldungen sollten konkret sein, damit sie später sauber geprüft werden können.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.62),
                          fontSize: 13,
                          height: 1.36,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final reason in reasons) ...[
                        _ProfileReportReasonTile(
                          label: reason,
                          selected: selectedReason == reason,
                          onTap: () {
                            setSheetState(() {
                              selectedReason = reason;
                            });
                          },
                        ),
                        const SizedBox(height: 7),
                      ],
                      const SizedBox(height: 5),
                      TextField(
                        controller: detailsController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 260,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 13.5,
                          height: 1.32,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Optional: Was ist passiert?',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.42),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: colorScheme.surface.withValues(alpha: 0.74),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.12),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();

                                onShowSnackBar(
                                  'Meldung vorgemerkt: $selectedReason',
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Melden',
                                style: TextStyle(
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
              ),
            );
          },
        );
      },
    ).whenComplete(detailsController.dispose);
  }

  static void showProfileSafetyInfoSheet({
    required BuildContext context,
  }) {
    Navigator.of(context).maybePop();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfileSheetHandle(),
                Text(
                  'Profil-Sicherheit',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Blockieren und Melden sind UI-seitig final vorbereitet. Für echte produktive Moderation muss die Meldung später zusätzlich in Firestore oder einem Moderationsservice gespeichert werden.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.66),
                    fontSize: 13,
                    height: 1.40,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ProfileSheetActionButton(
                  label: 'Verstanden',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileReportReasonTile extends StatelessWidget {
  const _ProfileReportReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.10)
          : colorScheme.surface.withValues(alpha: isDark ? 0.34 : 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: colorScheme.primary.withValues(alpha: 0.060),
        highlightColor: colorScheme.primary.withValues(alpha: 0.030),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.20)
                  : colorScheme.outline.withValues(alpha: isDark ? 0.10 : 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.40),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.86),
                    fontSize: 13.2,
                    height: 1.20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
