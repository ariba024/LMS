class NotificationModel {
  final String id;
  final String icon;
  final String title;
  final String body;
  final String time;
  bool read;
  final String role;

  NotificationModel({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.read,
    required this.role,
  });
}
