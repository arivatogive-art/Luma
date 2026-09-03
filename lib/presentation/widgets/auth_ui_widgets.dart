import 'package:flutter/material.dart';

import 'luma_background.dart';

class AuthUiColors {
  static const Color background = Color(0xFFFFFCF7);
  static const Color backgroundWarm = Color(0xFFF8F1E8);

  static const Color surface = Color(0xFFFFFBF6);
  static const Color surfaceSoft = Color(0xFFF4EADF);
  static const Color surfaceInput = Color(0xFFFFFEFC);

  static const Color border = Color(0xFFE7D8C8);

  static const Color textPrimary = Color(0xFF241B14);
  static const Color textSecondary = Color(0xFF74675C);
  static const Color textMuted = Color(0xFF9B8E82);

  static const Color accent = Color(0xFFE58A2B);
  static const Color accentDeep = Color(0xFFC96F1F);
  static const Color accentSoft = Color(0x1FE58A2B);

  static const Color error = Color(0xFFD94F4F);
  static const Color errorSoft = Color(0x14D94F4F);

  static const Color info = Color(0xFFE58A2B);
  static const Color infoSoft = Color(0x18E58A2B);
}

class AuthScreenScaffold extends StatelessWidget {
  const AuthScreenScaffold({
    super.key,
    required this.child,
    this.maxWidth = 500,
    this.useSafeArea = true,
    this.useImageBackground = true,
  });

  final Widget child;
  final double maxWidth;
  final bool useSafeArea;
  final bool useImageBackground;

  @override
  Widget build(BuildContext context) {
    final body = useImageBackground
        ? _AuthImageBackground(child: _buildContent())
        : LumaBackground(child: _buildContent());

    final content = Scaffold(
      backgroundColor: AuthUiColors.background,
      body: body,
    );

    if (!useSafeArea) return content;
    return SafeArea(child: content);
  }

  Widget _buildContent() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          child: child,
        ),
      ),
    );
  }
}

class _AuthImageBackground extends StatelessWidget {
  const _AuthImageBackground({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFCF7),
                Color(0xFFFFF8F1),
                Color(0xFFF9EFE5),
              ],
              stops: [0.0, 0.54, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.72, 0.78),
              radius: 0.92,
              colors: [
                Color(0x1BE58A2B),
                Color(0x09E58A2B),
                Color(0x00E58A2B),
              ],
              stops: [0.0, 0.44, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.72, -0.38),
              radius: 0.9,
              colors: [
                Color(0x1DE58A2B),
                Color(0x0BE58A2B),
                Color(0x00E58A2B),
              ],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.18, 0.24),
              radius: 0.72,
              colors: [
                Color(0xC9FFFFFF),
                Color(0x2BFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.52, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class AuthSurfaceCard extends StatelessWidget {
  const AuthSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCFA).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F6A48).withValues(alpha: 0.072),
            blurRadius: 48,
            offset: const Offset(0, 26),
          ),
          BoxShadow(
            color: AuthUiColors.accent.withValues(alpha: 0.024),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.54),
            blurRadius: 14,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.08),
                      AuthUiColors.accent.withValues(alpha: 0.022),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    this.title = 'Luma',
    this.subtitle,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: const TextStyle(
            color: AuthUiColors.accent,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.45,
            height: 1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 9),
          _AuthBrandSubtitle(
            subtitle: subtitle!,
            textAlign: textAlign,
          ),
        ],
      ],
    );
  }
}

class _AuthBrandSubtitle extends StatelessWidget {
  const _AuthBrandSubtitle({
    required this.subtitle,
    required this.textAlign,
  });

  final String subtitle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: AuthUiColors.textSecondary,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.35,
      letterSpacing: -0.08,
    );

    if (subtitle.trim() == 'Stay close') {
      return Text.rich(
        const TextSpan(
          children: [
            TextSpan(
              text: 'Stay ',
              style: TextStyle(
                color: AuthUiColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: 'close',
              style: TextStyle(
                color: AuthUiColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        textAlign: textAlign,
        style: baseStyle.copyWith(
          fontSize: 19,
          letterSpacing: -0.14,
        ),
      );
    }

    if (subtitle.trim() == 'Share your moments') {
      return Text.rich(
        const TextSpan(
          children: [
            TextSpan(text: 'Share '),
            TextSpan(
              text: 'your ',
              style: TextStyle(
                color: AuthUiColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: 'moments'),
          ],
        ),
        textAlign: textAlign,
        style: baseStyle.copyWith(
          color: AuthUiColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Text(
      subtitle,
      textAlign: textAlign,
      style: baseStyle,
    );
  }
}

class AuthSectionTitle extends StatelessWidget {
  const AuthSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.centered = false,
  });

  final String title;
  final String subtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: const TextStyle(
            color: AuthUiColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.72,
            height: 1.1,
          ),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: textAlign,
            style: const TextStyle(
              color: AuthUiColors.textSecondary,
              fontSize: 14,
              height: 1.48,
              letterSpacing: -0.03,
            ),
          ),
        ],
      ],
    );
  }
}

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Kept for compatibility with existing screens. The visual button intentionally
  /// does not render icons to keep the auth actions calmer and more premium.
  final IconData? icon;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _isPressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (!_enabled || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final buttonRadius = BorderRadius.circular(22);

    return AnimatedScale(
      scale: _isPressed ? 0.976 : 1,
      duration: const Duration(milliseconds: 115),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: buttonRadius,
          gradient: _enabled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEFA052),
                    Color(0xFFE58A2B),
                    Color(0xFFD9822F),
                  ],
                  stops: [0.0, 0.56, 1.0],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AuthUiColors.accent.withValues(alpha: 0.3),
                    AuthUiColors.accentDeep.withValues(alpha: 0.22),
                  ],
                ),
          boxShadow: [
            if (_enabled) ...[
              BoxShadow(
                color: AuthUiColors.accent.withValues(
                  alpha: _isPressed ? 0.10 : 0.16,
                ),
                blurRadius: _isPressed ? 12 : 19,
                offset: Offset(0, _isPressed ? 6 : 10),
              ),
              BoxShadow(
                color: const Color(0xFFFFD9AF).withValues(alpha: 0.16),
                blurRadius: 13,
                offset: const Offset(0, -3),
              ),
            ],
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: buttonRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: _enabled ? 0.28 : 0.08),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: buttonRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: _enabled ? 0.16 : 0),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Listener(
                onPointerDown: (_) => _setPressed(true),
                onPointerUp: (_) => _setPressed(false),
                onPointerCancel: (_) => _setPressed(false),
                child: ElevatedButton(
                  onPressed: _enabled ? widget.onPressed : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: buttonRadius,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    textStyle: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.12,
                    ),
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.1,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(widget.label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthSecondaryButton extends StatefulWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Kept for compatibility with existing screens. The visual button intentionally
  /// does not render icons to keep the auth actions calmer and more premium.
  final IconData? icon;

  @override
  State<AuthSecondaryButton> createState() => _AuthSecondaryButtonState();
}

class _AuthSecondaryButtonState extends State<AuthSecondaryButton> {
  bool _isPressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final buttonRadius = BorderRadius.circular(22);

    return AnimatedScale(
      scale: _isPressed ? 0.976 : 1,
      duration: const Duration(milliseconds: 115),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _isPressed ? 0.54 : 0.64),
          borderRadius: buttonRadius,
          border: Border.all(
            color: AuthUiColors.border.withValues(
              alpha: _isPressed ? 0.42 : 0.24,
            ),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8F6A48).withValues(
                alpha: _isPressed ? 0.025 : 0.052,
              ),
              blurRadius: _isPressed ? 8 : 13,
              offset: Offset(0, _isPressed ? 4 : 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.78),
              blurRadius: 9,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: OutlinedButton(
            onPressed: widget.onPressed,
            style: OutlinedButton.styleFrom(
              side: BorderSide.none,
              backgroundColor: Colors.transparent,
              foregroundColor: AuthUiColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: buttonRadius,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.08,
              ),
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class AuthMutedInfoBox extends StatelessWidget {
  const AuthMutedInfoBox({
    super.key,
    required this.child,
    this.icon = Icons.shield_outlined,
  });

  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AuthUiColors.surfaceSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AuthUiColors.border.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AuthUiColors.accent,
            size: 18,
          ),
          const SizedBox(width: 11),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class AuthDividerLabel extends StatelessWidget {
  const AuthDividerLabel({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AuthUiColors.border.withValues(alpha: 0.72),
            thickness: 1,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: AuthUiColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AuthUiColors.border.withValues(alpha: 0.72),
            thickness: 1,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class AuthInlineActionText extends StatelessWidget {
  const AuthInlineActionText({
    super.key,
    required this.text,
    this.onTap,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            color: isEnabled
                ? AuthUiColors.accent.withValues(alpha: 0.86)
                : AuthUiColors.textMuted.withValues(alpha: 0.58),
            fontSize: 12.7,
            fontWeight: FontWeight.w800,
            height: 1.4,
            letterSpacing: -0.04,
          ),
        ),
      ),
    );
  }
}

class AuthFeatureBullet extends StatelessWidget {
  const AuthFeatureBullet({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: AuthUiColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AuthUiColors.accent.withValues(alpha: 0.18),
                blurRadius: 9,
              ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AuthUiColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.34,
                  letterSpacing: -0.04,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AuthUiColors.textSecondary,
                  fontSize: 13,
                  height: 1.44,
                  letterSpacing: -0.03,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return _AuthFieldShell(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        validator: validator,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        cursorColor: AuthUiColors.accent,
        style: const TextStyle(
          color: AuthUiColors.textPrimary,
          fontSize: 15,
          height: 1.2,
          letterSpacing: -0.05,
        ),
        decoration: _authInputDecoration(
          hintText: hintText,
          prefixIcon: prefixIcon,
        ),
      ),
    );
  }
}

class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.obscureText,
    required this.onToggleVisibility,
    this.textInputAction,
    this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return _AuthFieldShell(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        validator: validator,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        obscureText: obscureText,
        textInputAction: textInputAction,
        cursorColor: AuthUiColors.accent,
        style: const TextStyle(
          color: AuthUiColors.textPrimary,
          fontSize: 15,
          height: 1.2,
          letterSpacing: -0.05,
        ),
        decoration: _authInputDecoration(
          hintText: hintText,
          prefixIcon: prefixIcon,
          suffixIcon: IconButton(
            splashRadius: 20,
            onPressed: enabled ? onToggleVisibility : null,
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AuthUiColors.textSecondary,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthFieldShell extends StatelessWidget {
  const _AuthFieldShell({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AuthUiColors.textPrimary,
            fontSize: 12.3,
            fontWeight: FontWeight.w800,
            height: 1.25,
            letterSpacing: -0.08,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class AuthStatusBanner extends StatelessWidget {
  const AuthStatusBanner._({
    super.key,
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
  });

  factory AuthStatusBanner.error({
    Key? key,
    required String message,
  }) {
    return AuthStatusBanner._(
      key: key,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: AuthUiColors.errorSoft,
      borderColor: AuthUiColors.error.withValues(alpha: 0.24),
      iconColor: AuthUiColors.error,
    );
  }

  factory AuthStatusBanner.info({
    Key? key,
    required String message,
  }) {
    return AuthStatusBanner._(
      key: key,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: AuthUiColors.infoSoft,
      borderColor: AuthUiColors.info.withValues(alpha: 0.24),
      iconColor: AuthUiColors.info,
    );
  }

  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AuthUiColors.textPrimary,
                fontSize: 13,
                height: 1.42,
                letterSpacing: -0.02,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _authInputDecoration({
  required String hintText,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  final borderRadius = BorderRadius.circular(20);

  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: AuthUiColors.textMuted.withValues(alpha: 0.82),
      fontSize: 14,
      height: 1.2,
      letterSpacing: -0.04,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(
            prefixIcon,
            color: AuthUiColors.textSecondary.withValues(alpha: 0.86),
            size: 19,
          ),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFFFFCFB).withValues(alpha: 0.94),
    contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AuthUiColors.border.withValues(alpha: 0.12),
        width: 0.6,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AuthUiColors.accent.withValues(alpha: 0.18),
        width: 0.9,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AuthUiColors.error.withValues(alpha: 0.58),
        width: 1,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AuthUiColors.error.withValues(alpha: 0.74),
        width: 1.15,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AuthUiColors.border.withValues(alpha: 0.34),
        width: 1,
      ),
    ),
    errorStyle: const TextStyle(
      color: AuthUiColors.error,
      fontSize: 12,
      height: 1.32,
      letterSpacing: -0.02,
    ),
  );
}
