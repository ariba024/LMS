import 'package:flutter/material.dart';

/// Draws a seamless, deterministic PCB-style circuit trace pattern.
/// Use as a full-screen background layer under the actual scaffold content.
class CircuitBoardBackground extends StatelessWidget {
  final Widget child;

  const CircuitBoardBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CircuitPainter(),
              isComplex: true,
              willChange: false,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CircuitPainter extends CustomPainter {
  // Trace color: warm light grey, slightly darker than the background
  static const _traceColor = Color(0xFFCECBC2);
  // Pad / junction dot color: a touch darker still
  static const _padColor = Color(0xFFBEBBB2);

  static const double _g = 56.0; // grid cell size

  @override
  void paint(Canvas canvas, Size size) {
    final trace = Paint()
      ..color = _traceColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pad = Paint()
      ..color = _padColor
      ..style = PaintingStyle.fill;

    final cols = (size.width / _g).ceil() + 2;
    final rows = (size.height / _g).ceil() + 2;

    for (int r = -1; r <= rows; r++) {
      for (int c = -1; c <= cols; c++) {
        _drawCell(canvas, trace, pad, c * _g, r * _g, c, r);
      }
    }
  }

  void _drawCell(Canvas canvas, Paint trace, Paint pad,
      double ox, double oy, int col, int row) {
    // Deterministic hash — same grid position always renders the same segment
    final h = ((col.abs() * 31 + row.abs() * 17 + col * row) & 0x7FFF) % 14;
    final g = _g;
    final g2 = g / 2;

    final path = Path();
    final dots = <Offset>[];

    switch (h) {
      case 0: // ── horizontal pass-through
        path.moveTo(ox, oy + g2);
        path.lineTo(ox + g, oy + g2);

      case 1: // │ vertical pass-through
        path.moveTo(ox + g2, oy);
        path.lineTo(ox + g2, oy + g);

      case 2: // ┐ top-left corner
        path.moveTo(ox, oy + g2);
        path.lineTo(ox + g2, oy + g2);
        path.lineTo(ox + g2, oy);
        dots.add(Offset(ox + g2, oy + g2));

      case 3: // └ bottom-left corner (going right and up)
        path.moveTo(ox, oy + g2);
        path.lineTo(ox + g2, oy + g2);
        path.lineTo(ox + g2, oy + g);
        dots.add(Offset(ox + g2, oy + g2));

      case 4: // ┘ bottom-right corner
        path.moveTo(ox + g2, oy + g);
        path.lineTo(ox + g2, oy + g2);
        path.lineTo(ox + g, oy + g2);
        dots.add(Offset(ox + g2, oy + g2));

      case 5: // ┌ top-right corner
        path.moveTo(ox + g2, oy);
        path.lineTo(ox + g2, oy + g2);
        path.lineTo(ox + g, oy + g2);
        dots.add(Offset(ox + g2, oy + g2));

      case 6: // ┤ T-junction (left/right/down)
        path.moveTo(ox, oy + g2);
        path.lineTo(ox + g, oy + g2);
        path.moveTo(ox + g2, oy + g2);
        path.lineTo(ox + g2, oy + g);
        dots.add(Offset(ox + g2, oy + g2));

      case 7: // ├ T-junction (left/right/up)
        path.moveTo(ox, oy + g2);
        path.lineTo(ox + g, oy + g2);
        path.moveTo(ox + g2, oy + g2);
        path.lineTo(ox + g2, oy);
        dots.add(Offset(ox + g2, oy + g2));

      case 8: // ┬ T-junction (up/down/right)
        path.moveTo(ox + g2, oy);
        path.lineTo(ox + g2, oy + g);
        path.moveTo(ox + g2, oy + g2);
        path.lineTo(ox + g, oy + g2);
        dots.add(Offset(ox + g2, oy + g2));

      case 9: // ┼ cross junction
        path.moveTo(ox, oy + g2);
        path.lineTo(ox + g, oy + g2);
        path.moveTo(ox + g2, oy);
        path.lineTo(ox + g2, oy + g);
        // Large solder pad at the cross
        dots.add(Offset(ox + g2, oy + g2));
        canvas.drawCircle(Offset(ox + g2, oy + g2), 3.5, pad);

      case 10: // blank (sparse area)
        break;

      case 11: // blank (more sparsity)
        break;

      case 12: // small IC component outline
        final rect = Rect.fromCenter(
          center: Offset(ox + g2, oy + g2),
          width: g * 0.45,
          height: g * 0.28,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          trace,
        );
        // Lead stubs on left and right
        canvas.drawLine(
            Offset(rect.left, oy + g2 - 5), Offset(ox, oy + g2 - 5), trace);
        canvas.drawLine(
            Offset(rect.left, oy + g2 + 5), Offset(ox, oy + g2 + 5), trace);
        canvas.drawLine(
            Offset(rect.right, oy + g2 - 5), Offset(ox + g, oy + g2 - 5), trace);
        canvas.drawLine(
            Offset(rect.right, oy + g2 + 5), Offset(ox + g, oy + g2 + 5), trace);

      case 13: // via / through-hole pad only
        canvas.drawCircle(Offset(ox + g2, oy + g2), 4.0, pad);
        canvas.drawCircle(Offset(ox + g2, oy + g2), 4.0, trace..style = PaintingStyle.stroke);
        trace..style = PaintingStyle.stroke; // reset
    }

    canvas.drawPath(path, trace);
    for (final dot in dots) {
      canvas.drawCircle(dot, 2.2, pad);
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter old) => false;
}
