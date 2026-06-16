import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/services/tutor_service.dart';
import '../../../data/providers/api_providers.dart';

class AssessmentQuizScreen extends ConsumerStatefulWidget {
  final String courseId;
  const AssessmentQuizScreen({super.key, required this.courseId});

  @override
  ConsumerState<AssessmentQuizScreen> createState() =>
      _AssessmentQuizScreenState();
}

class _AssessmentQuizScreenState extends ConsumerState<AssessmentQuizScreen> {
  Timer? _timer;
  int _secondsLeft = 30 * 60;
  int _currentIdx = 0;
  final Set<int> _flagged = {};

  // questionId → optionKey (A/B/C/D)
  final Map<String, String> _answers = {};
  // questionId → TutorAnswerResult (after server response)
  final Map<String, TutorAnswerResult> _results = {};
  bool _submittingAnswer = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        t.cancel();
        _submitAll([]);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeStr {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _selectAnswer(
      String sessionId, TutorQuizQuestion q, String optionKey) async {
    if (_answers.containsKey(q.questionId) || _submittingAnswer) return;
    setState(() {
      _answers[q.questionId] = optionKey;
      _submittingAnswer = true;
    });
    try {
      final result =
          await TutorService.submitAnswer(sessionId, q.questionId, optionKey);
      if (!mounted) return;
      setState(() {
        _results[q.questionId] = result;
        _submittingAnswer = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingAnswer = false);
    }
  }

  void _submitAll(List<TutorQuizQuestion> questions) {
    _timer?.cancel();
    final correct = _results.values.where((r) => r.correct).length;
    final total = questions.isNotEmpty ? questions.length : _answers.length;
    final score = total == 0 ? 0 : ((correct / total) * 100).round();
    ref.read(quizResultsProvider.notifier).state =
        QuizResult(correct: correct, total: total, score: score);
    context.go('/learner/assessment/${widget.courseId}/result');
  }

  @override
  Widget build(BuildContext context) {
    final sessionMap = ref.watch(tutorSessionMapProvider);
    final sessionId = sessionMap[widget.courseId];
    final questionsAsync = ref.watch(tutorQuizProvider(widget.courseId));

    return questionsAsync.when(
      loading: () => Column(
        children: [
          _appBar('Generating questions…'),
          const Expanded(child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: ArrestoColors.orange),
              SizedBox(height: 16),
              Text('Generating AI questions for your course…'),
            ]),
          )),
        ],
      ),
      error: (e, _) => Column(
        children: [
          _appBar('Assessment'),
          Expanded(child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.smart_toy_rounded,
                    color: ArrestoColors.textMuted2, size: 48),
                const SizedBox(height: 16),
                Text(
                  e.toString().contains('Start a lesson')
                      ? 'Please start a lesson in this course first to activate the AI tutor, then return here for your assessment.'
                      : 'Could not load questions: $e',
                  style: ArrestoText.body(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ArrestoButton(
                  label: 'Go to Course',
                  onPressed: () =>
                      context.go('/learner/course/${widget.courseId}'),
                ),
              ]),
            ),
          )),
        ],
      ),
      data: (questions) {
        if (questions.isEmpty) {
          return Column(
            children: [
              _appBar('Assessment'),
              Expanded(child: Center(
                child: Text(
                  'No questions generated. Try again after completing a lesson.',
                  style: ArrestoText.body(),
                  textAlign: TextAlign.center,
                ),
              )),
            ],
          );
        }
        if (_currentIdx >= questions.length) {
          // Clamp in case list shrunk
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _currentIdx = questions.length - 1));
        }
        final idx = _currentIdx.clamp(0, questions.length - 1);
        final q = questions[idx];
        final isFlagged = _flagged.contains(idx);
        final selectedKey = _answers[q.questionId];
        final result = _results[q.questionId];
        final answered = selectedKey != null;
        final opts = q.options.entries.toList();

        return Column(
          children: [
          AppBar(
            backgroundColor: ArrestoColors.surface,
            foregroundColor: ArrestoColors.ink,
            automaticallyImplyLeading: false,
            title: Row(children: [
              Text(
                'Q ${idx + 1}/${questions.length}',
                style: ArrestoText.h4(),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _secondsLeft < 300
                      ? ArrestoColors.redSoft
                      : ArrestoColors.bg2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(children: [
                  Icon(Icons.timer_rounded,
                      size: 14,
                      color: _secondsLeft < 300
                          ? ArrestoColors.red
                          : ArrestoColors.textMuted),
                  const SizedBox(width: 4),
                  Text(_timeStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _secondsLeft < 300
                            ? ArrestoColors.red
                            : ArrestoColors.ink,
                      )),
                ]),
              ),
            ]),
          ),
          Expanded(child: Column(children: [
            // Progress bar
            LinearProgressIndicator(
              value: (idx + 1) / questions.length,
              backgroundColor: ArrestoColors.line,
              valueColor: const AlwaysStoppedAnimation(ArrestoColors.amber),
              minHeight: 3,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question card
                    ArrestoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: ArrestoColors.blueSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('Multiple Choice',
                                  style: ArrestoText.xs(
                                      color: ArrestoColors.blue)),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() {
                                if (_flagged.contains(idx)) {
                                  _flagged.remove(idx);
                                } else {
                                  _flagged.add(idx);
                                }
                              }),
                              child: Row(children: [
                                Icon(
                                  isFlagged
                                      ? Icons.flag_rounded
                                      : Icons.flag_outlined,
                                  size: 16,
                                  color: isFlagged
                                      ? ArrestoColors.amber
                                      : ArrestoColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text('Flag',
                                    style: ArrestoText.small(
                                        color: isFlagged
                                            ? ArrestoColors.amber
                                            : ArrestoColors.textMuted)),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Text(q.question, style: ArrestoText.h3()),
                          const SizedBox(height: 16),

                          // Options
                          ...opts.map((opt) {
                            final isSelected = selectedKey == opt.key;
                            final isCorrectOpt =
                                result?.correctAnswer == opt.key;
                            Color bgColor = ArrestoColors.surface;
                            Color borderColor = ArrestoColors.line;
                            double borderWidth = 1;

                            if (answered) {
                              if (isSelected && result?.correct == true) {
                                bgColor = ArrestoColors.greenSoft;
                                borderColor = ArrestoColors.green;
                                borderWidth = 2;
                              } else if (isSelected &&
                                  result?.correct == false) {
                                bgColor = ArrestoColors.redSoft;
                                borderColor = ArrestoColors.red;
                                borderWidth = 2;
                              } else if (isCorrectOpt && !isSelected) {
                                bgColor = ArrestoColors.greenSoft;
                                borderColor = ArrestoColors.green;
                                borderWidth = 2;
                              }
                            } else if (isSelected) {
                              bgColor = ArrestoColors.amberSoft;
                              borderColor = ArrestoColors.amber;
                              borderWidth = 2;
                            }

                            return GestureDetector(
                              onTap: (answered ||
                                      _submittingAnswer ||
                                      sessionId == null)
                                  ? null
                                  : () => _selectAnswer(
                                      sessionId, q, opt.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color: borderColor,
                                      width: borderWidth),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? ArrestoColors.ink
                                          : ArrestoColors.bg2,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      opt.key,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : ArrestoColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      opt.value,
                                      style: ArrestoText.body(
                                          color: isSelected
                                              ? ArrestoColors.ink
                                              : null),
                                    ),
                                  ),
                                  if (answered && result != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      isCorrectOpt
                                          ? Icons.check_circle_rounded
                                          : (isSelected
                                              ? Icons.cancel_rounded
                                              : null),
                                      size: 18,
                                      color: isCorrectOpt
                                          ? ArrestoColors.green
                                          : ArrestoColors.red,
                                    ),
                                  ],
                                ]),
                              ),
                            );
                          }),

                          // Explanation after answering
                          if (answered && result != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: result.correct
                                    ? ArrestoColors.greenSoft
                                    : ArrestoColors.redSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    result.correct
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    color: result.correct
                                        ? ArrestoColors.green
                                        : ArrestoColors.red,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      result.explanation.isNotEmpty
                                          ? result.explanation
                                          : (result.correct
                                              ? 'Correct!'
                                              : 'Incorrect. The correct answer is ${result.correctAnswer}.'),
                                      style: ArrestoText.body(
                                          color: result.correct
                                              ? ArrestoColors.green
                                              : ArrestoColors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Submitting spinner
                          if (_submittingAnswer) ...[
                            const SizedBox(height: 12),
                            const Center(
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ArrestoColors.orange),
                                ),
                                SizedBox(width: 8),
                                Text('Checking answer…',
                                    style: TextStyle(
                                        color: ArrestoColors.textMuted,
                                        fontSize: 12)),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Question navigator
                    Text('Questions', style: ArrestoText.label()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          List.generate(questions.length, (i) {
                        final isCurrent = i == idx;
                        final qId = questions[i].questionId;
                        final isAnswered = _answers.containsKey(qId);
                        final isFlaggedQ = _flagged.contains(i);

                        Color bg;
                        Color border;
                        Color text;

                        if (isCurrent) {
                          bg = ArrestoColors.orange;
                          border = ArrestoColors.orange;
                          text = Colors.white;
                        } else if (isAnswered) {
                          bg = ArrestoColors.greenSoft;
                          border = ArrestoColors.green;
                          text = ArrestoColors.green;
                        } else if (isFlaggedQ) {
                          bg = ArrestoColors.amberSoft;
                          border = ArrestoColors.amber;
                          text = const Color(0xFF92400E);
                        } else {
                          bg = ArrestoColors.surface;
                          border = ArrestoColors.line;
                          text = ArrestoColors.textMuted;
                        }

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _currentIdx = i),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius:
                                  BorderRadius.circular(8),
                              border: Border.all(color: border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom navigation
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: const BoxDecoration(
                color: ArrestoColors.surface,
                border:
                    Border(top: BorderSide(color: ArrestoColors.line)),
              ),
              child: Row(children: [
                if (idx > 0)
                  ArrestoButton(
                    label: 'Previous',
                    variant: ArrestoButtonVariant.ghost,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () =>
                        setState(() => _currentIdx = idx - 1),
                  ),
                const Spacer(),
                if (idx < questions.length - 1)
                  ArrestoButton(
                    label: 'Next',
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () =>
                        setState(() => _currentIdx = idx + 1),
                  )
                else
                  ArrestoButton(
                    label: 'Submit',
                    variant: ArrestoButtonVariant.dark,
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () =>
                        _showSubmitDialog(context, questions),
                  ),
              ]),
            ),
          ])),
          ],
        );
      },
    );
  }

  AppBar _appBar(String title) => AppBar(
        backgroundColor: ArrestoColors.surface,
        foregroundColor: ArrestoColors.ink,
        title: Text(title, style: ArrestoText.h4()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      );

  void _showSubmitDialog(
      BuildContext context, List<TutorQuizQuestion> questions) {
    final unanswered =
        questions.where((q) => !_answers.containsKey(q.questionId)).length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArrestoColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Submit Assessment?', style: ArrestoText.h3()),
        content: Text(
          unanswered > 0
              ? '$unanswered question${unanswered > 1 ? 's' : ''} unanswered. Submit anyway?'
              : 'Are you sure you want to submit? You cannot change your answers after submission.',
          style: ArrestoText.body(),
        ),
        actions: [
          ArrestoButton(
            label: 'Cancel',
            variant: ArrestoButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 8),
          ArrestoButton(
            label: 'Submit',
            variant: ArrestoButtonVariant.dark,
            onPressed: () {
              Navigator.pop(ctx);
              _submitAll(questions);
            },
          ),
        ],
      ),
    );
  }
}
