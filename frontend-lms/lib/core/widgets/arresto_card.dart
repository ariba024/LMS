import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Premium glass card: translucent surface, soft glowing border, layered
/// shadow and a tasteful hover-lift microinteraction. The translucency lets the
/// animated circuit backdrop glow through for a frosted-glass feel without a
/// per-card blur pass (kept cheap so dozens can render at 60fps).
///
/// Set [blur] on the few hero/elevated surfaces where a true frosted backdrop
/// is worth the cost.
///
/// API is backwards-compatible with the previous ArrestoCard.
class ArrestoCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final bool hasShadow;
  final VoidCallback? onTap;
  final double? borderRadius;

  /// Apply a real frosted BackdropFilter (use sparingly — hero cards only).
  final bool blur;

  /// Amber accent ring + glow (for featured cards).
  final bool glow;

  const ArrestoCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.hasShadow = true,
    this.onTap,
    this.borderRadius,
    this.blur = false,
    this.glow = false,
  });

  @override
  State<ArrestoCard> createState() => _ArrestoCardState();
}

class _ArrestoCardState extends State<ArrestoCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? 18.0;
    final br = BorderRadius.circular(radius);

    final baseColor = (widget.color ?? ArrestoColors.surface)
        .withValues(alpha: widget.blur ? 0.55 : 0.72);

    final borderColor = widget.glow || _hover
        ? ArrestoColors.amber.withValues(alpha: _hover ? 0.55 : 0.35)
        : ArrestoColors.cardBorder.withValues(alpha: 0.9);

    final shadows = <BoxShadow>[
      if (widget.hasShadow) ...ArrestoColors.sh2,
      if (widget.glow || _hover)
        BoxShadow(
          color: ArrestoColors.amber.withValues(alpha: _hover ? 0.18 : 0.10),
          blurRadius: _hover ? 28 : 20,
          spreadRadius: _hover ? 1 : 0,
        ),
    ];

    Widget content = Padding(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: widget.child,
    );

    // Subtle top highlight for the glass edge.
    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      child: content,
    );

    Widget inner = Material(
      color: baseColor,
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.white.withValues(alpha: 0.02),
        borderRadius: br,
        child: content,
      ),
    );

    if (widget.blur) {
      inner = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: inner,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        transform: _hover
            ? (Matrix4.identity()..translate(0.0, -3.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border.all(color: borderColor, width: 1),
          boxShadow: shadows,
        ),
        child: ClipRRect(borderRadius: br, child: inner),
      ),
    );
  }
}
