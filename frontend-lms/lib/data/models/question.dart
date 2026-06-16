class Question {
  final String id;
  final String q;
  final List<String> opts;
  final int a;
  final String type;
  final String topic;
  final String lesson;
  final int points;
  final String why;

  const Question({
    required this.id,
    required this.q,
    required this.opts,
    required this.a,
    required this.type,
    required this.topic,
    required this.lesson,
    required this.points,
    required this.why,
  });
}
