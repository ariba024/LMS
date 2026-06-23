import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/chip_group.dart';
import '../../../core/widgets/course_thumb.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/providers/api_providers.dart';
import '../../../data/models/course.dart';

class CourseCatalogScreen extends ConsumerStatefulWidget {
  const CourseCatalogScreen({super.key});

  @override
  ConsumerState<CourseCatalogScreen> createState() =>
      _CourseCatalogScreenState();
}

class _CourseCatalogScreenState extends ConsumerState<CourseCatalogScreen> {
  // _search is the debounced value sent to the server; _rawSearch is the
  // live text-field value so the UI stays responsive while debounce fires.
  String _rawSearch = '';
  String _search    = '';
  String _category  = 'All';
  Timer? _debounce;

  static const _categories = [
    'All',
    'Fall Protection',
    'Equipment',
    'Emergency',
    'Site Safety',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() => _rawSearch = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(
      courseSearchProvider((
        q:        _search,
        category: _category == 'All' ? '' : _category,
      )),
    );

    return catalogAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ArrestoColors.orange),
      ),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded,
              color: ArrestoColors.textMuted2, size: 40),
          const SizedBox(height: 12),
          Text('Could not load courses', style: ArrestoText.bodyMd()),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(courseSearchProvider((
              q:        _search,
              category: _category == 'All' ? '' : _category,
            ))),
            child: const Text('Retry'),
          ),
        ]),
      ),
      data: (courses) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      icon: Icons.explore_rounded,
                      title: 'Course Catalog',
                      subtitle: '${courses.length} courses available',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded,
                            color: ArrestoColors.textMuted),
                        hintText: 'Search courses...',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(999)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ArrestoChip(
                              label: cat,
                              active: _category == cat,
                              onTap: () =>
                                  setState(() => _category = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('${courses.length} results',
                        style: ArrestoText.small()),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (courses.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          color: ArrestoColors.textMuted2, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        (_search.isEmpty && _category == 'All')
                            ? 'No courses published yet.\nAsk your admin to generate some!'
                            : 'No courses match your search.',
                        style: ArrestoText.body(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (ctx, i) =>
                      _CatalogCourseCard(course: courses[i]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
    );
  }
}

class _CatalogCourseCard extends StatelessWidget {
  final Course course;
  const _CatalogCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/learner/course/${course.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
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
                      Expanded(
                        child: Text(
                          '${course.cat} · ${course.level}',
                          style: ArrestoText.eyebrow(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (course.progress == 100)
                        const ArrestoBadge(
                            label: 'Done', variant: BadgeVariant.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.title,
                    style: ArrestoText.h3(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.desc,
                    style: ArrestoText.bodySm(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                      if (course.rating > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star_rounded,
                            size: 12, color: ArrestoColors.amber),
                        const SizedBox(width: 3),
                        Text('${course.rating}',
                            style: ArrestoText.small()),
                      ],
                    ],
                  ),
                  if (course.progress > 0 && course.progress < 100) ...[
                    const SizedBox(height: 8),
                    AnimatedArrestoProgressBar(
                        value: course.progress / 100),
                    const SizedBox(height: 2),
                    Text('${course.progress}% complete',
                        style: ArrestoText.xs()),
                  ] else if (course.progress == 0) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ArrestoColors.amberSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Enrol now',
                          style: ArrestoText.small(
                                  color: const Color(0xFF92400E))
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
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
