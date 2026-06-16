import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class ArrestoText {
  ArrestoText._();

  static TextStyle h1({Color? color}) => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: color ?? ArrestoColors.ink,
        decoration: TextDecoration.none,
      );

  static TextStyle h2({Color? color}) => GoogleFonts.inter(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: color ?? ArrestoColors.ink,
        decoration: TextDecoration.none,
      );

  static TextStyle h3({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color ?? ArrestoColors.ink,
        decoration: TextDecoration.none,
      );

  static TextStyle h4({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: color ?? ArrestoColors.ink,
        decoration: TextDecoration.none,
      );

  static TextStyle body({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? ArrestoColors.textSecondary,
        decoration: TextDecoration.none,
      );

  static TextStyle bodyMd({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color ?? ArrestoColors.textSecondary,
        decoration: TextDecoration.none,
      );

  static TextStyle bodySm({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color ?? ArrestoColors.textMuted,
        decoration: TextDecoration.none,
      );

  static TextStyle bodyBold({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color ?? ArrestoColors.ink,
        decoration: TextDecoration.none,
      );

  static TextStyle small({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? ArrestoColors.textMuted,
        decoration: TextDecoration.none,
      );

  static TextStyle smallBold({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color ?? ArrestoColors.textMuted,
        decoration: TextDecoration.none,
      );

  static TextStyle xs({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color ?? ArrestoColors.textMuted2,
        decoration: TextDecoration.none,
      );

  static TextStyle eyebrow({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: color ?? ArrestoColors.orange,
        decoration: TextDecoration.none,
      );

  static TextStyle stat({Color? color}) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: color ?? ArrestoColors.ink,
        decoration: TextDecoration.none,
      );

  static TextStyle statLg({Color? color}) => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: color ?? ArrestoColors.ink,
        decoration: TextDecoration.none,
      );

  static TextStyle mono({Color? color, double? fontSize}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize ?? 12,
        fontWeight: FontWeight.w400,
        color: color ?? ArrestoColors.textMuted,
        decoration: TextDecoration.none,
      );

  static TextStyle label({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? ArrestoColors.textSecondary,
        decoration: TextDecoration.none,
      );
}
