import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? sub;
  final IconData icon;
  final Color iconColor;
  final Color barColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.sub,
    required this.icon,
    this.iconColor = ArrestoColors.amber,
    this.barColor = ArrestoColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ArrestoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ArrestoColors.cardBorder),
        boxShadow: ArrestoColors.sh2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title, style: ArrestoText.small()),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: iconColor, size: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(value, style: ArrestoText.statLg()),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub!, style: ArrestoText.small()),
                  ],
                ],
              ),
            ),
            Container(height: 4, color: barColor),
          ],
        ),
      ),
    );
  }
}
