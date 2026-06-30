import 'package:flutter/material.dart';

/// Arresto AI safety robot mascot — drawn entirely with canvas, no image assets.
///
/// Matches the style of the MR Solve card: hard-hat robot with cyan screen eyes,
/// amber accent, thumbs-up pose. Scalable at any [size].
class ArrestoRobotMascot extends StatelessWidget {
  final double size;
  const ArrestoRobotMascot({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _RobotPainter(),
    );
  }
}

class _RobotPainter extends CustomPainter {
  const _RobotPainter();

  static const _amber  = Color(0xFFF5A623);
  static const _orange = Color(0xFFD4880A);
  static const _body   = Color(0xFF22222E);
  static const _bodyLt = Color(0xFF2C2C3C);
  static const _cyan   = Color(0xFF22D3EE);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // ── Ambient glow behind robot ──────────────────────────
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.56),
      h * 0.44,
      Paint()
        ..color = _amber.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // ── Left arm ───────────────────────────────────────────
    _arm(canvas, Rect.fromLTWH(w * 0.03, h * 0.60, w * 0.15, h * 0.27), w);

    // ── Right arm (raised slightly — thumbs up) ────────────
    _arm(canvas, Rect.fromLTWH(w * 0.82, h * 0.57, w * 0.15, h * 0.27), w);
    // Thumb circle on right fist
    canvas.drawCircle(
      Offset(w * 0.895, h * 0.83),
      w * 0.045,
      Paint()
        ..color = _amber.withOpacity(0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(Offset(w * 0.895, h * 0.83), w * 0.032, Paint()..color = _amber);

    // ── Body ───────────────────────────────────────────────
    final bodyR = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.20, h * 0.60, w * 0.60, h * 0.36),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(bodyR, Paint()..color = _body);
    canvas.drawRRect(bodyR, Paint()
      ..color = _amber.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);

    // Chest panel
    final chestR = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.64, w * 0.32, h * 0.21),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(chestR, Paint()..color = _amber.withOpacity(0.10));
    canvas.drawRRect(chestR, Paint()
      ..color = _amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);
    _text(canvas, 'A',
        x: w * 0.50 - w * 0.07, y: h * 0.65,
        fontSize: w * 0.15, color: _amber, bold: true);

    // ── Head ───────────────────────────────────────────────
    final headR = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.22, w * 0.72, h * 0.44),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(headR, Paint()..color = _bodyLt);
    canvas.drawRRect(headR, Paint()
      ..color = _amber.withOpacity(0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);

    // Shine highlight
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.38, h * 0.31), width: w * 0.28, height: h * 0.07),
      Paint()..color = Colors.white.withOpacity(0.06),
    );

    // Eyes
    _eye(canvas, Offset(w * 0.345, h * 0.38), w * 0.092);
    _eye(canvas, Offset(w * 0.655, h * 0.38), w * 0.092);

    // Grill / mouth
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(w * 0.34, h * (0.52 + i * 0.030)),
        Offset(w * 0.66, h * (0.52 + i * 0.030)),
        Paint()
          ..color = _amber.withOpacity(0.22)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Hard hat ───────────────────────────────────────────
    // Dome
    final dome = Path()
      ..moveTo(w * 0.10, h * 0.29)
      ..lineTo(w * 0.15, h * 0.29)
      ..cubicTo(w * 0.17, h * 0.07, w * 0.38, h * 0.03, w * 0.50, h * 0.03)
      ..cubicTo(w * 0.62, h * 0.03, w * 0.83, h * 0.07, w * 0.85, h * 0.29)
      ..lineTo(w * 0.90, h * 0.29)
      ..close();
    canvas.drawPath(dome, Paint()..color = _amber);

    // Brim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.08, h * 0.26, w * 0.84, h * 0.06),
          const Radius.circular(2)),
      Paint()..color = _orange,
    );

    // Small 'A' badge on hat
    _text(canvas, 'A',
        x: w * 0.435, y: h * 0.09,
        fontSize: w * 0.10, color: Colors.white.withOpacity(0.88), bold: true);

    // ── Antenna ────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.476, h * 0.02, w * 0.048, h * 0.06),
          const Radius.circular(2)),
      Paint()..color = _amber,
    );
    // Glow around ball
    canvas.drawCircle(Offset(w * 0.50, h * 0.035), w * 0.062,
      Paint()
        ..color = _amber.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(w * 0.50, h * 0.035), w * 0.044, Paint()..color = _amber);
  }

  void _arm(Canvas canvas, Rect rect, double w) {
    final r = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.065));
    canvas.drawRRect(r, Paint()..color = _body);
    canvas.drawRRect(r, Paint()
      ..color = _amber.withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);
  }

  void _eye(Canvas canvas, Offset c, double r) {
    // Outer glow
    canvas.drawCircle(c, r,
        Paint()
          ..color = _cyan.withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    // Dark background
    canvas.drawCircle(c, r * 0.86, Paint()..color = const Color(0xFF191924));
    // Cyan ring
    canvas.drawCircle(c, r * 0.86,
        Paint()
          ..color = _cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    // Inner glow
    canvas.drawCircle(c, r * 0.42,
        Paint()
          ..color = _cyan.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Bright center dot
    canvas.drawCircle(c, r * 0.28, Paint()..color = _cyan);
    // Specular
    canvas.drawCircle(
        Offset(c.dx - r * 0.24, c.dy - r * 0.24), r * 0.13,
        Paint()..color = Colors.white.withOpacity(0.75));
  }

  void _text(Canvas canvas, String t,
      {required double x,
      required double y,
      required double fontSize,
      required Color color,
      bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _RobotPainter old) => false;
}
