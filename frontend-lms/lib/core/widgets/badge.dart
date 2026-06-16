import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

enum BadgeVariant { amber, green, red, blue, gray, orange }

class ArrestoBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final bool dot;

  const ArrestoBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.gray,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      BadgeVariant.amber => (
          ArrestoColors.amberSoft,
          const Color(0xFF92400E)
        ),
      BadgeVariant.green => (
          ArrestoColors.greenSoft,
          const Color(0xFF14532D)
        ),
      BadgeVariant.red => (ArrestoColors.redSoft, const Color(0xFF7F1D1D)),
      BadgeVariant.blue => (ArrestoColors.blueSoft, const Color(0xFF1E3A8A)),
      BadgeVariant.gray => (
          const Color(0xFFF4F4F5),
          const Color(0xFF3F3F46)
        ),
      BadgeVariant.orange => (
          ArrestoColors.orangeTint,
          ArrestoColors.orange
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: variant == BadgeVariant.amber
            ? Border.all(color: ArrestoColors.amberStrong, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status.toLowerCase()) {
      'published' => const ArrestoBadge(label: 'Published', variant: BadgeVariant.green),
      'draft' => const ArrestoBadge(label: 'Draft', variant: BadgeVariant.amber),
      'generating' => const ArrestoBadge(label: 'Generating', variant: BadgeVariant.orange),
      'review' => const ArrestoBadge(label: 'Review', variant: BadgeVariant.blue),
      'active' => const ArrestoBadge(label: 'Active', variant: BadgeVariant.green),
      'inactive' => const ArrestoBadge(label: 'Inactive', variant: BadgeVariant.gray),
      'pending' => const ArrestoBadge(label: 'Pending', variant: BadgeVariant.amber),
      'open' => const ArrestoBadge(label: 'Open', variant: BadgeVariant.orange),
      'in progress' => const ArrestoBadge(label: 'In Progress', variant: BadgeVariant.blue),
      'resolved' => const ArrestoBadge(label: 'Resolved', variant: BadgeVariant.green),
      'closed' => const ArrestoBadge(label: 'Closed', variant: BadgeVariant.gray),
      _ => ArrestoBadge(label: status, variant: BadgeVariant.gray),
    };
  }
}
