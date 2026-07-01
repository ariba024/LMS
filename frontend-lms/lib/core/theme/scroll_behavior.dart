import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'colors.dart';

/// App-wide scroll behavior: thin, premium, auto-hiding scrollbars and
/// drag-to-scroll enabled for mouse, touch, trackpad and stylus.
class ArrestoScrollBehavior extends MaterialScrollBehavior {
  const ArrestoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return RawScrollbar(
      controller: details.controller,
      thumbColor: ArrestoColors.lineStrong.withValues(alpha: 0.7),
      radius: const Radius.circular(999),
      thickness: 6,
      thumbVisibility: false,
      trackVisibility: false,
      interactive: true,
      child: child,
    );
  }
}
