import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/services/assessment_service.dart' show AssessmentHistoryItem;
import '../../../data/models/course.dart' show Course;
import '../../../data/providers/api_providers.dart';

class MyProgressScreen extends ConsumerWidget {
  const MyProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync   = ref.watch(courseProgressSummaryProvider);
    final libraryAsync    = ref.watch(libraryProvider);
    final historyAsync    = ref.watch(assessmentHistoryProvider);

    final progressMap = progressAsync.valueOrNull ?? const <String, int>{};
    final library     = libraryAsync.valueOrNull ?? const <Course>[];
    final history     = historyAsync.valueOrNull ?? const <AssessmentHistoryItem>[];

    // Build a title map from library
    final titleMap = {for (final c in library) c.id: c.title};

    // Enrolled courses = keys in progressMap
    final enrolledIds = progressMap.keys.toList();
    final completedCount =
        progressMap.values.where((p) => p >= 100).length;

    // Best score per course from history
    final Map<String, int> bestScores = {};
    final Map<String, bool> hasPassed = {};
    for (final item in history) {
      final existing = bestScores[item.courseId] ?? -1;
      if (item.score > existing) bestScores[item.courseId] = item.score;
      if (item.passed) hasPassed[item.courseId] = true;
    }

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.bar_chart_rounded,
              title: 'My Progress',
              subtitle: 'Your learning journey across all courses',
            ),
            const SizedBox(height: 20),

            // Summary KPI strip
            _buildKpiStrip(
              enrolledCount: enrolledIds.length,
              completedCount: completedCount,
              assessmentCount: history.length,
              passedCount: hasPassed.length,
            ),
            const SizedBox(height: 20),

            // Course progress cards
            if (progressAsync.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (enrolledIds.isEmpty)
              ArrestoCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.school_outlined,
                            size: 48, color: ArrestoColors.textMuted),
                        const SizedBox(height: 12),
                        Text("You haven't started any courses yet.",
                            style: ArrestoText.body(
                                color: ArrestoColors.textMuted)),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.explore_rounded),
                          label: const Text('Browse Catalog'),
                          onPressed: () => context.go('/learner/catalog'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              Text('Course Progress', style: ArrestoText.h4()),
              const SizedBox(height: 10),
              ...enrolledIds.map((courseId) {
                final pct     = progressMap[courseId] ?? 0;
                final title   = titleMap[courseId] ?? courseId;
                final best    = bestScores[courseId];
                final passed  = hasPassed[courseId] ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CourseProgressCard(
                    courseId: courseId,
                    title: title,
                    percent: pct,
                    bestScore: best,
                    passed: passed,
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),

            // Assessment history
            if (history.isNotEmpty) ...[
              Text('Assessment History', style: ArrestoText.h4()),
              const SizedBox(height: 10),
              ArrestoCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: history
                      .take(20)
                      .map((item) => _AssessmentHistoryRow(item: item))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiStrip({
    required int enrolledCount,
    required int completedCount,
    required int assessmentCount,
    required int passedCount,
  }) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = c.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            _kpi(Icons.school_rounded, '$enrolledCount', 'Enrolled',
                ArrestoColors.blue),
            _kpi(Icons.check_circle_rounded, '$completedCount',
                'Completed', ArrestoColors.green),
            _kpi(Icons.assignment_rounded, '$assessmentCount',
                'Assessments', ArrestoColors.orange),
            _kpi(Icons.workspace_premium_rounded, '$passedCount',
                'Passed', ArrestoColors.amber),
          ],
        );
      },
    );
  }

  Widget _kpi(IconData icon, String value, String label, Color color) {
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: ArrestoText.h3(color: color)),
          Text(label, style: ArrestoText.xs()),
        ],
      ),
    );
  }
}

// ── Course progress card ──────────────────────────────────────────────────────

class _CourseProgressCard extends StatelessWidget {
  final String courseId;
  final String title;
  final int percent;
  final int? bestScore;
  final bool passed;

  const _CourseProgressCard({
    required this.courseId,
    required this.title,
    required this.percent,
    required this.bestScore,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final Color barColor = percent >= 80
        ? ArrestoColors.green
        : percent >= 40
            ? ArrestoColors.orange
            : ArrestoColors.blue;

    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: ArrestoText.bodyBold(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              if (percent >= 100)
                _badge('Completed', ArrestoColors.green)
              else
                _badge('$percent%', barColor),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: ArrestoColors.line,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (bestScore != null) ...[
                Icon(
                  passed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 14,
                  color: passed ? ArrestoColors.green : ArrestoColors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  'Best score: $bestScore%${passed ? ' (Passed)' : ''}',
                  style: ArrestoText.xs(
                      color: passed
                          ? ArrestoColors.green
                          : ArrestoColors.textMuted),
                ),
              ] else
                Text('No assessment attempts yet',
                    style: ArrestoText.xs(
                        color: ArrestoColors.textMuted)),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () =>
                    context.go('/learner/course/$courseId'),
                child: Text('Continue →',
                    style: ArrestoText.xs(
                        color: ArrestoColors.orange)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ── Assessment history row ────────────────────────────────────────────────────

class _AssessmentHistoryRow extends StatelessWidget {
  final AssessmentHistoryItem item;
  const _AssessmentHistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final passed = item.passed;
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: ArrestoColors.line, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: passed ? ArrestoColors.greenSoft : ArrestoColors.redSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${item.score}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: passed ? ArrestoColors.green : ArrestoColors.red,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.courseTitle,
                    style: ArrestoText.bodySm(),
                    overflow: TextOverflow.ellipsis),
                Text(
                  'Attempt ${item.attemptNumber} of ${item.totalAttempts}  •  ${item.formattedDate}',
                  style: ArrestoText.xs(color: ArrestoColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: passed ? ArrestoColors.greenSoft : ArrestoColors.redSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              passed ? 'Passed' : 'Failed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: passed ? ArrestoColors.green : ArrestoColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
