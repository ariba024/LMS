import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/chip_group.dart';
import '../../../core/widgets/course_thumb.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/providers/api_providers.dart';
import '../../../data/models/course.dart';

class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);

    return libraryAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ArrestoColors.orange),
        ),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded,
                color: ArrestoColors.textMuted2, size: 40),
            const SizedBox(height: 12),
            Text('Could not load courses', style: ArrestoText.bodyMd()),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.invalidate(libraryProvider),
              child: const Text('Retry'),
            ),
          ]),
        ),
        data: (all) => _buildContent(context, all),
      );
  }

  Widget _buildContent(BuildContext context, List<Course> all) {
    // Since the backend doesn't track per-learner progress yet,
    // all library courses are treated as available. Progress is 0 by default.
    final enrolled = all.toList();
    final completed = enrolled.where((c) => c.progress == 100).toList();
    final inProgress =
        enrolled.where((c) => c.progress > 0 && c.progress < 100).toList();

    final displayed = switch (_filter) {
      'In Progress' => inProgress,
      'Completed' => completed,
      _ => enrolled,
    };

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  icon: Icons.school_rounded,
                  title: 'My Courses',
                  subtitle:
                      '${enrolled.length} courses · ${completed.length} completed',
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _strip('${enrolled.length}', 'Available',
                      ArrestoColors.amber),
                  const SizedBox(width: 10),
                  _strip('${inProgress.length}', 'In Progress',
                      ArrestoColors.blue),
                  const SizedBox(width: 10),
                  _strip('${completed.length}', 'Completed',
                      ArrestoColors.green),
                ]),
                const SizedBox(height: 16),
                ChipGroup(
                  options: const ['All', 'In Progress', 'Completed'],
                  selected: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Text('${displayed.length} courses',
                      style: ArrestoText.small()),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: ArrestoColors.textMuted, size: 18),
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(libraryProvider),
                  ),
                ]),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (displayed.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.school_outlined,
                    color: ArrestoColors.textMuted2, size: 48),
                const SizedBox(height: 12),
                Text(
                  all.isEmpty
                      ? 'No courses published yet.\nAsk your admin to generate some!'
                      : 'No courses match the selected filter.',
                  style: ArrestoText.body(),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: displayed.length,
              itemBuilder: (ctx, i) => _MyCourseCard(course: displayed[i]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _strip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label, style: ArrestoText.xs()),
        ]),
      ),
    );
  }
}

class _MyCourseCard extends StatelessWidget {
  final Course course;
  const _MyCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final done = course.progress == 100;
    return ArrestoCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/learner/course/${course.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: CourseThumb(style: course.style, code: course.code),
            ),
            if (done)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: ArrestoColors.green,
                      borderRadius: BorderRadius.circular(999)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, size: 11, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Completed',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                ),
              ),
          ]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${course.cat} · ${course.level}',
                      style: ArrestoText.eyebrow()),
                  const SizedBox(height: 4),
                  Text(course.title,
                      style: ArrestoText.h3(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
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
                  ]),
                  if (course.progress > 0) ...[
                    const SizedBox(height: 8),
                    AnimatedArrestoProgressBar(
                        value: course.progress / 100,
                        tone: done ? ProgressTone.green : ProgressTone.amber),
                    const SizedBox(height: 3),
                    Text('${course.progress}% complete',
                        style: ArrestoText.xs()),
                  ],
                  const Spacer(),
                  ArrestoButton(
                    label: done ? 'Review' : 'Start Learning',
                    size: ArrestoButtonSize.sm,
                    icon: Icon(done
                        ? Icons.replay_rounded
                        : Icons.play_arrow_rounded),
                    fullWidth: true,
                    onPressed: () =>
                        context.go('/learner/course/${course.id}'),
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
