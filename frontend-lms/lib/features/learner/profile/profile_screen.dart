import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar + name
            ArrestoCard(
              child: Column(
                children: [
                  const ArrestoAvatar(name: 'James Harrington', size: 72),
                  const SizedBox(height: 12),
                  Text('James Harrington', style: ArrestoText.h2()),
                  Text('james.h@example.com',
                      style: ArrestoText.small()),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ArrestoButton(
                          label: 'Edit Profile',
                          size: ArrestoButtonSize.sm,
                          onPressed: () {}),
                      const SizedBox(width: 8),
                      ArrestoButton(
                          label: 'Change Picture',
                          variant: ArrestoButtonVariant.ghost,
                          size: ArrestoButtonSize.sm,
                          onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                _stat('4', 'Enrolled'),
                const SizedBox(width: 12),
                _stat('26', 'Completed'),
                const SizedBox(width: 12),
                _stat('1', 'Certificates'),
              ],
            ),
            const SizedBox(height: 16),

            // Settings
            ArrestoCard(
              child: Column(
                children: [
                  _settingRow(Icons.person_rounded, 'My Profile'),
                  _settingRow(Icons.lock_rounded, 'Change Password'),
                  _settingRow(Icons.notifications_rounded, 'Notifications'),
                  _settingRow(Icons.bar_chart_rounded, 'My Statistics'),
                  const Divider(color: ArrestoColors.line),
                  _settingRow(Icons.logout_rounded, 'Logout',
                      color: ArrestoColors.red),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ArrestoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArrestoColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(value, style: ArrestoText.h2()),
            Text(label, style: ArrestoText.small()),
          ],
        ),
      ),
    );
  }

  Widget _settingRow(IconData icon, String label,
      {Color? color}) {
    final c = color ?? ArrestoColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: ArrestoText.body(color: c))),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: ArrestoColors.textMuted2),
        ],
      ),
    );
  }
}
