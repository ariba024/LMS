class Reply {
  final String id;
  final String author;
  final String body;
  final String time;
  final bool isAdmin;

  const Reply({
    required this.id,
    required this.author,
    required this.body,
    required this.time,
    required this.isAdmin,
  });
}

class Ticket {
  final String id;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final String learnerName;
  final String email;
  final String date;
  final String desc;
  final List<Reply> replies;

  const Ticket({
    required this.id,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.learnerName,
    required this.email,
    required this.date,
    required this.desc,
    this.replies = const [],
  });
}
