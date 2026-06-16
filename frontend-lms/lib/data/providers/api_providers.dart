import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/course_service.dart';
import '../../core/services/document_service.dart';
import '../../core/services/tutor_service.dart';
import '../models/course.dart';
import '../models/lesson.dart' show CourseLesson;

// ── Course library (list) ─────────────────────────────────────────────────────
final libraryProvider =
    FutureProvider.autoDispose<List<Course>>((ref) async {
  return CourseService.listLibrary();
});

// ── Course detail (full script) ───────────────────────────────────────────────
final courseDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, scriptId) => CourseService.getCourseDetail(scriptId),
);

// ── Course lessons parsed from real script ────────────────────────────────────
// Calls getCourseDetail and converts modules[].lessons[] → CourseLesson list.
// Lesson IDs: 'm{moduleNum}l{lessonNum}' e.g. 'm1l1', 'm2l3'.
final courseLessonsProvider =
    FutureProvider.autoDispose.family<List<CourseLesson>, String>(
  (ref, courseId) async {
    final detail = await CourseService.getCourseDetail(courseId);
    final script = detail['course_script'] as Map<String, dynamic>? ?? {};
    final modules = script['modules'] as List? ?? [];
    final lessons = <CourseLesson>[];

    if (modules.isNotEmpty) {
      // Standard generated course: modules → lessons
      for (final mod in modules) {
        final modMap = mod as Map<String, dynamic>;
        final moduleNum = (modMap['module_number'] as num).toInt();
        final moduleTitle =
            modMap['module_title'] as String? ?? 'Module $moduleNum';
        final rawLessons = modMap['lessons'] as List? ?? [];
        for (final les in rawLessons) {
          final lesMap = les as Map<String, dynamic>;
          final lessonNum = (lesMap['lesson_number'] as num).toInt();
          lessons.add(CourseLesson(
            id: 'm${moduleNum}l$lessonNum',
            courseId: courseId,
            module: moduleTitle,
            moduleNum: moduleNum,
            title: lesMap['lesson_title'] as String? ?? 'Lesson $lessonNum',
            durationSecs:
                ((lesMap['duration_minutes'] as num?)?.toInt() ?? 0) * 60,
            narrationScript: lesMap['narration_script'] as String?,
          ));
        }
      }
    } else {
      // Custom / blueprint course: flat items list (module=1, lesson=index+1)
      final items = script['items'] as List? ?? [];
      for (int i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        final narration = item['narration'] as String? ??
            item['narration_script'] as String?;
        lessons.add(CourseLesson(
          id: 'm1l${i + 1}',
          courseId: courseId,
          module: 'Module 1',
          moduleNum: 1,
          title: item['title'] as String? ?? 'Lesson ${i + 1}',
          durationSecs:
              ((item['estimated_time_min'] as num?)?.toInt() ?? 0) * 60,
          narrationScript: narration,
        ));
      }
    }
    return lessons;
  },
);

// ── Documents ─────────────────────────────────────────────────────────────────
final documentsApiProvider =
    FutureProvider.autoDispose<List<DocumentInfo>>((ref) async {
  return DocumentService.listDocuments();
});

// ── Refreshable documents notifier ───────────────────────────────────────────
class DocumentsNotifier
    extends AutoDisposeAsyncNotifier<List<DocumentInfo>> {
  @override
  Future<List<DocumentInfo>> build() => DocumentService.listDocuments();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(DocumentService.listDocuments);
  }
}

final documentsNotifierProvider = AsyncNotifierProvider.autoDispose<
    DocumentsNotifier, List<DocumentInfo>>(DocumentsNotifier.new);

// ── Learner identity ──────────────────────────────────────────────────────────
// No auth yet — fixed learner ID. Replace with real auth when available.
final learnerIdProvider = StateProvider<String>((ref) => 'ariba@arresto.in');

// ── Active tutor sessions ─────────────────────────────────────────────────────
// Maps courseId → sessionId. Survives navigation within the app session.
final tutorSessionMapProvider =
    StateProvider<Map<String, String>>((ref) => {});

// ── Tutor session (legacy single holder kept for compatibility) ───────────────
final tutorSessionProvider =
    StateProvider.autoDispose<TutorSession?>((ref) => null);

// ── Assessment quiz from tutor session ───────────────────────────────────────
// Generates AI quiz questions for a course. Requires an active tutor session
// (created when the learner enters a lesson in that course).
final tutorQuizProvider =
    FutureProvider.autoDispose.family<List<TutorQuizQuestion>, String>(
  (ref, courseId) async {
    final sessionMap = ref.watch(tutorSessionMapProvider);
    final sessionId = sessionMap[courseId];
    if (sessionId == null) {
      throw Exception(
          'Start a lesson in this course before taking the assessment.');
    }
    return TutorService.generateQuiz(sessionId);
  },
);

// ── Last completed assessment result ─────────────────────────────────────────
// Populated by AssessmentQuizScreen on submit; read by AssessmentResultScreen.
class QuizResult {
  final int correct;
  final int total;
  final int score; // 0-100
  const QuizResult(
      {required this.correct, required this.total, required this.score});
}

final quizResultsProvider = StateProvider<QuizResult?>((ref) => null);
