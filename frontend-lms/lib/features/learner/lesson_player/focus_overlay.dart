import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class FocusDistractedOverlay extends StatelessWidget {
  final VoidCallback onBack;
  const FocusDistractedOverlay({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: ArrestoColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ArrestoColors.sh4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: ArrestoColors.amberSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.visibility_off_rounded,
                    color: ArrestoColors.amberStrong,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Video Paused', style: ArrestoText.h3()),
                const SizedBox(height: 8),
                Text(
                  'You appeared distracted. The lesson was paused to help you stay on track.',
                  style: ArrestoText.bodyMd().copyWith(color: ArrestoColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArrestoColors.amber,
                      foregroundColor: ArrestoColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text("I'm back!", style: ArrestoText.bodyMd().copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
