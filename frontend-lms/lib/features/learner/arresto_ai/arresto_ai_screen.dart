import 'package:flutter/material.dart';
import '../../../core/services/course_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/course.dart';
import '../../shared/arresto_ai/arresto_ai_panel.dart';

class ArrestoAiScreen extends StatefulWidget {
  const ArrestoAiScreen({super.key});

  @override
  State<ArrestoAiScreen> createState() => _ArrestoAiScreenState();
}

class _ArrestoAiScreenState extends State<ArrestoAiScreen> {
  List<Course>? _courses;
  Course? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await CourseService.listLibrary();
      if (mounted) {
        setState(() {
          _courses = courses;
          // Pre-select the first published course so the AI is immediately useful
          if (courses.isNotEmpty) _selectedCourse = courses.first;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final AiLessonContext? ctx = _selectedCourse == null
        ? null
        : AiLessonContext(
            lessonId: _selectedCourse!.id,
            courseId: _selectedCourse!.id,
            lessonTitle: _selectedCourse!.title,
            timestampSecs: 0,
          );

    return Column(
      children: [
        _CoursePickerBar(
          courses: _courses,
          selected: _selectedCourse,
          onChanged: (c) => setState(() => _selectedCourse = c),
        ),
        Expanded(
          child: ArrestoAIPanel(
            key: ValueKey(_selectedCourse?.id ?? '__none__'),
            embedded: true,
            lessonContext: ctx,
          ),
        ),
      ],
    );
  }
}

// ── Course picker header ──────────────────────────────────────────────────────

class _CoursePickerBar extends StatelessWidget {
  final List<Course>? courses;
  final Course? selected;
  final ValueChanged<Course?> onChanged;

  const _CoursePickerBar({
    required this.courses,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: ArrestoColors.surface,
        border: Border(bottom: BorderSide(color: ArrestoColors.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded,
              size: 16, color: ArrestoColors.orange),
          const SizedBox(width: 8),
          Text('Course context:', style: ArrestoText.xs()),
          const SizedBox(width: 10),
          Expanded(
            child: courses == null
                ? Text('Loading courses…',
                    style: ArrestoText.xs(color: ArrestoColors.textMuted2))
                : courses!.isEmpty
                    ? Text('No courses — generate one first',
                        style:
                            ArrestoText.xs(color: ArrestoColors.textMuted2))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<Course>(
                          value: selected,
                          isDense: true,
                          isExpanded: true,
                          style: ArrestoText.xs()
                              .copyWith(color: ArrestoColors.textPrimary),
                          icon: const Icon(Icons.expand_more_rounded,
                              size: 16, color: ArrestoColors.textMuted),
                          items: courses!
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.title,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: onChanged,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
