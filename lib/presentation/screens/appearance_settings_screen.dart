// Pfad: lib/presentation/screens/appearance_settings_screen.dart

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../application/app_appearance_controller.dart';
import '../../application/settings_state.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  final AppAppearanceController _controller = AppAppearanceController.instance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectMode(AppAppearanceMode mode) async {
    if (_saving || _controller.appearanceMode == mode) return;

    setState(() => _saving = true);

    try {
      await _controller.setAppearanceMode(mode);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Die Darstellung wurde geändert, konnte aber nicht gespeichert werden.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? LumaTheme.darkBackground : const Color(0xFFF8F4EF);
    final textPrimary =
        isDark ? LumaTheme.darkTextPrimary : const Color(0xFF102033);
    final textSecondary =
        isDark ? LumaTheme.darkTextSecondary : const Color(0xFF756D65);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Darstellung',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Text(
            'Wähle, wie Luma auf diesem Gerät dargestellt wird.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 13.2,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _AppearanceOption(
            title: 'System',
            subtitle: 'Luma folgt der Einstellung deines Geräts.',
            icon: Icons.settings_suggest_outlined,
            selected:
                _controller.appearanceMode == AppAppearanceMode.system,
            enabled: !_saving,
            onTap: () => _selectMode(AppAppearanceMode.system),
          ),
          _AppearanceOption(
            title: 'Hell',
            subtitle: 'Luma verwendet dauerhaft die helle Darstellung.',
            icon: Icons.light_mode_outlined,
            selected: _controller.appearanceMode == AppAppearanceMode.light,
            enabled: !_saving,
            onTap: () => _selectMode(AppAppearanceMode.light),
          ),
          _AppearanceOption(
            title: 'Dunkel',
            subtitle: 'Luma verwendet dauerhaft die dunkle Darstellung.',
            icon: Icons.dark_mode_outlined,
            selected: _controller.appearanceMode == AppAppearanceMode.dark,
            enabled: !_saving,
            onTap: () => _selectMode(AppAppearanceMode.dark),
          ),
        ],
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileColor =
        isDark ? LumaTheme.darkSurfaceSoft : const Color(0xFFFFFCF8);
    final borderColor = selected
        ? LumaTheme.lumaOrange
        : isDark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFE8DCCE);
    final textPrimary =
        isDark ? LumaTheme.darkTextPrimary : const Color(0xFF102033);
    final textSecondary =
        isDark ? LumaTheme.darkTextSecondary : const Color(0xFF756D65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: LumaTheme.lumaOrange.withValues(
                      alpha: isDark ? 0.11 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: LumaTheme.lumaOrange,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12.3,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: selected
                      ? LumaTheme.lumaOrange
                      : textSecondary.withValues(alpha: 0.55),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
