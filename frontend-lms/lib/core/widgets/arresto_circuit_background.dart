import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Premium futuristic backdrop: faint PCB circuit traces, glowing nodes,
/// slow-drifting particles and soft radial glows — all drawn on a single
/// canvas for GPU efficiency. Sits behind app content; never intercepts input.
///
/// The trace graph is generated once (seeded, deterministic) so it stays stable
/// across rebuilds. Only particle positions + glow drift animate, inside a
/// RepaintBoundary, so it won't force sibling widgets to repaint.
class ArrestoCircuitBackground extends StatefulWidget {
  final Widget child;
  const ArrestoCircuitBackground({super.key, required this.child});

  @override
  State<ArrestoCircuitBackground> createState() =>
      _ArrestoCircuitBackgroundState();
}

class _ArrestoCircuitBackgroundState extends State<ArrestoCircuitBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final _CircuitModel _model;

  @override
  void initState() {
    super.initState();
    _model = _CircuitModel.generate(seed: 7);
    // One slow loop drives every particle via per-particle phase offsets.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient wash
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E0E10),
                  Color(0xFF111113),
                  Color(0xFF0C0C0E),
                ],
              ),
            ),
          ),
        ),
        // Animated circuit layer — isolated so its 60fps repaint is cheap and
        // does not bubble up to the content above it.
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => CustomPaint(
                  painter: _CircuitPainter(_model, _ctrl.value),
                  isComplex: true,
                  willChange: true,
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _Trace {
  final List<Offset> pts; // normalized [0,1] polyline
  final List<double> cum; // cumulative normalized length
  final double total;
  const _Trace(this.pts, this.cum, this.total);

  Offset at(double t) {
    if (pts.length < 2) return pts.first;
    final target = t * total;
    for (int i = 1; i < cum.length; i++) {
      if (cum[i] >= target) {
        final segLen = cum[i] - cum[i - 1];
        final f = segLen <= 0 ? 0.0 : (target - cum[i - 1]) / segLen;
        return Offset.lerp(pts[i - 1], pts[i], f)!;
      }
    }
    return pts.last;
  }
}

class _Particle {
  final int trace;
  final double speed; // loops per animation cycle
  final double phase;
  final bool amber;
  const _Particle(this.trace, this.speed, this.phase, this.amber);
}

class _CircuitModel {
  final List<_Trace> traces;
  final List<Offset> nodes; // normalized
  final List<_Particle> particles;
  const _CircuitModel(this.traces, this.nodes, this.particles);

  static _CircuitModel generate({required int seed}) {
    final rnd = math.Random(seed);
    const cols = 16, rows = 10;
    final traces = <_Trace>[];
    final nodes = <Offset>[];

    Offset cell(int c, int r) => Offset(c / cols, r / rows);

    // Build ~18 right-angle traces via short grid random-walks.
    for (int t = 0; t < 18; t++) {
      int c = rnd.nextInt(cols + 1);
      int r = rnd.nextInt(rows + 1);
      final pts = <Offset>[cell(c, r)];
      final segs = 2 + rnd.nextInt(4);
      bool horiz = rnd.nextBool();
      for (int s = 0; s < segs; s++) {
        final step = (1 + rnd.nextInt(4)) * (rnd.nextBool() ? 1 : -1);
        if (horiz) {
          c = (c + step).clamp(0, cols);
        } else {
          r = (r + step).clamp(0, rows);
        }
        final p = cell(c, r);
        if (p != pts.last) pts.add(p);
        horiz = !horiz;
      }
      if (pts.length < 2) continue;

      final cum = <double>[0];
      double total = 0;
      for (int i = 1; i < pts.length; i++) {
        total += (pts[i] - pts[i - 1]).distance;
        cum.add(total);
      }
      traces.add(_Trace(pts, cum, total));
      nodes.add(pts.first);
      nodes.add(pts.last);
    }

    // Particles ride the traces at varied slow speeds.
    final particles = <_Particle>[];
    for (int i = 0; i < 22; i++) {
      final tr = rnd.nextInt(traces.length);
      particles.add(_Particle(
        tr,
        0.6 + rnd.nextDouble() * 1.6,
        rnd.nextDouble(),
        rnd.nextInt(3) == 0, // ~1/3 amber, rest cool white
      ));
    }

    return _CircuitModel(traces, nodes, particles);
  }
}

// ── Painter ─────────────────────────────────────────────────────────────────

class _CircuitPainter extends CustomPainter {
  final _CircuitModel m;
  final double t; // 0..1
  _CircuitPainter(this.m, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset px(Offset n) => Offset(n.dx * w, n.dy * h);

    // ── Soft radial glows (slow drift) ──
    final drift = math.sin(t * 2 * math.pi);
    _glow(canvas, Offset(w * (0.18 + 0.02 * drift), h * 0.12), w * 0.42,
        ArrestoColors.amber.withOpacity(0.055));
    _glow(canvas, Offset(w * (0.86 - 0.02 * drift), h * 0.9), w * 0.5,
        ArrestoColors.orange.withOpacity(0.045));
    _glow(canvas, Offset(w * 0.5, h * 0.5), w * 0.6,
        const Color(0xFF3B82F6).withOpacity(0.02));

    // ── Traces ──
    final tracePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.035);
    for (final tr in m.traces) {
      final path = Path()..moveTo(px(tr.pts.first).dx, px(tr.pts.first).dy);
      for (int i = 1; i < tr.pts.length; i++) {
        final p = px(tr.pts[i]);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, tracePaint);
    }

    // ── Nodes ──
    final nodeFill = Paint()..color = Colors.white.withOpacity(0.06);
    final nodeRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = ArrestoColors.amber.withOpacity(0.10);
    for (final n in m.nodes) {
      final p = px(n);
      canvas.drawCircle(p, 2.2, nodeFill);
      canvas.drawCircle(p, 3.6, nodeRing);
    }

    // ── Particles (glowing pulses travelling the traces) ──
    for (final part in m.particles) {
      if (part.trace >= m.traces.length) continue;
      final tr = m.traces[part.trace];
      final prog = (t * part.speed + part.phase) % 1.0;
      final p = px(tr.at(prog));
      final base = part.amber ? ArrestoColors.amber : const Color(0xFFBFE3FF);
      // fade in/out near the ends of each loop
      final edge = (math.sin(prog * math.pi)).clamp(0.0, 1.0);
      canvas.drawCircle(
          p, 6.5, Paint()..color = base.withOpacity(0.10 * edge)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(p, 1.7, Paint()..color = base.withOpacity(0.85 * edge));
    }
  }

  void _glow(Canvas canvas, Offset c, double r, Color color) {
    final rect = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter old) => old.t != t;
}
