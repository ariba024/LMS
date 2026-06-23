import '../../core/widgets/course_thumb.dart';

class Lesson {
  final String id;
  final String title;
  final int mins;
  final String style;
  final String status; // completed, in-progress, locked

  const Lesson({
    required this.id,
    required this.title,
    required this.mins,
    required this.style,
    this.status = 'locked',
  });
}

class Module {
  final String id;
  final String title;
  final List<Lesson> lessons;

  const Module({required this.id, required this.title, required this.lessons});
}

class Course {
  final String id;
  final String title;
  final String desc;
  final String cat;
  final CourseStyle style;
  final String status;
  final String level;
  final int lessons;
  final int mins;
  final int progress;
  final int learners;
  final double rating;
  final bool certified;
  final String code;
  final List<Module> modules;

  const Course({
    required this.id,
    required this.title,
    required this.desc,
    required this.cat,
    required this.style,
    required this.status,
    required this.level,
    required this.lessons,
    required this.mins,
    required this.progress,
    required this.learners,
    required this.rating,
    required this.certified,
    required this.code,
    this.modules = const [],
  });

  Course copyWith({int? progress, int? lessons, int? mins}) {
    return Course(
      id: id,
      title: title,
      desc: desc,
      cat: cat,
      style: style,
      status: status,
      level: level,
      lessons: lessons ?? this.lessons,
      mins: mins ?? this.mins,
      progress: progress ?? this.progress,
      learners: learners,
      rating: rating,
      certified: certified,
      code: code,
      modules: modules,
    );
  }
}
