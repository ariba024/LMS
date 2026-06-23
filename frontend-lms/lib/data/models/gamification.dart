class DailyQuestion {
  final String questionId;
  final String questionText;
  final List<String> options;
  final int xpReward;
  final bool alreadyAttempted;
  final int? selectedIndex;
  final bool? isCorrect;
  final int? correctIndex;
  final String? explanation;

  const DailyQuestion({
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.xpReward,
    required this.alreadyAttempted,
    this.selectedIndex,
    this.isCorrect,
    this.correctIndex,
    this.explanation,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> j) => DailyQuestion(
        questionId: j['question_id'] as String,
        questionText: j['question_text'] as String,
        options: List<String>.from(j['options'] as List),
        xpReward: j['xp_reward'] as int,
        alreadyAttempted: j['already_attempted'] as bool,
        selectedIndex: j['selected_index'] as int?,
        isCorrect: j['is_correct'] as bool?,
        correctIndex: j['correct_index'] as int?,
        explanation: j['explanation'] as String?,
      );
}

class HazardRegion {
  final String label;
  final String note;
  final double cx;
  final double cy;
  final double r;

  const HazardRegion({
    required this.label,
    required this.note,
    required this.cx,
    required this.cy,
    required this.r,
  });

  factory HazardRegion.fromJson(Map<String, dynamic> j) => HazardRegion(
        label: j['label'] as String,
        note: j['note'] as String,
        cx: (j['cx'] as num).toDouble(),
        cy: (j['cy'] as num).toDouble(),
        r: (j['r'] as num).toDouble(),
      );
}

class HazardQuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const HazardQuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory HazardQuizQuestion.fromJson(Map<String, dynamic> j) =>
      HazardQuizQuestion(
        question: j['question'] as String,
        options: List<String>.from(j['options'] as List),
        correctIndex: j['correct_index'] as int,
        explanation: j['explanation'] as String,
      );
}

class HazardSession {
  final String sessionId;
  final String courseId;
  final String title;
  final String sceneDescription;
  final String? imageUrl;
  final List<HazardRegion> hazardRegions;
  final List<HazardQuizQuestion> quizQuestions;
  final int xpReward;

  const HazardSession({
    required this.sessionId,
    required this.courseId,
    required this.title,
    required this.sceneDescription,
    this.imageUrl,
    required this.hazardRegions,
    required this.quizQuestions,
    required this.xpReward,
  });

  factory HazardSession.fromJson(Map<String, dynamic> j) => HazardSession(
        sessionId: j['session_id'] as String,
        courseId: j['course_id'] as String,
        title: j['title'] as String,
        sceneDescription: j['scene_description'] as String,
        imageUrl: j['image_url'] as String?,
        hazardRegions: (j['hazard_regions'] as List)
            .map((e) => HazardRegion.fromJson(e as Map<String, dynamic>))
            .toList(),
        quizQuestions: (j['quiz_questions'] as List)
            .map((e) => HazardQuizQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        xpReward: j['xp_reward'] as int,
      );
}

class LeaderboardEntry {
  final int rank;
  final String learnerId;
  final String displayName;
  final int totalXp;
  final int dailyQXp;
  final int hazardXp;
  final int dailyQStreak;

  const LeaderboardEntry({
    required this.rank,
    required this.learnerId,
    required this.displayName,
    required this.totalXp,
    required this.dailyQXp,
    required this.hazardXp,
    required this.dailyQStreak,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: j['rank'] as int,
        learnerId: j['learner_id'] as String,
        displayName: j['display_name'] as String,
        totalXp: j['total_xp'] as int,
        dailyQXp: j['daily_q_xp'] as int,
        hazardXp: j['hazard_xp'] as int,
        dailyQStreak: j['daily_q_streak'] as int,
      );
}

class GamificationProfile {
  final String learnerId;
  final String courseId;
  final String displayName;
  final int totalXp;
  final int dailyQXp;
  final int hazardXp;
  final int dailyQStreak;
  final int? rank;

  const GamificationProfile({
    required this.learnerId,
    required this.courseId,
    required this.displayName,
    required this.totalXp,
    required this.dailyQXp,
    required this.hazardXp,
    required this.dailyQStreak,
    this.rank,
  });

  factory GamificationProfile.fromJson(Map<String, dynamic> j) =>
      GamificationProfile(
        learnerId: j['learner_id'] as String,
        courseId: j['course_id'] as String,
        displayName: j['display_name'] as String,
        totalXp: j['total_xp'] as int,
        dailyQXp: j['daily_q_xp'] as int,
        hazardXp: j['hazard_xp'] as int,
        dailyQStreak: j['daily_q_streak'] as int,
        rank: j['rank'] as int?,
      );
}
