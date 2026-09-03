// Pfad: lib/presentation/screens/register_screen.dart

import 'package:flutter/material.dart';

import '../../application/register_controller.dart';
import '../widgets/auth_ui_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final RegisterController _controller;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _legalAccepted = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _controller = RegisterController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(
            child: _RegisterBackground(),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final screenHeight = constraints.maxHeight;
                    final isCompactHeight = screenHeight < 760;
                    final isVeryCompactHeight = screenHeight < 660;

                    final topPadding = isVeryCompactHeight
                        ? 16.0
                        : isCompactHeight
                            ? 24.0
                            : 34.0;

                    final cardMaxWidth = constraints.maxWidth >= 520
                        ? 500.0
                        : constraints.maxWidth - 56;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        topPadding,
                        20,
                        isVeryCompactHeight ? 20 : 28,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: screenHeight -
                              topPadding -
                              (isVeryCompactHeight ? 20 : 28),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RegisterWordmark(
                              compact: isCompactHeight,
                            ),
                            SizedBox(
                              height: isVeryCompactHeight
                                  ? 10
                                  : isCompactHeight
                                      ? 14
                                      : 18,
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: cardMaxWidth),
                              child: _RegisterCard(
                                formKey: _formKey,
                                controller: _controller,
                                nameController: _nameController,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                                legalAccepted: _legalAccepted,
                                onLegalAcceptedChanged: (value) {
                                  setState(() {
                                    _legalAccepted = value;
                                  });
                                  _controller.clearMessages();
                                },
                                onSubmit: _submit,
                              ),
                            ),
                            SizedBox(height: isVeryCompactHeight ? 18 : 26),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final success = await _controller.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      acceptedTerms: _legalAccepted,
      acceptedPrivacy: _legalAccepted,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.infoMessage ??
                'Konto erstellt. Bitte bestätige deine E-Mail und melde dich anschließend an.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AuthUiColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

}

class _RegisterBackground extends StatelessWidget {
  const _RegisterBackground();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFBF6),
                ],
                stops: [0.0, 0.66, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RegisterOrangeWavePainter(),
          ),
        ),
      ],
    );
  }
}

class _RegisterOrangeWavePainter extends CustomPainter {
  const _RegisterOrangeWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final waveTopAtSides = size.height * 0.30;
    final waveDipInCenter = size.height * 0.42;

    final wavePath = Path()
      ..moveTo(0, waveTopAtSides)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.42,
        size.width * 0.28,
        waveDipInCenter,
        size.width * 0.50,
        waveDipInCenter,
      )
      ..cubicTo(
        size.width * 0.72,
        waveDipInCenter,
        size.width * 0.84,
        size.height * 0.42,
        size.width,
        waveTopAtSides,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final orangePaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFF4F00);

    canvas.drawPath(wavePath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant _RegisterOrangeWavePainter oldDelegate) {
    return false;
  }
}

class _RegisterWordmark extends StatelessWidget {
  const _RegisterWordmark({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Luma',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AuthUiColors.accent,
        fontSize: compact ? 39 : 44,
        height: 1,
        letterSpacing: compact ? -1.3 : -1.55,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({
    required this.formKey,
    required this.controller,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.legalAccepted,
    required this.onLegalAcceptedChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final RegisterController controller;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool legalAccepted;
  final ValueChanged<bool> onLegalAcceptedChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.94),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F1208).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Konto erstellen',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: AuthUiColors.textPrimary,
                fontSize: 25,
                height: 1.04,
                letterSpacing: -0.9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            _RegisterTextField(
              controller: nameController,
              label: 'Name',
              hintText: 'Dein Name',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              enabled: !controller.isLoading,
              validator: controller.validateName,
              onChanged: (_) => controller.clearMessages(),
            ),
            const SizedBox(height: 13),
            _RegisterTextField(
              controller: emailController,
              label: 'E-Mail-Adresse',
              hintText: 'name@beispiel.de',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !controller.isLoading,
              validator: controller.validateEmail,
              onChanged: (_) => controller.clearMessages(),
            ),
            const SizedBox(height: 13),
            _RegisterTextField(
              controller: passwordController,
              label: 'Passwort',
              hintText: 'Mindestens 6 Zeichen',
              icon: Icons.lock_outline_rounded,
              obscureText: controller.obscurePassword,
              enabled: !controller.isLoading,
              textInputAction: TextInputAction.next,
              suffix: IconButton(
                onPressed: controller.isLoading
                    ? null
                    : controller.togglePasswordVisibility,
                icon: Icon(
                  controller.obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AuthUiColors.textSecondary.withValues(alpha: 0.72),
                  size: 20,
                ),
              ),
              validator: controller.validatePassword,
              onChanged: (_) => controller.clearMessages(),
            ),
            const SizedBox(height: 13),
            _RegisterTextField(
              controller: confirmPasswordController,
              label: 'Passwort bestätigen',
              hintText: 'Passwort wiederholen',
              icon: Icons.lock_reset_rounded,
              obscureText: controller.obscureConfirmPassword,
              enabled: !controller.isLoading,
              textInputAction: TextInputAction.done,
              suffix: IconButton(
                onPressed: controller.isLoading
                    ? null
                    : controller.toggleConfirmPasswordVisibility,
                icon: Icon(
                  controller.obscureConfirmPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AuthUiColors.textSecondary.withValues(alpha: 0.72),
                  size: 20,
                ),
              ),
              validator: (value) => controller.validateConfirmPassword(
                value: value,
                password: passwordController.text,
              ),
              onChanged: (_) => controller.clearMessages(),
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 18),
            _LegalAcceptanceRow(
              value: legalAccepted,
              enabled: !controller.isLoading,
              onChanged: onLegalAcceptedChanged,
            ),
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthStatusBanner.error(
                message: controller.errorMessage!,
              ),
            ],
            if (controller.infoMessage != null) ...[
              const SizedBox(height: 16),
              AuthStatusBanner.info(
                message: controller.infoMessage!,
              ),
            ],
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton.icon(
                    onPressed: controller.isLoading ? null : onSubmit,
                    icon: controller.isLoading
                        ? const SizedBox.shrink()
                        : const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 19,
                          ),
                    label: controller.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Konto erstellen',
                            style: TextStyle(
                              fontSize: 15.8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.14,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFFF4F00),
                      disabledBackgroundColor:
                          AuthUiColors.accent.withValues(alpha: 0.54),
                      foregroundColor: Colors.white,
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.82),
                      shadowColor: Colors.transparent,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                Text(
                  'Bereits registriert?',
                  style: TextStyle(
                    color: AuthUiColors.textSecondary.withValues(alpha: 0.62),
                    fontSize: 12.4,
                    letterSpacing: -0.02,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AuthInlineActionText(
                  text: 'Zum Login',
                  onTap: controller.isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _LegalAcceptanceRow extends StatelessWidget {
  const _LegalAcceptanceRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final mutedColor =
        AuthUiColors.textSecondary.withValues(alpha: enabled ? 0.78 : 0.42);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEADCCF).withValues(alpha: 0.76),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: Checkbox(
              value: value,
              onChanged: enabled
                  ? (checked) => onChanged(checked ?? false)
                  : null,
              activeColor: const Color(0xFFFF4F00),
              checkColor: Colors.white,
              side: BorderSide(
                color: AuthUiColors.textSecondary.withValues(alpha: 0.48),
                width: 1.35,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ich akzeptiere die Nutzungsbedingungen und habe die Datenschutzerklärung gelesen.',
              style: TextStyle(
                color: mutedColor,
                fontSize: 12.5,
                height: 1.48,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _RegisterTextField extends StatelessWidget {
  const _RegisterTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: AuthUiColors.textPrimary,
              fontSize: 12.8,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.06,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          cursorColor: const Color(0xFFFF4F00),
          style: const TextStyle(
            color: AuthUiColors.textPrimary,
            fontSize: 14.8,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.08,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: AuthUiColors.textSecondary.withValues(alpha: 0.48),
              fontSize: 14.6,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.06,
            ),
            prefixIcon: Icon(
              icon,
              color: AuthUiColors.textSecondary.withValues(alpha: 0.74),
              size: 20,
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFFFFCF8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: const Color(0xFFEADCCF).withValues(alpha: 0.76),
                width: 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: const Color(0xFFEADCCF).withValues(alpha: 0.50),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFFF4F00),
                width: 1.25,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFDF5E45),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFDF5E45),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
