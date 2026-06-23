import 'package:intl/intl.dart';

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

  factory Reply.fromJson(Map<String, dynamic> j) {
    final ts = (j['created_at'] as num).toDouble();
    final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    return Reply(
      id:      j['id']     as String,
      author:  j['author'] as String,
      body:    j['body']   as String,
      isAdmin: j['is_admin'] as bool,
      time:    DateFormat('d MMM yyyy, HH:mm').format(dt),
    );
  }
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

  factory Ticket.fromJson(Map<String, dynamic> j) {
    final ts = (j['created_at'] as num).toDouble();
    final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    final rawReplies = j['replies'] as List? ?? [];
    return Ticket(
      id:          j['id']           as String,
      subject:     j['subject']      as String,
      category:    j['category']     as String,
      priority:    j['priority']     as String,
      status:      j['status']       as String,
      learnerName: j['learner_name'] as String,
      email:       j['email']        as String,
      desc:        j['description']  as String,
      date:        DateFormat('d MMM yyyy').format(dt),
      replies:     rawReplies
          .map((r) => Reply.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
