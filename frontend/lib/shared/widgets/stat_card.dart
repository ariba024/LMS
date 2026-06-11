import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.barColor = AColors.amber,
    this.sub,
    this.delta,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color barColor;
  final String? sub;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AColors.textMuted, letterSpacing: 0.1)),
          ),
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: barColor),
            ),
        ]),
        const SizedBox(height: 12),
        Text(value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                color: AColors.ink, letterSpacing: -0.5)),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub!, style: const TextStyle(fontSize: 12, color: AColors.textMuted)),
        ],
        if (delta != null) ...[
          const SizedBox(height: 4),
          Text(delta!,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: delta!.startsWith('+') ? AColors.green : AColors.red)),
        ],
        const SizedBox(height: 12),
        Container(height: 3, decoration: BoxDecoration(
            color: barColor, borderRadius: BorderRadius.circular(2))),
      ]),
    );
  }
}
