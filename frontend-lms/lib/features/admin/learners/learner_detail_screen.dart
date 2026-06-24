import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/services/attention_service.dart' show LessonAttentionStat;
import '../../../core/services/learner_service.dart' show LearnerCourseStat, LearnerService;
import '../../../data/models/learner.dart' show WeakTopic;
import '../../../data/providers/api_providers.dart';

class LearnerDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const LearnerDetailScreen({super.key, required this.id});

  @override
  ConsumerState<LearnerDetailScreen> createState() =>
      _LearnerDetailScreenState();
}

class _LearnerDetailScreenState extends ConsumerState<LearnerDetailScreen> {
  List<WeakTopic>? _weakTopics;
  bool _weakTopicsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeakTopics();
  }

  Future<void> _loadWeakTopics() async {
    try {
      final topics = await LearnerService.getWeakTopics(widget.id);
      if (mounted) {
        setState(() {
          _weakTopics = topics;
          _weakTopicsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _weakTopicsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final learnerAsync = ref.watch(learnerDetailApiProvider(widget.id));
    final coursesAsync = ref.watch(learnerCoursesProvider(widget.id));
    final attentionAsync = ref.watch(learnerAttentionProvider(widget.id));
    final learner = learnerAsync.valueOrNull;

    if (learner == null) {
      return Scaffold(
        backgroundColor: ArrestoColors.background,
        appBar: AppBar(
          backgroundColor: ArrestoColors.surface,
          foregroundColor: ArrestoColors.ink,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: learnerAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const Center(child: Text('Learner not found.')),
      );
    }

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      appBar: AppBar(
        backgroundColor: ArrestoColors.surface,
        foregroundColor: ArrestoColors.ink,
        title: Text(learner.name, style: ArrestoText.h4()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile header
            ArrestoCard(
              child: Row(
                children: [
                  ArrestoAvatar(name: learner.name, size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(learner.name, style: ArrestoText.h3()),
                        Text(learner.email, style: ArrestoText.small()),
                        const SizedBox(height: 6),
                        StatusBadge(status: learner.status),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Last active', style: ArrestoText.xs()),
                      Text(learner.lastActive,
                          style: ArrestoText.small(color: ArrestoColors.ink)
                              .copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Key stats strip
            Row(
              children: [
                _stat('${learner.enrolled}', 'Enrolled'),
                const SizedBox(width: 12),
                _stat('${learner.progress}%', 'Progress'),
                const SizedBox(width: 12),
                _stat(learner.time, 'Time Spent'),
                const SizedBox(width: 12),
                _stat('${learner.assessments}', 'Assessments'),
              ],
            ),
            const SizedBox(height: 16),

            // Overall progress bar
            ArrestoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Progress', style: ArrestoText.h4()),
                  const SizedBox(height: 12),
                  AnimatedArrestoProgressBar(
                    value: learner.progress / 100,
                    height: 10,
                  ),
                  const SizedBox(height: 4),
                  Text('${learner.progress}% complete across all courses',
                      style: ArrestoText.small()),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Per-course breakdown
            ArrestoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded,
                          size: 16, color: ArrestoColors.blue),
                      const SizedBox(width: 6),
                      Text('Course Breakdown', style: ArrestoText.h4()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (coursesAsync.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (coursesAsync.hasError ||
                      (coursesAsync.valueOrNull?.isEmpty ?? true))
                    Text(
                      'No course activity yet.',
                      style: ArrestoText.bodySm(
                          color: ArrestoColors.textMuted),
                    )
                  else
                    ...coursesAsync.value!.map((c) => _CourseStatRow(stat: c)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Attention insights
            ArrestoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility_rounded,
                          size: 16, color: ArrestoColors.blue),
                      const SizedBox(width: 6),
                      Text('Attention Insights', style: ArrestoText.h4()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (attentionAsync.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (attentionAsync.valueOrNull?.isEmpty ?? true)
                    Text(
                      'No attention data yet. Enable focus monitoring '
                      'during lessons to start tracking.',
                      style: ArrestoText.bodySm(color: ArrestoColors.textMuted),
                    )
                  else
                    ...attentionAsync.value!.map(
                      (s) => _AttentionStatRow(stat: s),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Weak topics
            ArrestoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: ArrestoColors.amber),
                      const SizedBox(width: 6),
                      Text('Weak Topics', style: ArrestoText.h4()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_weakTopicsLoading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else if (_weakTopics == null || _weakTopics!.isEmpty)
                    Text(
                      'No weak topics identified yet — '
                      'topics appear once the learner answers quiz questions.',
                      style: ArrestoText.bodySm(
                          color: ArrestoColors.textMuted),
                    )
                  else
                    ..._weakTopics!.map((t) => _WeakTopicRow(topic: t)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ArrestoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArrestoColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(value, style: ArrestoText.h3()),
            Text(label, style: ArrestoText.xs()),
          ],
        ),
      ),
    );
  }
}

// ── Per-course progress row ───────────────────────────────────────────────────

class _CourseStatRow extends StatelessWidget {
  final LearnerCourseStat stat;
  const _CourseStatRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final pct = stat.percent;
    final Color barColor = pct >= 80
        ? ArrestoColors.green
        : pct >= 40
            ? ArrestoColors.orange
            : ArrestoColors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stat.title,
                    style: ArrestoText.bodyBold(),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text('$pct%',
                  style: ArrestoText.smallBold(color: barColor)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: ArrestoColors.line,
            valueColor: AlwaysStoppedAnimation(barColor),
            minHeight: 5,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${stat.completed}/${stat.total} lessons',
                style: ArrestoText.xs(color: ArrestoColors.textMuted),
              ),
              const Spacer(),
              if (stat.attempts > 0)
                Text(
                  'Best: ${stat.bestScore}%  •  ${stat.attempts} attempt${stat.attempts == 1 ? '' : 's'}',
                  style: ArrestoText.xs(color: ArrestoColors.textMuted),
                )
              else
                Text('No assessment attempts',
                    style: ArrestoText.xs(color: ArrestoColors.textMuted)),
              const SizedBox(width: 8),
              Text('Last: ${stat.lastActive}',
                  style: ArrestoText.xs(color: ArrestoColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Attention stat row ────────────────────────────────────────────────────────

class _AttentionStatRow extends StatelessWidget {
  final LessonAttentionStat stat;
  const _AttentionStatRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final score = stat.focusScore;
    final Color scoreColor = score >= 70
        ? ArrestoColors.green
        : score >= 40
            ? ArrestoColors.orange
            : ArrestoColors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.lessonId.toUpperCase(),
                  style: ArrestoText.bodyBold(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${score.toStringAsFixed(0)}% recovery',
                  style: ArrestoText.xs(color: scoreColor)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _chip(Icons.visibility_off_rounded,
                  '${stat.distractedCount} distracted', ArrestoColors.red),
              const SizedBox(width: 8),
              _chip(Icons.warning_amber_rounded,
                  '${stat.warningCount} warnings', ArrestoColors.amber),
              const SizedBox(width: 8),
              _chip(Icons.check_circle_outline_rounded,
                  '${stat.returnedCount} returned', ArrestoColors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: ArrestoText.xs(color: color)),
    ]);
  }
}

// ── Weak topic row ────────────────────────────────────────────────────────────

class _WeakTopicRow extends StatelessWidget {
  final WeakTopic topic;
  const _WeakTopicRow({required this.topic});

  @override
  Widget build(BuildContext context) {
    final pct = (topic.accuracy * 100).round();
    final color = pct >= 70
        ? ArrestoColors.green
        : pct >= 40
            ? ArrestoColors.amber
            : ArrestoColors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(topic.topic,
                    style: ArrestoText.bodySm(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text('$pct%',
                  style: ArrestoText.smallBold(color: color)),
              const SizedBox(width: 6),
              Text('(${topic.totalAttempts} attempts)',
                  style: ArrestoText.xs(color: ArrestoColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: topic.accuracy.clamp(0.0, 1.0),
            backgroundColor: ArrestoColors.line,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    );
  }
}
