import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'arresto_ai_mascot.dart';

/// Draggable, floating "Arresto AI" launcher. Defaults to the lower-right,
/// lifted clear of bottom bars (nav footers, mobile tab bar) so it never
/// overlaps page actions — and the user can drag it anywhere on screen.
///
/// Rendered as the top layer of a screen-filling Stack; empty areas do not
/// absorb pointer events, so content beneath stays fully interactive.
class FloatingAiButton extends StatefulWidget {
  final VoidCallback onPressed;
  const FloatingAiButton({super.key, required this.onPressed});

  @override
  State<FloatingAiButton> createState() => _FloatingAiButtonState();
}

class _FloatingAiButtonState extends State<FloatingAiButton> {
  Offset? _pos;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      const double w = 150, h = 48, m = 20;
      final maxX = (c.maxWidth - w - m).clamp(m, double.infinity);
      final clampMaxY = (c.maxHeight - h - m).clamp(m, double.infinity);
      // Default sits ~88px up so it clears the generator's nav footer and the
      // mobile bottom bar; still draggable down to the edge if desired.
      final defaultY = (c.maxHeight - h - 88).clamp(m, clampMaxY);
      final base = _pos ?? Offset(maxX, defaultY);
      final pos = Offset(base.dx.clamp(m, maxX), base.dy.clamp(m, clampMaxY));

      return Stack(
        children: [
          Positioned(
            left: pos.dx,
            top: pos.dy,
            child: GestureDetector(
              onPanStart: (_) => setState(() => _dragging = true),
              onPanUpdate: (d) => setState(() => _pos = pos + d.delta),
              onPanEnd: (_) => setState(() => _dragging = false),
              onTap: widget.onPressed,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedScale(
                  scale: _dragging ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    height: h,
                    padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [ArrestoColors.amber, ArrestoColors.orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: ArrestoColors.amber
                              .withValues(alpha: _dragging ? 0.5 : 0.38),
                          blurRadius: _dragging ? 26 : 18,
                          spreadRadius: 1,
                        ),
                        ...ArrestoColors.sh2,
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ArrestoAiAvatar(
                            size: 34, circle: true, transparent: true),
                        const SizedBox(width: 8),
                        Text('Arresto AI',
                            style: ArrestoText.small(
                                    color: const Color(0xFF1B1B1D))
                                .copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
