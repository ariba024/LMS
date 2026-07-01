import '../../data/models/gamification.dart';
import 'api_client.dart';

class GamificationService {
  Future<DailyQuestion> getDailyQuestion(String courseId, String learnerId) async {
    final r = await apiClient.get(
      '/api/v1/gamification/daily-question/$courseId',
      queryParameters: {'learner_id': learnerId},
    );
    return DailyQuestion.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> submitDailyQuestion({
    required String courseId,
    required String learnerId,
    required int selectedIndex,
  }) async {
    final r = await apiClient.post(
      '/api/v1/gamification/daily-question/$courseId/attempt',
      data: {'learner_id': learnerId, 'selected_index': selectedIndex},
    );
    return r.data as Map<String, dynamic>;
  }

  Future<List<HazardSession>> getHazardSessions(String courseId) async {
    final r = await apiClient.get('/api/v1/gamification/hazard-sessions/$courseId');
    return (r.data as List)
        .map((e) => HazardSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HazardSession>> generateHazardSessions(String courseId) async {
    final r = await apiClient.post(
      '/api/v1/gamification/hazard-sessions/$courseId/generate',
    );
    return (r.data as List)
        .map((e) => HazardSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> submitHazardAttempt({
    required String learnerId,
    required String sessionId,
    required String courseId,
    required int hazardsFound,
    required int totalHazards,
    required int quizCorrect,
    required int quizTotal,
    required int timeTakenSecs,
  }) async {
    final r = await apiClient.post('/api/v1/gamification/hazard-attempt', data: {
      'learner_id': learnerId,
      'session_id': sessionId,
      'course_id': courseId,
      'hazards_found': hazardsFound,
      'total_hazards': totalHazards,
      'quiz_correct': quizCorrect,
      'quiz_total': quizTotal,
      'time_taken_secs': timeTakenSecs,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<List<LeaderboardEntry>> getLeaderboard(String courseId) async {
    final r = await apiClient.get('/api/v1/gamification/leaderboard/$courseId');
    return (r.data as List)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LeaderboardEntry>> getGlobalLeaderboard() async {
    final r = await apiClient.get('/api/v1/gamification/leaderboard');
    return (r.data as List)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GamificationProfile> getProfile(String learnerId, String courseId) async {
    final r = await apiClient.get('/api/v1/gamification/profile/$learnerId/$courseId');
    return GamificationProfile.fromJson(r.data as Map<String, dynamic>);
  }
}

final gamificationService = GamificationService();
