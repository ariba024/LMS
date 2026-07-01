import 'api_client.dart';

class LessonAttentionStat {
  final String lessonId;
  final int distractedCount;
  final int warningCount;
  final int returnedCount;
  final double focusScore;

  const LessonAttentionStat({
    required this.lessonId,
    required this.distractedCount,
    required this.warningCount,
    required this.returnedCount,
    required this.focusScore,
  });

  factory LessonAttentionStat.fromJson(Map<String, dynamic> j) =>
      LessonAttentionStat(
        lessonId: j['lesson_id'] as String,
        distractedCount: (j['distracted_count'] as num).toInt(),
        warningCount: (j['warning_count'] as num).toInt(),
        returnedCount: (j['returned_count'] as num).toInt(),
        focusScore: (j['focus_score'] as num).toDouble(),
      );
}

class AttentionService {
  /// Fire-and-forget — never throws; never blocks the learner.
  static Future<void> logEvent({
    required String courseId,
    required String lessonId,
    required String eventType,
    required int posSecs,
  }) async {
    try {
      await apiClient.post('/api/v1/attention/events', data: {
        'course_id': courseId,
        'lesson_id': lessonId,
        'event_type': eventType,
        'pos_secs': posSecs,
      });
    } catch (_) {}
  }

  static Future<List<LessonAttentionStat>> getSummary(String learnerId) async {
    final resp = await apiClient.get('/api/v1/attention/summary/$learnerId');
    final lessons = (resp.data as Map<String, dynamic>)['lessons'] as List;
    return lessons
        .map((j) => LessonAttentionStat.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
