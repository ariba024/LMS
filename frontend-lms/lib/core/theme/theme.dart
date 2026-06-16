import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

ThemeData buildArrestoTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: ArrestoColors.background,
    colorScheme: ColorScheme.light(
      primary: ArrestoColors.amber,
      secondary: ArrestoColors.orange,
      surface: ArrestoColors.surface,
      error: ArrestoColors.red,
      onPrimary: ArrestoColors.ink,
      onSecondary: Colors.white,
      onSurface: ArrestoColors.textPrimary,
      onError: Colors.white,
      outline: ArrestoColors.cardBorder,
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
          fontSize: 26, fontWeight: FontWeight.w800, color: ArrestoColors.ink),
      headlineMedium: GoogleFonts.inter(
          fontSize: 21, fontWeight: FontWeight.w800, color: ArrestoColors.ink),
      titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w700, color: ArrestoColors.ink),
      bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ArrestoColors.textSecondary),
      bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: ArrestoColors.textMuted),
      labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ArrestoColors.orange),
    ),
    cardTheme: CardThemeData(
      color: ArrestoColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ArrestoColors.cardBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ArrestoColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ArrestoColors.lineStrong, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ArrestoColors.lineStrong, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ArrestoColors.amber, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(
          fontSize: 14, color: ArrestoColors.textMuted2),
    ),
    dividerColor: ArrestoColors.line,
    appBarTheme: AppBarTheme(
      backgroundColor: ArrestoColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ArrestoColors.ink,
      ),
      iconTheme: const IconThemeData(color: ArrestoColors.ink),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
