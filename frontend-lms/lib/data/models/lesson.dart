class CourseLesson {
  final String id;
  final String courseId;
  final String module;
  final int moduleNum;
  final String title;
  final int durationSecs;
  final bool completed;
  final int savedPositionSecs;
  // Full narration script text from the backend course_script (may be null for mock lessons).
  final String? narrationScript;

  const CourseLesson({
    required this.id,
    required this.courseId,
    required this.module,
    required this.moduleNum,
    required this.title,
    required this.durationSecs,
    this.completed = false,
    this.savedPositionSecs = 0,
    this.narrationScript,
  });

  String get durationLabel {
    if (durationSecs == 0) return '—';
    final m = durationSecs ~/ 60;
    final s = durationSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Parse moduleNum from a lesson ID formatted as 'm{moduleNum}l{lessonNum}'.
  static int moduleNumFromId(String id) {
    final lIdx = id.indexOf('l');
    return int.tryParse(id.substring(1, lIdx)) ?? 1;
  }

  /// Parse lessonNum from a lesson ID formatted as 'm{moduleNum}l{lessonNum}'.
  static int lessonNumFromId(String id) {
    final lIdx = id.indexOf('l');
    return int.tryParse(id.substring(lIdx + 1)) ?? 1;
  }
}
