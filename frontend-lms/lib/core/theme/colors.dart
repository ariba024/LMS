import 'package:flutter/material.dart';

class ArrestoColors {
  ArrestoColors._();

  // Primary accent
  static const amber = Color(0xFFF5A623);       // Arresto orange — primary accent
  static const orange = Color(0xFFF39C12);       // Darker orange — hover / secondary
  static const ink = Color(0xFF0A0A0A);          // Near-black — text on orange buttons

  // Surface
  static const background = Color(0xFFF0EEEA);   // App background — warm light grey
  static const surface = Color(0xFF1A1A1A);       // Cards / panels
  static const surfaceSoft = Color(0xFF141414);   // Slightly raised surface / input fill
  static const cardBorder = Color(0xFF2A2A2A);    // Borders / dividers

  // Text hierarchy
  static const textPrimary = Color(0xFFFFFFFF);   // White — headings & primary text
  static const textSecondary = Color(0xFFB0B0B0); // Light grey — body text
  static const textMuted = Color(0xFF808080);      // Muted grey — helper / caption
  static const textMuted2 = Color(0xFF606060);     // Very muted — subtle labels

  // Semantic — brightened slightly for legibility on dark backgrounds
  static const green = Color(0xFF4ADE80);
  static const greenSoft = Color(0xFF0A2A14);
  static const red = Color(0xFFEF4444);
  static const redSoft = Color(0xFF2A0A0A);
  static const blue = Color(0xFF60A5FA);
  static const blueSoft = Color(0xFF0A1828);

  // Tints (dark equivalents of light-mode soft fills)
  static const amberSoft = Color(0xFF3A2008);
  static const amberStrong = Color(0xFFE8920E);
  static const orangeTint = Color(0xFF1F1008);
  static const bg2 = Color(0xFF141414);          // Input field fill
  static const line = Color(0xFF2A2A2A);          // Dividers
  static const lineStrong = Color(0xFF383838);    // Stronger borders

  // Shadow helpers — higher opacity for visibility on dark surfaces
  static List<BoxShadow> get sh1 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.50),
            blurRadius: 3,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 2,
            offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get sh2 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 12,
            offset: const Offset(0, 4)),
        BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 4,
            offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> get sh3 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.60),
            blurRadius: 24,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 8,
            offset: const Offset(0, 4)),
      ];

  static List<BoxShadow> get sh4 => [
        BoxShadow(
            color: Colors.black.withOpacity(0.70),
            blurRadius: 48,
            offset: const Offset(0, 20)),
        BoxShadow(
            color: Colors.black.withOpacity(0.50),
            blurRadius: 16,
            offset: const Offset(0, 8)),
      ];
}
