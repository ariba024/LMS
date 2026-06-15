import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../data/providers/app_state.dart';

class AssessmentReviewScreen extends ConsumerWidget {
  final String courseId;
  const AssessmentReviewScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentProvider);
    final questions = ref.watch(questionsProvider);

    return Column(
      children: [
        AppBar(
          backgroundColor: ArrestoColors.surface,
          foregroundColor: ArrestoColors.ink,
          title: Text('Review Answers', style: ArrestoText.h4()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: questions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (ctx, i) {
          final q = questions[i];
          final selected = state.answers[i];
          final isCorrect = selected == q.a;

          return ArrestoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? ArrestoColors.greenSoft
                            : ArrestoColors.redSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isCorrect
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size: 16,
                        color: isCorrect
                            ? ArrestoColors.green
                            : ArrestoColors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Q${i + 1}',
                        style: ArrestoText.label()),
                    const SizedBox(width: 8),
                    ArrestoBadge(
                      label: q.topic,
                      variant: BadgeVariant.blue,
                    ),
                    const Spacer(),
                    ArrestoBadge(
                      label: isCorrect ? 'Correct' : 'Incorrect',
                      variant: isCorrect
                          ? BadgeVariant.green
                          : BadgeVariant.red,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(q.q, style: ArrestoText.bodyBold()),
                const SizedBox(height: 10),
                if (q.opts.isNotEmpty)
                  ...List.generate(q.opts.length, (j) {
                    final isSelected = selected == j;
                    final isAnswer = q.a == j;
                    Color bg = ArrestoColors.surface;
                    Color border = ArrestoColors.line;
                    if (isAnswer) {
                      bg = ArrestoColors.greenSoft;
                      border = ArrestoColors.green;
                    } else if (isSelected && !isAnswer) {
                      bg = ArrestoColors.redSoft;
                      border = ArrestoColors.red;
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Text(
                            String.fromCharCode(65 + j),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isAnswer
                                    ? ArrestoColors.green
                                    : ArrestoColors.textMuted),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(q.opts[j],
                                style: ArrestoText.body(
                                    color: isAnswer
                                        ? ArrestoColors.green
                                        : null)),
                          ),
                          if (isAnswer)
                            const Icon(Icons.check_circle_rounded,
                                size: 16, color: ArrestoColors.green),
                          if (isSelected && !isAnswer)
                            const Icon(Icons.cancel_rounded,
                                size: 16, color: ArrestoColors.red),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ArrestoColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ArrestoColors.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_rounded,
                          size: 14, color: ArrestoColors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(q.why,
                            style: ArrestoText.bodySm()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        )),
      ],
    );
  }
}
