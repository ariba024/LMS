import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

/// Official Arresto brand lockup.
///
/// Renders the EXACT uploaded brand asset at `assets/images/arresto_logo.png`
/// — never cropped, stretched, recolored, or gradient-applied (BoxFit.contain
/// preserves the original proportions, colors, spacing, typography and icon).
///
/// Height is responsive by default (desktop 44 / tablet 38 / mobile 32) unless
/// an explicit [height] is provided. High filterQuality keeps it crisp on
/// Retina/HiDPI displays — supply a 2×/3× PNG for best sharpness.
///
/// A vector placeholder is drawn ONLY if the asset file is not present yet, so
/// the UI never shows a broken image; drop the real file in to replace it.
class ArrestoBrandLogo extends StatelessWidget {
  /// Explicit logo height in logical px. When null, sizing is responsive.
  final double? height;

  /// Kept for source compatibility with older call sites; ignored because the
  /// uploaded asset already includes the tagline.
  final bool showTagline;

  const ArrestoBrandLogo({super.key, this.height, this.showTagline = true});

  double _responsiveHeight(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1024) return 44; // desktop
    if (w >= 640) return 38; // tablet
    return 32; // mobile
  }

  @override
  Widget build(BuildContext context) {
    final h = height ?? _responsiveHeight(context);
    return Image.asset(
      'assets/images/arresto_logo.png',
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _VectorFallback(height: h),
    );
  }
}

/// Temporary vector stand-in shown only until the official PNG is dropped in.
class _VectorFallback extends StatelessWidget {
  final double height;
  const _VectorFallback({required this.height});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: height,
          child: CustomPaint(painter: _ArrestoMarkPainter()),
        ),
        SizedBox(width: height * 0.30),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('arresto',
                style: GoogleFonts.inter(
                  fontSize: height * 0.62,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.0,
                  color: Colors.white,
                )),
            SizedBox(height: height * 0.06),
            Text('Transform Safety Digitally',
                style: GoogleFonts.inter(
                  fontSize: height * 0.24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1.0,
                  color: ArrestoColors.amber,
                )),
          ],
        ),
      ],
    );
  }
}

class _ArrestoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final amber = ArrestoColors.amber;
    final orange = ArrestoColors.orange;
    final fill = Paint()..color = amber;
    final thick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = amber;
    canvas.drawCircle(Offset(s * 0.60, s * 0.20), s * 0.13, fill);
    canvas.drawPath(
        Path()
          ..moveTo(s * 0.58, s * 0.34)
          ..lineTo(s * 0.42, s * 0.60),
        thick);
    canvas.drawPath(
        Path()
          ..moveTo(s * 0.30, s * 0.40)
          ..lineTo(s * 0.52, s * 0.46)
          ..lineTo(s * 0.74, s * 0.34),
        thick..color = orange);
    canvas.drawPath(
        Path()
          ..moveTo(s * 0.42, s * 0.60)
          ..lineTo(s * 0.30, s * 0.82)
          ..moveTo(s * 0.42, s * 0.60)
          ..lineTo(s * 0.56, s * 0.82),
        thick..color = amber);
  }

  @override
  bool shouldRepaint(covariant _ArrestoMarkPainter oldDelegate) => false;
}
