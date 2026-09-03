// Pfad: lib/presentation/widgets/luma_background.dart
//
// NUR DER HINTERGRUND.
// Rekonstruktion nach der gelieferten Originalreferenz.
// Keine Logos, keine Karten, keine Buttons, keine zusätzlichen UI-Elemente.
//
// Aufbau der Referenz:
// 1. Creme/weiß als Grundfläche
// 2. Dunkles Navy von links unten
// 3. Weiches Grau/Lavendel links mittig
// 4. Warmes Orange/Gold von rechts
// 5. Sehr heller weißer Mittelpunkt
//
// Das child bleibt vollständig unangetastet.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class LumaBackground extends StatelessWidget {
  const LumaBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: CustomPaint(
            painter: _LumaOriginalBackgroundPainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class _LumaOriginalBackgroundPainter extends CustomPainter {
  const _LumaOriginalBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1) Sehr heller, leicht warmer Grundton.
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFCF9),
          Color(0xFFFFF9F4),
          Color(0xFFFFF7F0),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, basePaint);

    // 2) Navy links unten. In der Vorlage sitzt der dunkelste Punkt
    //    außerhalb/knapp unterhalb der linken unteren Ecke.
    _drawRadial(
      canvas: canvas,
      size: size,
      center: Offset(
        size.width * -0.10,
        size.height * 0.92,
      ),
      radius: size.longestSide * 0.63,
      colors: const [
        Color(0xFF102033),
        Color(0xF0122033),
        Color(0xC7182940),
        Color(0x6B31445E),
        Color(0x0031445E),
      ],
      stops: const [0.0, 0.26, 0.48, 0.70, 1.0],
    );

    // 3) Zweiter dunkler Navy-Kern weiter unten links.
    _drawRadial(
      canvas: canvas,
      size: size,
      center: Offset(
        size.width * 0.03,
        size.height * 1.08,
      ),
      radius: size.longestSide * 0.42,
      colors: const [
        Color(0xFF071522),
        Color(0xD70B1A29),
        Color(0x71152538),
        Color(0x00152538),
      ],
      stops: const [0.0, 0.34, 0.66, 1.0],
    );

    // 4) Weicher grau-bläulicher Übergang links mittig.
    _drawRadial(
      canvas: canvas,
      size: size,
      center: Offset(
        size.width * -0.03,
        size.height * 0.43,
      ),
      radius: size.longestSide * 0.45,
      colors: const [
        Color(0x878F93A0),
        Color(0x5F9CA0AB),
        Color(0x299DA1AA),
        Color(0x009DA1AA),
      ],
      stops: const [0.0, 0.38, 0.72, 1.0],
    );

    // 5) Großer orange-goldener Bereich rechts.
    //    Der intensivste Bereich liegt rechts der Bildmitte.
    _drawRadial(
      canvas: canvas,
      size: size,
      center: Offset(
        size.width * 1.05,
        size.height * 0.32,
      ),
      radius: size.longestSide * 0.60,
      colors: const [
        Color(0xF6FF9D1F),
        Color(0xDCFFAE38),
        Color(0xAFFFBC58),
        Color(0x67FFD18B),
        Color(0x00FFD18B),
      ],
      stops: const [0.0, 0.24, 0.48, 0.72, 1.0],
    );

    // 6) Orange-Kern am rechten oberen/mittleren Rand.
    _drawRadial(
      canvas: canvas,
      size: size,
      center: Offset(
        size.width * 0.97,
        size.height * 0.15,
      ),
      radius: size.longestSide * 0.34,
      colors: const [
        Color(0xB8FF8A08),
        Color(0x84FFA01D),
        Color(0x34FFB64E),
        Color(0x00FFB64E),
      ],
      stops: const [0.0, 0.36, 0.70, 1.0],
    );

    // 7) Goldener Übergang rechts unten.
    _drawRadial(
      canvas: canvas,
      size: size,
      center: Offset(
        size.width * 1.02,
        size.height * 0.73,
      ),
      radius: size.longestSide * 0.39,
      colors: const [
        Color(0x86FFC45E),
        Color(0x5BFFD78E),
        Color(0x20FFE6BC),
        Color(0x00FFE6BC),
      ],
      stops: const [0.0, 0.40, 0.72, 1.0],
    );

    // 8) Sehr großer weißer Mittelpunkt.
    //    Das ist entscheidend für die Referenz: nicht orange -> navy direkt,
    //    sondern ein stark aufgehellter, milchiger Innenbereich.
    _drawRadial(
      canvas: canvas,
      size: size,
      center: Offset(
        size.width * 0.47,
        size.height * 0.34,
      ),
      radius: size.longestSide * 0.53,
      colors: const [
        Color(0xFFFFFFFF),
        Color(0xF7FFFFFF),
        Color(0xD9FFFDFC),
        Color(0x72FFFDF9),
        Color(0x00FFFDF9),
      ],
      stops: const [0.0, 0.26, 0.50, 0.76, 1.0],
    );

    // 9) Zweite weiße Wolke links oben, damit der obere Bereich
    //    genauso ruhig und fast reinweiß wirkt wie auf der Vorlage.
    _drawRadial(
      canvas: canvas,
      size: size,
      center: Offset(
        size.width * 0.25,
        size.height * 0.10,
      ),
      radius: size.longestSide * 0.42,
      colors: const [
        Color(0xF7FFFFFF),
        Color(0xCFFFFFFF),
        Color(0x5AFFFFFF),
        Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.40, 0.72, 1.0],
    );

    // 10) Leichte warme Milchigkeit über alles, damit keine harte
    //     "Computergrafik-Kante" sichtbar bleibt.
    final veilPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x18FFFFFF),
          Color(0x08FFFFFF),
          Color(0x10FFF4E8),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, veilPaint);
  }

  void _drawRadial({
    required Canvas canvas,
    required Size size,
    required Offset center,
    required double radius,
    required List<Color> colors,
    required List<double> stops,
  }) {
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        center,
        radius,
        colors,
        stops,
        TileMode.clamp,
      );

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(
    covariant _LumaOriginalBackgroundPainter oldDelegate,
  ) {
    return false;
  }
}
