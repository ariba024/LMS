import 'api_client.dart';

class MonthlyActivity {
  final String month;
  final int count;

  const MonthlyActivity({required this.month, required this.count});

  factory MonthlyActivity.fromJson(Map<String, dynamic> j) => MonthlyActivity(
        month: j['month'] as String,
        count: (j['count'] as num).toInt(),
      );
}

class AnalyticsOverview {
  final int totalCourses;
  final int totalVideos;
  final int totalLearners;
  final int activeLearners;
  final int totalAiSessions;
  final int newThisMonth;
  final double totalLearningHours;
  final List<MonthlyActivity> learnerActivity;
  final Map<String, int> styleDistribution;
  final List<int> generationByMonth;

  const AnalyticsOverview({
    required this.totalCourses,
    required this.totalVideos,
    required this.totalLearners,
    required this.activeLearners,
    this.totalAiSessions = 0,
    this.newThisMonth = 0,
    this.totalLearningHours = 0,
    required this.learnerActivity,
    required this.styleDistribution,
    this.generationByMonth = const [],
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> j) =>
      AnalyticsOverview(
        totalCourses:        j['total_courses']          as int,
        totalVideos:         j['total_videos']           as int,
        totalLearners:       j['total_learners']         as int,
        activeLearners:      j['active_learners']        as int,
        totalAiSessions:     j['total_ai_sessions']      as int?    ?? 0,
        newThisMonth:        j['new_this_month']         as int?    ?? 0,
        totalLearningHours:  (j['total_learning_hours'] as num?)?.toDouble() ?? 0,
        learnerActivity: (j['learner_activity'] as List)
            .map((e) => MonthlyActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
        styleDistribution: (j['style_distribution'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        // Backend returns List[MonthlyActivity] ({month, count}).
        // Extract the count; handle both numeric legacy format and dict format.
        generationByMonth: (j['generation_by_month'] as List?)
            ?.map((e) {
              if (e is num) return e.toInt();
              if (e is Map) return ((e as Map)['count'] as num?)?.toInt() ?? 0;
              return 0;
            })
            .toList() ?? const [],
      );
}

// ── Per-course analytics ───────────────────────────────────────────────────────

class CourseStatItem {
  final String courseId;
  final String title;
  final int enrolledLearners;
  final int completedLearners;
  final double completionRate;
  final double passRate;
  final double avgScore;
  final int totalAttempts;

  const CourseStatItem({
    required this.courseId,
    required this.title,
    required this.enrolledLearners,
    required this.completedLearners,
    required this.completionRate,
    required this.passRate,
    required this.avgScore,
    required this.totalAttempts,
  });

  factory CourseStatItem.fromJson(Map<String, dynamic> j) => CourseStatItem(
        courseId:          j['course_id']          as String,
        title:             j['title']              as String,
        enrolledLearners:  j['enrolled_learners']  as int,
        completedLearners: j['completed_learners'] as int,
        completionRate:    (j['completion_rate']   as num).toDouble(),
        passRate:          (j['pass_rate']         as num).toDouble(),
        avgScore:          (j['avg_score']         as num).toDouble(),
        totalAttempts:     j['total_attempts']     as int,
      );
}

// ── AI Tutor analytics ─────────────────────────────────────────────────────────

class TutorStats {
  final int totalSessions;
  final int activeLearners;
  final List<MonthlyActivity> sessionsByMonth;
  final List<Map<String, dynamic>> topCourses;

  const TutorStats({
    required this.totalSessions,
    required this.activeLearners,
    required this.sessionsByMonth,
    required this.topCourses,
  });

  factory TutorStats.fromJson(Map<String, dynamic> j) => TutorStats(
        totalSessions:  j['total_sessions']   as int,
        activeLearners: j['active_learners']  as int,
        sessionsByMonth: (j['sessions_by_month'] as List)
            .map((e) => MonthlyActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
        topCourses: (j['top_courses'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList(),
      );
}

// ── Engagement funnel ──────────────────────────────────────────────────────────

class FunnelStep {
  final String label;
  final int count;

  const FunnelStep({required this.label, required this.count});

  factory FunnelStep.fromJson(Map<String, dynamic> j) => FunnelStep(
        label: j['label'] as String,
        count: j['count'] as int,
      );
}

// ── Service ────────────────────────────────────────────────────────────────────

class AnalyticsService {
  static Future<AnalyticsOverview> getOverview() async {
    final resp = await apiClient.get('/api/v1/analytics/overview');
    return AnalyticsOverview.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<List<CourseStatItem>> getCourseStats() async {
    final resp = await apiClient.get('/api/v1/analytics/course-stats');
    return (resp.data['courses'] as List)
        .map((e) => CourseStatItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TutorStats> getTutorStats() async {
    final resp = await apiClient.get('/api/v1/analytics/tutor-stats');
    return TutorStats.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<List<FunnelStep>> getFunnel() async {
    final resp = await apiClient.get('/api/v1/analytics/funnel');
    return (resp.data['steps'] as List)
        .map((e) => FunnelStep.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
