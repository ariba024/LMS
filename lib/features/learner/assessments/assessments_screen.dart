import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/providers/app_state.dart';

class AssessmentsScreen extends ConsumerWidget {
  const AssessmentsScreen({super.key});

  // Mock history entries
  static const _history = [
    ('Rescue at Height & Suspension Trauma', 96, 'Passed', '1 attempt · Taken May 28'),
    ('Harness Inspection & Maintenance',     72, 'Passed', '2 attempts · Taken May 14'),
    ('Scaffold Safety Awareness',            48, 'Failed', '1 attempt · Taken May 02'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    final available = courses.where((c) => c.progress > 0 && c.progress < 100).toList();

    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.assignment_rounded,
              title: 'Assessments',
              subtitle: 'Your quizzes, scores and certification status',
            ),
            const SizedBox(height: 24),

            // ── Available ────────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.list_alt_rounded, size: 18, color: ArrestoColors.orange),
              const SizedBox(width: 8),
              Text('Available to take', style: ArrestoText.h3()),
            ]),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (ctx, c) {
              final cols = c.maxWidth > 640 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 2.2,
                ),
                itemCount: available.isEmpty ? 2 : available.length,
                itemBuilder: (ctx, i) {
                  if (available.isEmpty) {
                    // fallback cards so screen is never empty
                    const mock = [
                      ('Working at Height — Fundamentals', 'c1'),
                      ('Harness Inspection & Fit',         'c2'),
                    ];
                    return _AvailableCard(title: mock[i].$1, courseId: mock[i].$2);
                  }
                  return _AvailableCard(
                    title: available[i].title,
                    courseId: available[i].id,
                  );
                },
              );
            }),
            const SizedBox(height: 28),

            // ── Results & history ────────────────────────────────────────
            Row(children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: ArrestoColors.orange),
              const SizedBox(width: 8),
              Text('Results & history', style: ArrestoText.h3()),
            ]),
            const SizedBox(height: 14),
            ArrestoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: _history.map((h) => _HistoryRow(
                  title: h.$1,
                  score: h.$2,
                  status: h.$3,
                  meta: h.$4,
                  courseId: 'c1',
                )).toList(),
              ),
            ),
          ],
        ),
      );
  }
}

// ── Available card ──────────────────────────────────────────────────────────
class _AvailableCard extends StatelessWidget {
  final String title;
  final String courseId;
  const _AvailableCard({required this.title, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: ArrestoColors.orangeTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.list_alt_rounded, color: ArrestoColors.orange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: ArrestoText.bodyBold(), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('12 questions · 70% to pass', style: ArrestoText.small()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ArrestoButton(
            label: 'Take assessment',
            size: ArrestoButtonSize.sm,
            onPressed: () => context.go('/learner/assessment/$courseId'),
          ),
        ],
      ),
    );
  }
}

// ── History row ─────────────────────────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  final String title;
  final int score;
  final String status;
  final String meta;
  final String courseId;

  const _HistoryRow({
    required this.title,
    required this.score,
    required this.status,
    required this.meta,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    final passed = status == 'Passed';
    final bg    = passed ? ArrestoColors.greenSoft : ArrestoColors.redSoft;
    final fg    = passed ? ArrestoColors.green      : ArrestoColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ArrestoColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$score',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ArrestoText.bodyBold(), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(meta, style: ArrestoText.xs()),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ArrestoBadge(label: status, variant: passed ? BadgeVariant.green : BadgeVariant.red, dot: true),
          const SizedBox(width: 10),
          ArrestoButton(
            label: 'Review',
            size: ArrestoButtonSize.sm,
            variant: ArrestoButtonVariant.ghost,
            icon: const Icon(Icons.visibility_rounded),
            onPressed: () => context.go('/learner/assessment/$courseId/review'),
          ),
          if (!passed) ...[
            const SizedBox(width: 6),
            ArrestoButton(
              label: 'Retake',
              size: ArrestoButtonSize.sm,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => context.go('/learner/assessment/$courseId'),
            ),
          ],
        ],
      ),
    );
  }
}
