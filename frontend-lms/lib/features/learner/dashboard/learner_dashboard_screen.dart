import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/course_thumb.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/arresto_ai_mascot.dart';
import '../../../data/providers/api_providers.dart';
import '../../../data/models/course.dart';
import '../../shared/arresto_ai/arresto_ai_panel.dart';

class LearnerDashboardScreen extends ConsumerWidget {
  const LearnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCourses = ref.watch(libraryProvider).valueOrNull ?? [];
    final progressMap = ref.watch(courseProgressSummaryProvider).valueOrNull ?? {};

    // Merge backend progress percentages into course objects
    final courses = allCourses.map((c) {
      final pct = progressMap[c.id] ?? 0;
      return pct > 0 ? c.copyWith(progress: pct) : c;
    }).toList();

    final enrolledCourses =
        courses.where((c) => c.progress > 0 && c.progress < 100).toList();

    final avgProgress = progressMap.isEmpty
        ? 0
        : progressMap.values.reduce((a, b) => a + b) ~/
            max(1, progressMap.values.length);

    final isWide = MediaQuery.of(context).size.width >= 1024;

    return SingleChildScrollView(
        padding: const EdgeInsets.all(ArrestoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            Text('My Learning', style: ArrestoText.h1()),
            const SizedBox(height: ArrestoSpacing.lg),

            // Hero continue-learning banner
            if (enrolledCourses.isNotEmpty) ...[
              _HeroBanner(course: enrolledCourses.first),
              const SizedBox(height: ArrestoSpacing.xl),
            ],

            // Stats strip
            _StatsStrip(),
            const SizedBox(height: ArrestoSpacing.xl),

            // Main content + sidebar
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ContinueCourses(courses: enrolledCourses),
                            const SizedBox(height: ArrestoSpacing.xl),
                            _buildRecommended(courses),
                          ],
                        ),
                      ),
                      const SizedBox(width: ArrestoSpacing.xl),
                      SizedBox(
                          width: 300,
                          child: _RightSidebar(courses: enrolledCourses, avgProgress: avgProgress)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ContinueCourses(courses: enrolledCourses),
                      const SizedBox(height: ArrestoSpacing.xl),
                      _buildRecommended(courses),
                      const SizedBox(height: ArrestoSpacing.xl),
                      _RightSidebar(courses: enrolledCourses, avgProgress: avgProgress),
                    ],
                  ),
          ],
        ),
      );
  }

  Widget _buildRecommended(List<Course> courses) {
    final inProgress = courses
        .where((c) => c.progress > 0 && c.progress < 100)
        .toList()
      ..sort((a, b) => a.progress.compareTo(b.progress));
    final recommended = inProgress.isNotEmpty
        ? inProgress.take(3).toList()
        : courses.where((c) => c.progress == 0).take(5).toList();
    return _RecommendedSection(
      courses: recommended,
      title: inProgress.isNotEmpty ? 'Continue Learning' : 'Recommended for you',
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final Course course;
  const _HeroBanner({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ArrestoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArrestoColors.cardBorder),
        boxShadow: ArrestoColors.sh2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Amber left accent bar
              Container(width: 4, color: ArrestoColors.amber),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CONTINUE LEARNING',
                                style: ArrestoText.eyebrow()),
                            const SizedBox(height: 6),
                            Text(course.title, style: ArrestoText.h2()),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to continue where you left off',
                              style: ArrestoText.bodySm(),
                            ),
                            const SizedBox(height: 12),
                            AnimatedArrestoProgressBar(
                                value: course.progress / 100),
                            const SizedBox(height: 4),
                            Text('${course.progress}% complete',
                                style: ArrestoText.small()),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              children: [
                                ArrestoButton(
                                  label: 'Resume lesson',
                                  icon: const Icon(Icons.play_circle_rounded),
                                  onPressed: () =>
                                      context.go('/learner/course/${course.id}'),
                                ),
                                ArrestoButton(
                                  label: 'View course',
                                  variant: ArrestoButtonVariant.ghost,
                                  onPressed: () => context.go('/learner/course/${course.id}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 140,
                          height: 140,
                          child: CourseThumb(
                              style: course.style, code: course.code),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(libraryProvider);
    final historyAsync = ref.watch(assessmentHistoryProvider);
    final statsAsync = ref.watch(gamificationStatsProvider);

    final courseCount = coursesAsync.maybeWhen(
      data: (c) => '${c.length}',
      orElse: () => '—',
    );
    final certCount = historyAsync.maybeWhen(
      data: (h) {
        final passed = h.map((a) => a.courseId).toSet().where(
          (cid) => h.any((a) => a.courseId == cid && a.passed),
        ).length;
        return '$passed';
      },
      orElse: () => '—',
    );
    final lessonsCompleted = statsAsync.maybeWhen(
      data: (s) => '${s.totalLessonsCompleted}',
      orElse: () => '—',
    );
    final streak = statsAsync.maybeWhen(
      data: (s) => s.maxStreak > 0 ? '${s.maxStreak}d' : '0',
      orElse: () => '—',
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 800
            ? 4
            : constraints.maxWidth > 500
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            StatCard(
              title: 'Courses Available',
              value: courseCount,
              icon: Icons.school_rounded,
              iconColor: ArrestoColors.amber,
              barColor: ArrestoColors.amber,
            ),
            StatCard(
              title: 'Lessons Completed',
              value: lessonsCompleted,
              icon: Icons.check_circle_rounded,
              iconColor: ArrestoColors.green,
              barColor: ArrestoColors.green,
            ),
            StatCard(
              title: 'Certificates Earned',
              value: certCount,
              icon: Icons.workspace_premium_rounded,
              iconColor: ArrestoColors.orange,
              barColor: ArrestoColors.orange,
            ),
            StatCard(
              title: 'Learning Streak',
              value: streak,
              icon: Icons.local_fire_department_rounded,
              iconColor: ArrestoColors.red,
              barColor: ArrestoColors.red,
            ),
          ],
        );
      },
    );
  }
}

class _ContinueCourses extends StatelessWidget {
  final List<Course> courses;
  const _ContinueCourses({required this.courses});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.play_circle_rounded,
          title: 'Continue your courses',
          subtitle: '${courses.length} courses in progress',
          trailing: TextButton(
            onPressed: () => context.go('/learner/catalog'),
            child: Text('View all',
                style: ArrestoText.small(color: ArrestoColors.orange)
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 600 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: courses.take(4).length,
            itemBuilder: (ctx, i) => _CourseCard(course: courses[i]),
          );
        }),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/learner/course/${course.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(15)),
            child: CourseThumb(style: course.style, code: course.code),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${course.cat} · ${course.level}',
                          style: ArrestoText.eyebrow()),
                      const Spacer(),
                      if (course.progress == 100)
                        const ArrestoBadge(
                            label: 'Done', variant: BadgeVariant.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(course.title,
                      style: ArrestoText.h3(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(course.desc,
                      style: ArrestoText.bodySm(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 12, color: ArrestoColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${course.lessons} lessons',
                          style: ArrestoText.small()),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule_rounded,
                          size: 12, color: ArrestoColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${course.mins}m', style: ArrestoText.small()),
                      const SizedBox(width: 8),
                      Icon(Icons.star_rounded,
                          size: 12, color: ArrestoColors.amber),
                      const SizedBox(width: 3),
                      Text('${course.rating}', style: ArrestoText.small()),
                    ],
                  ),
                  if (course.progress > 0) ...[
                    const SizedBox(height: 8),
                    AnimatedArrestoProgressBar(
                        value: course.progress / 100),
                    const SizedBox(height: 3),
                    Text('${course.progress}%',
                        style: ArrestoText.xs()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedSection extends StatelessWidget {
  final List<Course> courses;
  final String title;
  const _RecommendedSection({required this.courses, this.title = 'Recommended for you'});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.recommend_rounded,
          title: title,
          subtitle: 'Based on your learning history',
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: courses.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (ctx, i) => SizedBox(
              width: 220,
              child: _MiniCourseCard(course: courses[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniCourseCard extends StatelessWidget {
  final Course course;
  const _MiniCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/learner/course/${course.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(15)),
            child: CourseThumb(
                style: course.style, code: course.code, height: 110),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.cat, style: ArrestoText.eyebrow()),
                  const SizedBox(height: 3),
                  Text(course.title,
                      style: ArrestoText.h4(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 11, color: ArrestoColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${course.lessons} lessons',
                          style: ArrestoText.xs()),
                      const SizedBox(width: 6),
                      Icon(Icons.schedule_rounded,
                          size: 11, color: ArrestoColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${course.mins}m', style: ArrestoText.xs()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RightSidebar extends StatelessWidget {
  final List<Course> courses;
  final int avgProgress;
  const _RightSidebar({required this.courses, required this.avgProgress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress donut card — real average across all enrolled courses
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall Progress', style: ArrestoText.h4()),
              const SizedBox(height: 16),
              Center(child: _DonutChart(percent: avgProgress)),
              const SizedBox(height: 12),
              AnimatedArrestoProgressBar(value: avgProgress / 100),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Avg across courses', style: ArrestoText.small()),
                  Text('$avgProgress%',
                      style: ArrestoText.small(color: ArrestoColors.amber)
                          .copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // In-progress courses — replaces fake "Upcoming Deadlines"
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded,
                      size: 16, color: ArrestoColors.orange),
                  const SizedBox(width: 6),
                  Text('In Progress', style: ArrestoText.h4()),
                ],
              ),
              const SizedBox(height: 12),
              if (courses.isEmpty)
                Text('No courses started yet.',
                    style: ArrestoText.bodySm(color: ArrestoColors.textMuted))
              else
                ...courses.take(4).map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _courseRow(context, c),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // AI promo — MR Solve style
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF191200),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: ArrestoColors.amber.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: ArrestoColors.amber.withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ArrestoAiMascot(size: 124),
              const SizedBox(height: 12),
              Text('Talk to Arresto AI',
                  style: ArrestoText.h3(color: Colors.white)
                      .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Click Start and ask anything about safety, compliance or risk.',
                style: ArrestoText.small(color: ArrestoColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const _AISheet(),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded,
                      size: 15, color: Color(0xFF1B1B1D)),
                  label: const Text('Start a Chat',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1D))),
                  style: FilledButton.styleFrom(
                    backgroundColor: ArrestoColors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _courseRow(BuildContext context, Course c) {
    return InkWell(
      onTap: () => context.go('/learner/course/${c.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: ArrestoText.bodySm(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: c.progress / 100,
                    backgroundColor: ArrestoColors.line,
                    valueColor:
                        const AlwaysStoppedAnimation(ArrestoColors.amber),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${c.progress}%',
                style: ArrestoText.xs(color: ArrestoColors.amber)
                    .copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _AISheet extends StatelessWidget {
  const _AISheet();

  @override
  Widget build(BuildContext context) => const ArrestoAIPanel();
}

class _DonutChart extends StatelessWidget {
  final int percent;
  const _DonutChart({required this.percent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percent / 100,
            strokeWidth: 10,
            backgroundColor: ArrestoColors.line,
            valueColor:
                const AlwaysStoppedAnimation(ArrestoColors.amber),
            strokeCap: StrokeCap.round,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$percent%', style: ArrestoText.h3()),
              Text('done', style: ArrestoText.xs()),
            ],
          ),
        ],
      ),
    );
  }
}
