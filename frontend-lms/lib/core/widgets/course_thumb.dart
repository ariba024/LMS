import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

enum CourseStyle { animated, whiteboard, claude, hybrid }

class CourseThumb extends StatelessWidget {
  final CourseStyle style;
  final String? code;
  final double height;

  const CourseThumb({
    super.key,
    required this.style,
    this.code,
    this.height = 140,
  });

  LinearGradient get _gradient => switch (style) {
        CourseStyle.animated => const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        CourseStyle.whiteboard => const LinearGradient(
            colors: [Color(0xFFE8EAF6), Color(0xFFD1D9E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        CourseStyle.claude => const LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        CourseStyle.hybrid => const LinearGradient(
            colors: [Color(0xFFFFFDE7), Color(0xFFFFF9C4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      };

  IconData get _icon => switch (style) {
        CourseStyle.animated => Icons.grid_view_rounded,
        CourseStyle.whiteboard => Icons.edit_rounded,
        CourseStyle.claude => Icons.auto_awesome_rounded,
        CourseStyle.hybrid => Icons.layers_rounded,
      };

  String get _styleName => switch (style) {
        CourseStyle.animated => 'Animated',
        CourseStyle.whiteboard => 'Whiteboard',
        CourseStyle.claude => 'AI Style',
        CourseStyle.hybrid => 'Hybrid',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(gradient: _gradient),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: ArrestoColors.orange, size: 26),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ArrestoColors.amber,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _styleName,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: ArrestoColors.ink),
              ),
            ),
          ),
          if (code != null)
            Positioned(
              bottom: 8,
              right: 10,
              child: Text(code!, style: ArrestoText.mono()),
            ),
        ],
      ),
    );
  }
}
