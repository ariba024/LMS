class WeakTopic {
  final String courseId;
  final String topic;
  final double accuracy;
  final int totalAttempts;

  const WeakTopic({
    required this.courseId,
    required this.topic,
    required this.accuracy,
    required this.totalAttempts,
  });

  factory WeakTopic.fromJson(Map<String, dynamic> j) => WeakTopic(
        courseId:     j['course_id']     as String,
        topic:        j['topic']         as String,
        accuracy:     (j['accuracy'] as num).toDouble(),
        totalAttempts: j['total_attempts'] as int,
      );
}

class Learner {
  final String id;
  final String name;
  final String email;
  final int enrolled;
  final int progress;
  final String lastActive;
  final String time;
  final int assessments;
  final String status;

  const Learner({
    required this.id,
    required this.name,
    required this.email,
    required this.enrolled,
    required this.progress,
    required this.lastActive,
    required this.time,
    required this.assessments,
    required this.status,
  });

  factory Learner.fromJson(Map<String, dynamic> j) => Learner(
        id:          j['id']          as String,
        name:        j['name']        as String,
        email:       j['email']       as String,
        enrolled:    j['enrolled']    as int,
        progress:    j['progress']    as int,
        lastActive:  j['last_active'] as String,
        time:        j['time']        as String,
        assessments: j['assessments'] as int,
        status:      j['status']      as String,
      );
}
