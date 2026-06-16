import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class SectionHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ArrestoColors.orangeTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: ArrestoColors.orange, size: 17),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ArrestoText.h3()),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(subtitle!, style: ArrestoText.small()),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
