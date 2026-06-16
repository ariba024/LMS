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
}
