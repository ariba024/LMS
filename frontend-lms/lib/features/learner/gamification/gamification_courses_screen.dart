import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/course.dart';
import '../../../data/providers/api_providers.dart';
import 'gamification_hub_screen.dart';

class GamificationCoursesScreen extends ConsumerWidget {
  const GamificationCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync     = ref.watch(libraryProvider);
    final activeAsync      = ref.watch(gamificationActiveCoursesProvider);
    final learnerId        = ref.watch(learnerIdProvider);
    // Fall back to empty set (show all) when endpoint errors
    final activeIds        = activeAsync.valueOrNull ?? const <String>{};

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      appBar: AppBar(
        backgroundColor: ArrestoColors.surface,
        elevation: 0,
        title: Text('Gamification',
            style: ArrestoText.base(color: ArrestoColors.ink)
                .copyWith(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B1B1D), Color(0xFF2D2D30)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: ArrestoColors.sh3,
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Colors.amber, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Course Challenges',
                            style: ArrestoText.lg(color: Colors.white)
                                .copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'Daily questions, Spot the Hazard games and leaderboards — one per course.',
                          style: ArrestoText.xs(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('SELECT A COURSE',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ArrestoColors.textMuted2,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),

            coursesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: ArrestoColors.amber),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Could not load courses: $e',
                      style: ArrestoText.bodySm()),
                ),
              ),
              data: (courses) {
                // Show only courses that have active gamification content.
                // If activeIds is empty (endpoint returned nothing or errored),
                // fall back to showing all published courses.
                final filtered = activeIds.isEmpty
                    ? courses
                    : courses.where((c) => activeIds.contains(c.id)).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        activeIds.isEmpty
                            ? 'No published courses yet.'
                            : 'No gamification content available yet.',
                        style: ArrestoText.bodySm(),
                      ),
                    ),
                  );
                }
                return Column(
                  children: filtered
                      .map((c) => _CourseCard(course: c, learnerId: learnerId))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course  course;
  final String  learnerId;
  const _CourseCard({required this.course, required this.learnerId});

  @override
  Widget build(BuildContext context) {
    void open() {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GamificationHubScreen(
          courseId:    course.id,
          courseTitle: course.title,
          learnerId:   learnerId,
        ),
      ));
    }

    return GestureDetector(
      onTap: open,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ArrestoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArrestoColors.cardBorder),
          boxShadow: ArrestoColors.sh1,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ArrestoColors.amberSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: ArrestoColors.amberStrong, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      style: ArrestoText.base(color: ArrestoColors.ink)
                          .copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${course.cat} · ${course.level}',
                      style: ArrestoText.xs(color: ArrestoColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: open,
              style: FilledButton.styleFrom(
                backgroundColor: ArrestoColors.ink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Play',
                  style: ArrestoText.small(color: Colors.white)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
