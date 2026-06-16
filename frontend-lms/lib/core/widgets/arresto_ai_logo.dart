import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Official Arresto AI brand mark.
///
/// Renders the amber-gradient rounded-square tile with the white open-book +
/// sparkle mark. Implemented as scalable vector art so it stays crisp at any
/// size / DPI, preserves its square aspect ratio (never stretched or cropped),
/// and reads correctly in both light and dark mode.
///
/// If a raster brand asset is dropped at `assets/images/arresto_ai_logo.png`
/// it is used automatically; otherwise the vector mark is drawn.
class ArrestoAiLogo extends StatelessWidget {
  /// Edge length in logical pixels (the logo is always square).
  final double size;

  /// When false, only the book+sparkle mark is drawn (no gradient tile) — use
  /// this when placing the mark on an already-coloured surface.
  final bool tile;

  /// Mark colour override. Defaults to white on a tile, brand orange off-tile.
  final Color? markColor;

  const ArrestoAiLogo({super.key, this.size = 28, this.tile = true, this.markColor});

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _ArrestoAiMarkPainter(
        markColor ?? (tile ? Colors.white : ArrestoColors.orange),
      ),
    );

    if (!tile) {
      return SizedBox.square(dimension: size, child: mark);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/arresto_ai_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        // No real asset yet → draw the vector tile instead (no console noise
        // once a PNG is added at the path above).
        errorBuilder: (_, __, ___) => _VectorTile(size: size, radius: radius),
      ),
    );
  }
}

class _VectorTile extends StatelessWidget {
  final double size;
  final double radius;
  const _VectorTile({required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ArrestoColors.amber, ArrestoColors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: CustomPaint(painter: _ArrestoAiMarkPainter(Colors.white)),
      ),
    );
  }
}

class _ArrestoAiMarkPainter extends CustomPainter {
  final Color color;
  _ArrestoAiMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ── Sparkle (4-point star) top-centre ──
    final cx = s * 0.5;
    final sy = s * 0.205;
    final r = s * 0.135; // long axis
    final w = s * 0.045; // waist
    final spark = Path()
      ..moveTo(cx, sy - r)
      ..quadraticBezierTo(cx + w, sy - w, cx + r, sy)
      ..quadraticBezierTo(cx + w, sy + w, cx, sy + r)
      ..quadraticBezierTo(cx - w, sy + w, cx - r, sy)
      ..quadraticBezierTo(cx - w, sy - w, cx, sy - r)
      ..close();
    canvas.drawPath(spark, fill);

    // ── Open book ──
    final topL = Offset(s * 0.50, s * 0.45);
    final topR = Offset(s * 0.50, s * 0.45);
    // Left page
    final left = Path()
      ..moveTo(topL.dx, topL.dy)
      ..lineTo(s * 0.19, s * 0.51)
      ..lineTo(s * 0.19, s * 0.77)
      ..lineTo(s * 0.50, s * 0.71);
    // Right page
    final right = Path()
      ..moveTo(topR.dx, topR.dy)
      ..lineTo(s * 0.81, s * 0.51)
      ..lineTo(s * 0.81, s * 0.77)
      ..lineTo(s * 0.50, s * 0.71);
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
    // Spine
    canvas.drawLine(Offset(s * 0.50, s * 0.45), Offset(s * 0.50, s * 0.71), stroke);
  }

  @override
  bool shouldRepaint(covariant _ArrestoAiMarkPainter old) => old.color != color;
}
