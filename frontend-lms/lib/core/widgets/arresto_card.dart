import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class ArrestoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final bool hasShadow;
  final VoidCallback? onTap;
  final double? borderRadius;

  const ArrestoCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.hasShadow = true,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? 16.0;
    return Container(
      decoration: BoxDecoration(
        color: color ?? ArrestoColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ArrestoColors.cardBorder),
        boxShadow: hasShadow ? ArrestoColors.sh2 : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: padding ??
                  const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
