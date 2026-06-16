import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/spacing.dart';

enum ArrestoButtonVariant { primary, ghost, dark, orange, danger }
enum ArrestoButtonSize { sm, md, lg }

class ArrestoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ArrestoButtonVariant variant;
  final ArrestoButtonSize size;
  final Widget? icon;
  final bool loading;
  final bool fullWidth;

  const ArrestoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ArrestoButtonVariant.primary,
    this.size = ArrestoButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = switch (size) {
      ArrestoButtonSize.sm => 32.0,
      ArrestoButtonSize.md => 40.0,
      ArrestoButtonSize.lg => 48.0,
    };
    final hPad = switch (size) {
      ArrestoButtonSize.sm => 14.0,
      ArrestoButtonSize.md => 18.0,
      ArrestoButtonSize.lg => 24.0,
    };
    final fontSize = switch (size) {
      ArrestoButtonSize.sm => 13.0,
      ArrestoButtonSize.md => 14.0,
      ArrestoButtonSize.lg => 15.0,
    };

    final (bg, fg, border) = switch (variant) {
      ArrestoButtonVariant.primary => (
          ArrestoColors.amber,
          ArrestoColors.ink,
          null
        ),
      ArrestoButtonVariant.ghost => (
          Colors.transparent,
          ArrestoColors.textSecondary,
          ArrestoColors.lineStrong
        ),
      ArrestoButtonVariant.dark => (
          ArrestoColors.ink,
          Colors.white,
          null
        ),
      ArrestoButtonVariant.orange => (
          ArrestoColors.orange,
          Colors.white,
          null
        ),
      ArrestoButtonVariant.danger => (
          ArrestoColors.red,
          Colors.white,
          null
        ),
    };

    final disabled = onPressed == null && !loading;

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          )
        else if (icon != null) ...[
          IconTheme(data: IconThemeData(color: fg, size: 16), child: icon!),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: h,
        child: Material(
          color: bg,
          borderRadius: ArrestoRadius.fullAll,
          child: InkWell(
            onTap: loading ? null : onPressed,
            borderRadius: ArrestoRadius.fullAll,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              decoration: border != null
                  ? BoxDecoration(
                      borderRadius: ArrestoRadius.fullAll,
                      border: Border.all(color: border, width: 1.5),
                    )
                  : null,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
