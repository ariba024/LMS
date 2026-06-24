import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/api_client.dart';
import '../../core/services/assessment_service.dart';
import '../../core/services/course_service.dart';
import '../../core/services/document_service.dart';
import '../../core/services/attention_service.dart' show AttentionService, LessonAttentionStat;
import '../../core/services/learner_service.dart' show LearnerService, LearnerCourseStat, ProfileData;
import '../../core/services/notification_service.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/tutor_service.dart';
import '../../core/services/video_service.dart';
import '../models/course.dart';
import '../models/gamification.dart' show LearnerGamificationStats;
import '../models/learner.dart';
import '../models/lesson.dart' show CourseLesson;
import '../models/notification_model.dart';

// ── Course library (list) ─────────────────────────────────────────────────────
final libraryProvider =
    FutureProvider.autoDispose<List<Course>>((ref) async {
  return CourseService.listLibrary();
});

// ── Course search (filtered library) ─────────────────────────────────────────
// Family key: 'q|category' — pass empty string for no filter.
final courseSearchProvider =
    FutureProvider.autoDispose.family<List<Course>, ({String q, String category})>(
  (ref, args) => CourseService.listLibrary(q: args.q, category: args.category),
);

// ── Gamification active courses ───────────────────────────────────────────────
// Returns the set of course_ids that have at least one daily question or hazard session.
final gamificationActiveCoursesProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  try {
    final resp = await apiClient.get('/api/v1/gamification/active-courses');
    final ids = resp.data as List;
    return ids.map((e) => e as String).toSet();
  } catch (_) {
    return const <String>{};
  }
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
final learnerIdProvider = Provider<String>((ref) {
  final user = ref.watch(authProvider).user;
  return user?.email ?? '';
});

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
// Populated by AssessmentQuizScreen on submit; read by result + review screens.
class QuizResult {
  final int correct;
  final int total;
  final int score;           // 0-100
  final int elapsedSeconds;
  final int passPct;         // pass threshold from course config
  final Map<String, String> answers;        // questionId → selected option key
  final Map<String, String> correctAnswers; // questionId → correct option key
  final Map<String, String> explanations;   // questionId → explanation text
  final List<AssessmentQuestion> questions; // full question list for review

  const QuizResult({
    required this.correct,
    required this.total,
    required this.score,
    this.elapsedSeconds = 0,
    this.passPct = 70,
    this.answers = const {},
    this.correctAnswers = const {},
    this.explanations = const {},
    this.questions = const [],
  });
}

final quizResultsProvider = StateProvider<QuizResult?>((ref) => null);

// ── Assessment questions (from course instructions + script) ──────────────────
// Generated by the backend from the admin's instructions (which contain the quiz)
// and cached in the DB. No tutor session required.
final assessmentQuestionsProvider =
    FutureProvider.autoDispose.family<List<AssessmentQuestion>, String>(
  (ref, courseId) => AssessmentService.getQuestions(courseId),
);

// ── Assessment attempt history (per-course) ───────────────────────────────────
final assessmentAttemptsProvider =
    FutureProvider.autoDispose.family<List<AssessmentAttempt>, String>(
  (ref, courseId) {
    final learnerId = ref.read(learnerIdProvider);
    return AssessmentService.getAttempts(courseId, learnerId: learnerId);
  },
);

// ── Assessment history (all courses) ─────────────────────────────────────────
// Used by the Assessments tab to show the learner's full attempt history.
final assessmentHistoryProvider =
    FutureProvider.autoDispose<List<AssessmentHistoryItem>>((ref) {
  final learnerId = ref.read(learnerIdProvider);
  return AssessmentService.getAllAttempts(learnerId);
});

// ── Video renders for a course ───────────────────────────────────────────────
// Fetches all render jobs for a course script. Returns empty list on error.
final videoRendersProvider =
    FutureProvider.autoDispose.family<List<VideoRenderJob>, String>(
  (ref, scriptId) async {
    try {
      return await VideoService.listRenders(scriptId);
    } catch (_) {
      return const [];
    }
  },
);

// ── Learner profile ───────────────────────────────────────────────────────────
final profileProvider =
    FutureProvider.autoDispose.family<ProfileData, String>(
  (ref, learnerId) => LearnerService.getProfile(learnerId),
);

// ── Admin: learners list (family keyed on search query) ───────────────────────
// Pass empty string for unfiltered. Backend applies SQL ILIKE search.
final learnersApiProvider =
    FutureProvider.autoDispose.family<List<Learner>, String>(
  (ref, q) => LearnerService.listLearners(q: q),
);

// ── Admin: single learner detail ──────────────────────────────────────────────
final learnerDetailApiProvider =
    FutureProvider.autoDispose.family<Learner, String>(
  (ref, learnerId) => LearnerService.getLearnerDetail(learnerId),
);

// ── Admin: per-course breakdown for one learner ───────────────────────────────
final learnerCoursesProvider =
    FutureProvider.autoDispose.family<List<LearnerCourseStat>, String>(
  (ref, learnerId) => LearnerService.getLearnerCourses(learnerId),
);

// ── Admin: per-lesson attention summary for one learner ──────────────────────
final learnerAttentionProvider =
    FutureProvider.autoDispose.family<List<LessonAttentionStat>, String>(
  (ref, learnerId) async {
    try {
      return await AttentionService.getSummary(learnerId);
    } catch (_) {
      return const [];
    }
  },
);

// ── Analytics overview ────────────────────────────────────────────────────────
final analyticsOverviewProvider =
    FutureProvider.autoDispose<AnalyticsOverview>(
  (ref) => AnalyticsService.getOverview(),
);

// ── Per-course analytics ──────────────────────────────────────────────────────
final courseStatsProvider =
    FutureProvider.autoDispose<List<CourseStatItem>>(
  (ref) => AnalyticsService.getCourseStats(),
);

// ── AI Tutor analytics ────────────────────────────────────────────────────────
final tutorStatsProvider =
    FutureProvider.autoDispose<TutorStats>(
  (ref) => AnalyticsService.getTutorStats(),
);

// ── Learner engagement funnel ─────────────────────────────────────────────────
final funnelProvider =
    FutureProvider.autoDispose<List<FunnelStep>>(
  (ref) => AnalyticsService.getFunnel(),
);

// ── Notifications (real API) ──────────────────────────────────────────────────
// recipientId is the learner's ID for learner notifications, or 'admin' for
// admin-wide notifications. The header passes the correct value based on role.
final notificationsProvider =
    FutureProvider.autoDispose.family<List<NotificationModel>, String>(
  (ref, recipientId) => NotificationService.list(recipientId),
);

// ── Course progress summary for current learner ──────────────────────────────
// Maps course_id → percent complete (0–100).
// Calls GET /api/v1/progress/me/summary — falls back to empty map on error.
final courseProgressSummaryProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  try {
    final resp = await apiClient.get('/api/v1/progress/me/summary');
    final data = resp.data as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, (v['percent'] as num).toInt()));
  } catch (_) {
    return const <String, int>{};
  }
});

// ── Enrolled course IDs for the current learner ──────────────────────────────
// Calls GET /api/v1/learners/me/enrolled-courses — returns the set of course_ids
// that have at least one lesson_record row. Falls back to empty set on error so
// My Courses degrades gracefully when the endpoint is unavailable.
final enrolledCourseIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  try {
    final resp = await apiClient.get('/api/v1/learners/me/enrolled-courses');
    final ids = (resp.data['course_ids'] as List).cast<String>();
    return ids.toSet();
  } catch (_) {
    return const <String>{};
  }
});

// ── Learner gamification aggregate stats ─────────────────────────────────────
// Calls GET /api/v1/gamification/me/stats — returns max streak, total XP,
// and total lessons completed across all courses. Falls back to zeroes on error.
final gamificationStatsProvider =
    FutureProvider.autoDispose<LearnerGamificationStats>((ref) async {
  try {
    final resp = await apiClient.get('/api/v1/gamification/me/stats');
    return LearnerGamificationStats.fromJson(
        resp.data as Map<String, dynamic>);
  } catch (_) {
    return const LearnerGamificationStats(
        maxStreak: 0, totalXp: 0, totalLessonsCompleted: 0);
  }
});

// ── Admin: course generation jobs ────────────────────────────────────────────
// Calls GET /api/v1/courses/jobs — returns up to 10 most recent jobs.
// Each job: {job_id, status, title, progress (0–1), started_at}.
class CourseJob {
  final String jobId;
  final String status; // pending | running | completed | failed
  final String title;
  final double progress; // 0–1
  final String? sourceFile;
  final String? error;

  const CourseJob({
    required this.jobId,
    required this.status,
    required this.title,
    required this.progress,
    this.sourceFile,
    this.error,
  });

  factory CourseJob.fromJson(Map<String, dynamic> j) => CourseJob(
        jobId: j['job_id'] as String,
        status: j['status'] as String,
        title: j['title'] as String? ?? 'Untitled',
        progress: (j['progress'] as num).toDouble(),
        sourceFile: j['source_file'] as String?,
        error: j['error'] as String?,
      );
}

final courseJobsProvider =
    FutureProvider.autoDispose<List<CourseJob>>((ref) async {
  try {
    final resp = await apiClient.get('/api/v1/courses/jobs');
    return (resp.data as List)
        .map((e) => CourseJob.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
});

// ── Adaptive recommendations for a course ────────────────────────────────────
// Derived from weak_topics and lesson checkpoint scores. Returns an empty list
// when the learner has no history yet (not an error state).
final recommendationsProvider =
    FutureProvider.autoDispose.family<List<Recommendation>, String>(
  (ref, courseId) async {
    final learnerId = ref.read(learnerIdProvider);
    try {
      return await ProgressService.getRecommendations(learnerId, courseId);
    } catch (_) {
      return const [];
    }
  },
);
