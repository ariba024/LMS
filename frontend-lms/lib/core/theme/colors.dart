import 'package:flutter/material.dart';

class ArrestoColors {
  ArrestoColors._();

  // Primary
  static const amber = Color(0xFFF5BE3F);
  static const orange = Color(0xFFC2410C);
  static const ink = Color(0xFF1B1B1D);

  // Surface
  static const background = Color(0xFFF7F5F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFFAF9F7);
  static const cardBorder = Color(0xFFE8E4DE);

  // Text
  static const textPrimary = Color(0xFF1B1B1D);
  static const textSecondary = Color(0xFF3D3A36);
  static const textMuted = Color(0xFF71717A);
  static const textMuted2 = Color(0xFFA1A1AA);

  // Semantic
  static const green = Color(0xFF1F8A5B);
  static const greenSoft = Color(0xFFDCFCE7);
  static const red = Color(0xFFD1432F);
  static const redSoft = Color(0xFFFEE2E2);
  static const blue = Color(0xFF2563B8);
  static const blueSoft = Color(0xFFDBEAFE);

  // Tints
  static const amberSoft = Color(0xFFFEF3C7);
  static const amberStrong = Color(0xFFD97706);
  static const orangeTint = Color(0xFFFFF1EC);
  static const bg2 = Color(0xFFF0EDE8);
  static const line = Color(0xFFE8E4DE);
  static const lineStrong = Color(0xFFD4CFC8);

  // Shadow helpers
  static List<BoxShadow> get sh1 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 3,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 2,
            offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get sh2 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4)),
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> get sh3 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4)),
      ];

  static List<BoxShadow> get sh4 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 48,
            offset: const Offset(0, 20)),
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8)),
      ];
}
