import 'package:flutter/material.dart';

class ArrestoSpacing {
  ArrestoSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 28.0;
  static const double page = 20.0;
  static const double pageLg = 28.0;

  static const double sidebarWidth = 240.0;
  static const double headerHeight = 56.0;
  static const double maxContentWidth = 1320.0;
}

class ArrestoRadius {
  ArrestoRadius._();

  static const sm = Radius.circular(6);
  static const md = Radius.circular(8);
  static const lg = Radius.circular(10);
  static const xl = Radius.circular(12);
  static const xl2 = Radius.circular(14);
  static const xl3 = Radius.circular(16);
  static const card = Radius.circular(16);
  static const full = Radius.circular(999);

  static BorderRadius smAll = BorderRadius.circular(6);
  static BorderRadius mdAll = BorderRadius.circular(8);
  static BorderRadius lgAll = BorderRadius.circular(10);
  static BorderRadius xlAll = BorderRadius.circular(12);
  static BorderRadius xl2All = BorderRadius.circular(14);
  static BorderRadius cardAll = BorderRadius.circular(16);
  static BorderRadius fullAll = BorderRadius.circular(999);
}

class Breakpoints {
  Breakpoints._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 640;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 640 && w < 1024;
  }
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;
}
