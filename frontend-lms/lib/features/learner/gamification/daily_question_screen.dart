import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/gamification_service.dart';
import '../../../data/models/gamification.dart';

class DailyQuestionScreen extends StatefulWidget {
  final String courseId;
  final String learnerId;
  final String courseTitle;

  const DailyQuestionScreen({
    super.key,
    required this.courseId,
    required this.learnerId,
    required this.courseTitle,
  });

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  DailyQuestion? _question;
  bool _loading = true;
  String? _error;
  int? _selected;
  bool _submitted = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = await gamificationService.getDailyQuestion(
          widget.courseId, widget.learnerId);
      setState(() {
        _question = q;
        _loading = false;
        if (q.alreadyAttempted) {
          _submitted = true;
          _selected = q.selectedIndex;
          _result = {
            'is_correct': q.isCorrect,
            'correct_index': q.correctIndex,
            'explanation': q.explanation,
            'xp_earned': q.isCorrect == true ? q.xpReward : 5,
            'streak': 0,
          };
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selected == null || _question == null) return;
    setState(() => _loading = true);
    try {
      final res = await gamificationService.submitDailyQuestion(
        courseId: widget.courseId,
        learnerId: widget.learnerId,
        selectedIndex: _selected!,
      );
      setState(() {
        _result = res;
        _submitted = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrestoColors.background,
      appBar: AppBar(
        backgroundColor: ArrestoColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question of the Day',
                style: ArrestoText.base(color: ArrestoColors.ink)
                    .copyWith(fontWeight: FontWeight.w700)),
            Text(widget.courseTitle,
                style: ArrestoText.xs(color: ArrestoColors.textMuted)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _question == null
                  ? const Center(child: Text('No question available today.'))
                  : _QuestionView(
                      question: _question!,
                      selected: _selected,
                      submitted: _submitted,
                      result: _result,
                      onSelect: _submitted ? null : (i) => setState(() => _selected = i),
                      onSubmit: _submitted || _selected == null ? null : _submit,
                    ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final DailyQuestion question;
  final int? selected;
  final bool submitted;
  final Map<String, dynamic>? result;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onSubmit;

  const _QuestionView({
    required this.question,
    required this.selected,
    required this.submitted,
    required this.result,
    required this.onSelect,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final correct = result?['correct_index'] as int?;
    final isCorrect = result?['is_correct'] as bool?;
    final xpEarned = result?['xp_earned'] as int?;
    final streak = result?['streak'] as int?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ArrestoColors.amberSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        size: 14, color: ArrestoColors.amberStrong),
                    const SizedBox(width: 4),
                    Text('Daily Challenge · +${question.xpReward} XP',
                        style: ArrestoText.xs(color: ArrestoColors.amberStrong)
                            .copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Question text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ArrestoColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ArrestoColors.cardBorder),
              boxShadow: ArrestoColors.sh1,
            ),
            child: Text(
              question.questionText,
              style: ArrestoText.lg(color: ArrestoColors.ink)
                  .copyWith(fontWeight: FontWeight.w600, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),

          // Options
          ...List.generate(question.options.length, (i) {
            final label = String.fromCharCode(65 + i); // A, B, C, D
            Color bg = ArrestoColors.surface;
            Color border = ArrestoColors.cardBorder;
            Color textColor = ArrestoColors.textPrimary;
            IconData? icon;
            Color iconColor = ArrestoColors.textMuted;

            if (submitted) {
              if (i == correct) {
                bg = ArrestoColors.greenSoft;
                border = ArrestoColors.green;
                textColor = ArrestoColors.green;
                icon = Icons.check_circle_rounded;
                iconColor = ArrestoColors.green;
              } else if (i == selected && i != correct) {
                bg = ArrestoColors.redSoft;
                border = ArrestoColors.red;
                textColor = ArrestoColors.red;
                icon = Icons.cancel_rounded;
                iconColor = ArrestoColors.red;
              }
            } else if (i == selected) {
              bg = ArrestoColors.amberSoft;
              border = ArrestoColors.amberStrong;
              textColor = ArrestoColors.ink;
            }

            return GestureDetector(
              onTap: () => onSelect?.call(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: i == selected || (submitted && i == correct)
                            ? border
                            : ArrestoColors.bg2,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: i == selected || (submitted && i == correct)
                                  ? Colors.white
                                  : ArrestoColors.textMuted,
                            )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(question.options[i],
                          style: ArrestoText.base(color: textColor)),
                    ),
                    if (icon != null)
                      Icon(icon, size: 20, color: iconColor),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // Explanation (after submit)
          if (submitted && result?['explanation'] != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCorrect == true
                    ? ArrestoColors.greenSoft
                    : ArrestoColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect == true
                      ? ArrestoColors.green
                      : ArrestoColors.blue,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCorrect == true
                        ? Icons.lightbulb_rounded
                        : Icons.info_rounded,
                    size: 18,
                    color: isCorrect == true
                        ? ArrestoColors.green
                        : ArrestoColors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result!['explanation'] as String,
                      style: ArrestoText.small(
                          color: isCorrect == true
                              ? ArrestoColors.green
                              : ArrestoColors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // XP earned banner
          if (submitted && xpEarned != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ArrestoColors.ink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isCorrect == true ? '🎉 ' : '',
                    style: const TextStyle(fontSize: 20),
                  ),
                  Text(
                    isCorrect == true
                        ? '+$xpEarned XP earned!'
                        : '+$xpEarned XP for trying',
                    style: ArrestoText.base(color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (streak != null && streak > 1) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ArrestoColors.amberStrong,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('🔥 $streak day streak',
                          style: ArrestoText.xs(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),

          // Submit button
          if (!submitted) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: ArrestoColors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Submit Answer',
                    style: ArrestoText.base(color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: ArrestoColors.red),
            const SizedBox(height: 12),
            Text('Could not load question',
                style: ArrestoText.lg(color: ArrestoColors.ink)
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(error,
                style: ArrestoText.small(color: ArrestoColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: ArrestoColors.amber,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
