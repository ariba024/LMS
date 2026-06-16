import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../data/providers/api_providers.dart';

class AssessmentResultScreen extends ConsumerWidget {
  final String courseId;
  const AssessmentResultScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizResult = ref.watch(quizResultsProvider);

    final correct = quizResult?.correct ?? 0;
    final total = quizResult?.total ?? 6;
    final score = quizResult?.score ?? 0;
    final passed = score >= 70;

    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Pass/Fail hero
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: passed ? ArrestoColors.greenSoft : ArrestoColors.redSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: passed ? ArrestoColors.green : ArrestoColors.red),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color:
                          passed ? ArrestoColors.green : ArrestoColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      passed
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    passed ? 'Assessment Passed!' : 'Assessment Failed',
                    style: ArrestoText.h2(
                        color: passed
                            ? ArrestoColors.green
                            : ArrestoColors.red),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    passed
                        ? 'Congratulations! You\'ve passed the assessment.'
                        : 'You scored below the 70% pass mark. Please retake.',
                    style: ArrestoText.body(),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Score metrics
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                _metric('Score', '$score%',
                    passed ? ArrestoColors.green : ArrestoColors.red),
                _metric('Correct', '$correct',
                    ArrestoColors.green),
                _metric('Incorrect', '${total - correct}',
                    ArrestoColors.red),
                _metric('Time', '12:34', ArrestoColors.blue),
              ],
            ),
            const SizedBox(height: 20),

            // Performance by topic
            ArrestoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Performance by Topic', style: ArrestoText.h4()),
                  const SizedBox(height: 16),
                  ...[
                    ('Anchor Points', 0.8),
                    ('Equipment Inspection', 0.6),
                    ('Fall Clearance', 0.5),
                    ('System Components', 1.0),
                  ].map((t) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text(t.$1,
                                      style: ArrestoText.bodySm(
                                          color: ArrestoColors.ink))),
                              Text(
                                  '${(t.$2 * 100).round()}%',
                                  style: ArrestoText.small(
                                      color: t.$2 >= 0.7
                                          ? ArrestoColors.green
                                          : ArrestoColors.red)
                                    ..copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AnimatedArrestoProgressBar(
                            value: t.$2,
                            tone: t.$2 >= 0.7
                                ? ProgressTone.green
                                : ProgressTone.red,
                            height: 6,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ArrestoButton(
                  label: 'Review Answers',
                  variant: ArrestoButtonVariant.ghost,
                  icon: const Icon(Icons.list_alt_rounded),
                  onPressed: () => context
                      .go('/learner/assessment/$courseId/review'),
                ),
                if (!passed)
                  ArrestoButton(
                    label: 'Retake Assessment',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => context
                        .go('/learner/assessment/$courseId'),
                  ),
                if (passed)
                  ArrestoButton(
                    label: 'Download Certificate',
                    icon: const Icon(
                        Icons.workspace_premium_rounded),
                    onPressed: () {},
                  ),
                ArrestoButton(
                  label: 'Back to Course',
                  variant: ArrestoButtonVariant.dark,
                  onPressed: () =>
                      context.go('/learner/course/$courseId'),
                ),
              ],
            ),
          ],
        ),
      );
  }

  Widget _metric(String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label, style: ArrestoText.xs()),
        ],
      ),
    );
  }
}
