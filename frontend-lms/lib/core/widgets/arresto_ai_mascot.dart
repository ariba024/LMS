import 'package:flutter/material.dart';
import '../theme/colors.dart';

const _kMascotAsset = 'assets/images/arresto_ai_mascot.png';

/// Full Arresto AI robot mascot (hard-hat safety robot, transparent background).
///
/// Renders the brand mascot at [size] with no crop — use for hero cards and
/// empty states where the whole character should be visible. Falls back to a
/// simple amber tile with a smart-toy glyph if the asset is missing.
class ArrestoAiMascot extends StatelessWidget {
  final double size;
  const ArrestoAiMascot({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _kMascotAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.smart_toy_rounded,
        size: size * 0.7,
        color: ArrestoColors.amber,
      ),
    );
  }
}

/// Compact mascot avatar for chat headers, launcher buttons and message rows.
///
/// Crops to the robot's head/shoulders (top of the image) inside a
/// rounded-square or circular tile so it stays crisp and recognisable at small
/// sizes. Pass [circle] = true for a round crop.
class ArrestoAiAvatar extends StatelessWidget {
  final double size;
  final bool circle;

  /// When true the tile is transparent (use on an already-coloured surface such
  /// as the amber FAB, where the mascot silhouette should show directly).
  final bool transparent;

  const ArrestoAiAvatar({
    super.key,
    this.size = 32,
    this.circle = false,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = circle ? size / 2 : size * 0.28;

    final image = Image.asset(
      _kMascotAsset,
      width: size,
      height: size,
      // Portrait full-body art → cover + top alignment frames the hat + face.
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.85),
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.smart_toy_rounded,
        size: size * 0.62,
        color: ArrestoColors.amber,
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: transparent
            ? null
            : const LinearGradient(
                colors: [Color(0xFF2A2A38), Color(0xFF17171F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(radius),
        border: transparent
            ? null
            : Border.all(
                color: ArrestoColors.amber.withValues(alpha: 0.35),
                width: 1,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}
