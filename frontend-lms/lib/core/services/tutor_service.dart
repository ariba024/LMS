import 'api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class TutorSession {
  final String sessionId;
  final String courseTitle;
  final int currentModule;
  final int currentLesson;

  const TutorSession({
    required this.sessionId,
    required this.courseTitle,
    required this.currentModule,
    required this.currentLesson,
  });

  factory TutorSession.fromJson(Map<String, dynamic> j) => TutorSession(
        sessionId: j['session_id'] as String,
        courseTitle: j['course_title'] as String? ?? '',
        currentModule: (j['current_module'] as num?)?.toInt() ?? 1,
        currentLesson: (j['current_lesson'] as num?)?.toInt() ?? 1,
      );
}

class TutorQuizQuestion {
  final String questionId;
  final String question;
  final Map<String, String> options;

  const TutorQuizQuestion({
    required this.questionId,
    required this.question,
    required this.options,
  });

  factory TutorQuizQuestion.fromJson(Map<String, dynamic> j) {
    final opts = (j['options'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v as String));
    return TutorQuizQuestion(
      questionId: j['question_id'] as String,
      question: j['question'] as String,
      options: opts,
    );
  }
}

class TutorAnswerResult {
  final bool correct;
  final String correctAnswer;
  final String explanation;
  final bool checkpointComplete;
  final double? checkpointScore;

  const TutorAnswerResult({
    required this.correct,
    required this.correctAnswer,
    required this.explanation,
    required this.checkpointComplete,
    this.checkpointScore,
  });

  factory TutorAnswerResult.fromJson(Map<String, dynamic> j) =>
      TutorAnswerResult(
        correct: j['correct'] as bool? ?? false,
        correctAnswer: j['correct_answer'] as String? ?? '',
        explanation: j['explanation'] as String? ?? '',
        checkpointComplete: j['checkpoint_complete'] as bool? ?? false,
        checkpointScore:
            (j['checkpoint_score'] as num?)?.toDouble(),
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class TutorService {
  /// Create a tutor session from a library script.
  /// [scriptId] — the UUID from the course library.
  /// [learnerId] — any stable identifier for the learner (e.g. email).
  static Future<TutorSession> createSession({
    required String scriptId,
    required String learnerId,
    int startModule = 1,
    int startLesson = 1,
  }) async {
    final resp = await apiClient.post('/api/v1/tutor/session', data: {
      'script_id': scriptId,
      'learner_id': learnerId,
      'current_module': startModule,
      'current_lesson': startLesson,
    });
    return TutorSession.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Send a chat message to the tutor and get a reply.
  static Future<String> chat(String sessionId, String message) async {
    final resp = await apiClient.post(
      '/api/v1/tutor/session/$sessionId/chat',
      data: {'message': message},
    );
    return resp.data['reply'] as String;
  }

  /// Generate a practice quiz for the current lesson.
  static Future<List<TutorQuizQuestion>> generateQuiz(
      String sessionId) async {
    final resp =
        await apiClient.post('/api/v1/tutor/session/$sessionId/quiz');
    final questions = resp.data['questions'] as List;
    return questions
        .map((q) => TutorQuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  /// Trigger the gated lesson checkpoint (3 questions required to advance).
  static Future<List<TutorQuizQuestion>> completeLessonCheckpoint(
      String sessionId) async {
    final resp = await apiClient
        .post('/api/v1/tutor/session/$sessionId/complete-lesson');
    final questions = resp.data['questions'] as List;
    return questions
        .map((q) => TutorQuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  /// Submit an answer to a quiz question.
  static Future<TutorAnswerResult> submitAnswer(
      String sessionId, String questionId, String answer) async {
    final resp = await apiClient.post(
      '/api/v1/tutor/session/$sessionId/answer',
      data: {'question_id': questionId, 'answer': answer},
    );
    return TutorAnswerResult.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Advance to the next lesson (or trigger module checkpoint).
  static Future<Map<String, dynamic>> nextLesson(String sessionId) async {
    final resp = await apiClient
        .post('/api/v1/tutor/session/$sessionId/next-lesson');
    return resp.data as Map<String, dynamic>;
  }

  /// Returns the streaming URL for a lesson's audio narration.
  /// Audio is generated on-demand by the backend and cached as MP3.
  static String audioUrl(String scriptId, int moduleNum, int lessonNum) =>
      '${apiClient.options.baseUrl}/api/v1/audio/$scriptId/$moduleNum/$lessonNum';
}
