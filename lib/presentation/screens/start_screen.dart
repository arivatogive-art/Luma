// Pfad: lib/presentation/screens/start_screen.dart
//
// FUNKTIONALE LOGIN-FASSUNG:
// Das bestehende visuelle Layout bleibt erhalten.
// Die bisherigen Attrappen-Felder und leeren onPressed-Callbacks werden
// durch echte Eingaben und die wiederhergestellte LoginController-Logik ersetzt.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../application/login_controller.dart';
import 'register_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  static const Color _orange = Color(0xFFFF6A00);
  static const Color _navy = Color(0xFF102033);
  static const Color _muted = Color(0xFF756D65);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final LoginController _controller;

  bool _staySignedIn = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _controller = LoginController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ExactReferenceBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                  ),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 44),
                          _buildCard(context),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        color: _orange,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: _orange.withValues(alpha: 0.18),
            blurRadius: 36,
            spreadRadius: 3,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'L',
        style: TextStyle(
          color: Colors.white,
          fontSize: 64,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -2,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        28,
        32,
        28,
        30,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.13),
            blurRadius: 46,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _EntryField(
              controller: _emailController,
              hintText: 'name@beispiel.de',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_controller.isLoading,
              validator: _controller.validateEmail,
              onChanged: (_) => _controller.clearMessages(),
            ),
            const SizedBox(height: 18),
            _EntryField(
              controller: _passwordController,
              hintText: 'Dein Passwort',
              icon: Icons.lock_outline_rounded,
              obscureText: _controller.obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_controller.isLoading,
              validator: _controller.validatePassword,
              onChanged: (_) => _controller.clearMessages(),
              onSubmitted: (_) => _submit(),
              suffixIcon: _controller.obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffixTap: _controller.togglePasswordVisibility,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                GestureDetector(
                  onTap: _controller.isLoading
                      ? null
                      : () {
                          setState(() {
                            _staySignedIn = !_staySignedIn;
                          });
                        },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _staySignedIn
                          ? _orange
                          : Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _staySignedIn
                            ? _orange
                            : _navy.withValues(alpha: 0.12),
                      ),
                      boxShadow: _staySignedIn
                          ? [
                              BoxShadow(
                                color: _orange.withValues(alpha: 0.20),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: _staySignedIn
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 21,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Angemeldet bleiben',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      _controller.isLoading ? null : _openPasswordReset,
                  child: const Text(
                    'Passwort vergessen?',
                    style: TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              _StatusMessage(
                message: _controller.errorMessage!,
                isError: true,
              ),
            ],
            if (_controller.infoMessage != null) ...[
              const SizedBox(height: 12),
              _StatusMessage(
                message: _controller.infoMessage!,
                isError: false,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: _controller.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _orange.withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _controller.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Anmelden',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _controller.isLoading ? null : _submitGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.72),
                  foregroundColor: _navy,
                  side: BorderSide(
                    color: _navy.withValues(alpha: 0.08),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Mit Google anmelden',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: _navy.withValues(alpha: 0.12),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'oder',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: _navy.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed:
                    _controller.isLoading ? null : _openRegister,
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: _orange,
                ),
                label: const Text(
                  'Konto erstellen',
                  style: TextStyle(
                    color: _orange,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _orange.withValues(alpha: 0.24),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final success = await _controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
      rememberAccount: _staySignedIn,
    );

    if (!mounted || !success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anmeldung erfolgreich.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();

    final success = await _controller.signInWithGoogle(
      rememberAccount: _staySignedIn,
    );

    if (!mounted || !success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google-Anmeldung erfolgreich.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPasswordReset() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte gib zuerst deine E-Mail-Adresse ein.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _controller.sendPasswordReset(email: email);
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: (isError
                ? const Color(0xFFB3261E)
                : const Color(0xFF102033))
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError
              ? const Color(0xFFB3261E)
              : const Color(0xFF102033),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _EntryField extends StatelessWidget {
  const _EntryField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.onSuffixTap,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      cursorColor: _StartScreenState._orange,
      style: const TextStyle(
        color: _StartScreenState._navy,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: _StartScreenState._navy.withValues(alpha: 0.34),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: _StartScreenState._navy.withValues(alpha: 0.45),
        ),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: enabled ? onSuffixTap : null,
                icon: Icon(
                  suffixIcon,
                  color:
                      _StartScreenState._navy.withValues(alpha: 0.42),
                ),
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.64),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 21,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: _StartScreenState._navy.withValues(alpha: 0.07),
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: _StartScreenState._navy.withValues(alpha: 0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: _StartScreenState._orange,
            width: 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: Color(0xFFB3261E),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: Color(0xFFB3261E),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}


class _ExactReferenceBackground extends StatelessWidget {
  const _ExactReferenceBackground();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Grundfläche der Referenz: warmes, sehr helles Off-White.
              const ColoredBox(
                color: Color(0xFFF7F0EC),
              ),

              // Heller Bereich oben links / Mitte.
              _Glow(
                left: -w * 0.18,
                top: -h * 0.20,
                width: w * 1.18,
                height: h * 0.70,
                blur: 95,
                color: const Color(0xFFFFFFFF),
                opacity: 0.88,
              ),

              // Milchiger weißer Mittelpunkt.
              _Glow(
                left: w * 0.10,
                top: h * 0.06,
                width: w * 0.95,
                height: h * 0.72,
                blur: 110,
                color: const Color(0xFFFFFEFC),
                opacity: 0.92,
              ),

              // Orange/Gold rechts oben. In der Referenz deutlich sichtbar.
              _Glow(
                left: w * 0.62,
                top: -h * 0.11,
                width: w * 0.62,
                height: h * 0.58,
                blur: 78,
                color: const Color(0xFFFF9B22),
                opacity: 0.72,
              ),

              // Zweiter Orangebereich rechts mittig, breiter und heller.
              _Glow(
                left: w * 0.70,
                top: h * 0.16,
                width: w * 0.58,
                height: h * 0.48,
                blur: 88,
                color: const Color(0xFFFFBE61),
                opacity: 0.66,
              ),

              // Goldener Übergang nach rechts unten.
              _Glow(
                left: w * 0.76,
                top: h * 0.46,
                width: w * 0.48,
                height: h * 0.38,
                blur: 82,
                color: const Color(0xFFFFD89A),
                opacity: 0.50,
              ),

              // Graublauer Übergang links mittig.
              _Glow(
                left: -w * 0.30,
                top: h * 0.24,
                width: w * 0.72,
                height: h * 0.60,
                blur: 88,
                color: const Color(0xFF8A8E9D),
                opacity: 0.62,
              ),

              // Navy links unten, groß und tief.
              _Glow(
                left: -w * 0.36,
                top: h * 0.52,
                width: w * 0.82,
                height: h * 0.72,
                blur: 78,
                color: const Color(0xFF102033),
                opacity: 0.98,
              ),

              // Dunkler Kern ganz links unten.
              _Glow(
                left: -w * 0.24,
                top: h * 0.72,
                width: w * 0.58,
                height: h * 0.46,
                blur: 60,
                color: const Color(0xFF081522),
                opacity: 0.90,
              ),

              // Helle Cremefläche rechts unten, damit dort NICHT alles grau/navy wird.
              _Glow(
                left: w * 0.50,
                top: h * 0.67,
                width: w * 0.70,
                height: h * 0.48,
                blur: 92,
                color: const Color(0xFFFFF8F2),
                opacity: 0.86,
              ),

              // Sehr sanfter finaler Weißschleier wie in der Referenz.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-0.55, -1.0),
                        end: const Alignment(0.35, 1.0),
                        colors: [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.02),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                        stops: const [0.0, 0.56, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.blur,
    required this.color,
    required this.opacity,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double blur;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: opacity),
            ),
          ),
        ),
      ),
    );
  }
}
