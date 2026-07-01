import 'package:flutter/material.dart';

class ArrestoColors {
  ArrestoColors._();

  // Primary accent — matches Arresto website
  static const amber = Color(0xFFF5A623);
  static const orange = Color(0xFFE8900A);
  static const ink = Color(0xFFFFFFFF); // primary foreground (white) on dark bg

  // Surfaces (dark)
  static const background = Color(0xFF111113);
  static const surface = Color(0xFF1B1B1D);
  static const surfaceSoft = Color(0xFF222226);
  static const cardBorder = Color(0xFF2D2D30);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFE4E4E7);
  static const textMuted = Color(0xFFA1A1AA);
  static const textMuted2 = Color(0xFF71717A);

  // Semantic
  static const green = Color(0xFF22C55E);
  static const greenSoft = Color(0xFF0D2118);
  static const red = Color(0xFFEF4444);
  static const redSoft = Color(0xFF2A0F0F);
  static const blue = Color(0xFF3B82F6);
  static const blueSoft = Color(0xFF0F1A2A);

  // Tints / accent backgrounds
  static const amberSoft = Color(0xFF352008);
  static const amberStrong = Color(0xFFF5A623);
  static const orangeTint = Color(0xFF221508);
  static const bg2 = Color(0xFF222226);
  static const line = Color(0xFF2D2D30);
  static const lineStrong = Color(0xFF404044);

  // Shadows (stronger contrast for dark bg)
  static List<BoxShadow> get sh1 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 2,
            offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get sh2 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4)),
        BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 4,
            offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> get sh3 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4)),
      ];

  static List<BoxShadow> get sh4 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 48,
            offset: const Offset(0, 20)),
        BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 16,
            offset: const Offset(0, 8)),
      ];
}
