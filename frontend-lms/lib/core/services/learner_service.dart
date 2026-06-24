import 'api_client.dart';
import '../../data/models/learner.dart' show Learner, WeakTopic;

class LearnerCourseStat {
  final String courseId;
  final String title;
  final int total;
  final int completed;
  final int percent;
  final String lastActive;
  final int attempts;
  final int bestScore; // -1 when no attempts yet

  const LearnerCourseStat({
    required this.courseId,
    required this.title,
    required this.total,
    required this.completed,
    required this.percent,
    required this.lastActive,
    required this.attempts,
    required this.bestScore,
  });

  factory LearnerCourseStat.fromJson(Map<String, dynamic> j) => LearnerCourseStat(
        courseId:   j['course_id']   as String,
        title:      j['title']       as String,
        total:      (j['total']      as num).toInt(),
        completed:  (j['completed']  as num).toInt(),
        percent:    (j['percent']    as num).toInt(),
        lastActive: j['last_active'] as String,
        attempts:   (j['attempts']   as num).toInt(),
        bestScore:  (j['best_score'] as num).toInt(),
      );
}

class ProfileData {
  final String learnerId;
  final String displayName;
  final String email;
  final int enrolledCourses;
  final int completedLessons;
  final int certificates;
  final String? avatarUrl;

  const ProfileData({
    required this.learnerId,
    required this.displayName,
    required this.email,
    required this.enrolledCourses,
    required this.completedLessons,
    required this.certificates,
    this.avatarUrl,
  });

  factory ProfileData.fromJson(Map<String, dynamic> j) => ProfileData(
        learnerId:        j['learner_id']        as String,
        displayName:      j['display_name']      as String,
        email:            j['email']             as String,
        enrolledCourses:  j['enrolled_courses']  as int,
        completedLessons: j['completed_lessons'] as int,
        certificates:     j['certificates']      as int,
        avatarUrl:        j['avatar_url']        as String?,
      );
}

class LearnerService {
  static Future<ProfileData> getProfile(String learnerId) async {
    final resp = await apiClient.get('/api/v1/profile/$learnerId');
    return ProfileData.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<void> updateDisplayName(String learnerId, String name) async {
    await apiClient.patch(
      '/api/v1/profile/$learnerId',
      data: {'display_name': name},
    );
  }

  static Future<List<Learner>> listLearners({String q = ''}) async {
    final resp = await apiClient.get(
      '/api/v1/learners',
      queryParameters: q.isNotEmpty ? {'q': q} : null,
    );
    final list = resp.data as List;
    return list
        .map((e) => Learner.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<LearnerCourseStat>> getLearnerCourses(String learnerId) async {
    final resp = await apiClient.get('/api/v1/learners/$learnerId/courses');
    return (resp.data as List)
        .map((e) => LearnerCourseStat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Learner> getLearnerDetail(String learnerId) async {
    final resp = await apiClient.get('/api/v1/learners/$learnerId');
    return Learner.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<List<WeakTopic>> getWeakTopics(String learnerId) async {
    final resp =
        await apiClient.get('/api/v1/progress/$learnerId/weak-topics');
    return (resp.data as List)
        .map((e) => WeakTopic.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
