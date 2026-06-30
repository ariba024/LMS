import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/gamification_service.dart';
import '../../../data/models/gamification.dart';

enum _Phase { intro, playing, quiz, result }

class SpotTheHazardScreen extends StatefulWidget {
  final String courseId;
  final String learnerId;
  final String courseTitle;

  const SpotTheHazardScreen({
    super.key,
    required this.courseId,
    required this.learnerId,
    required this.courseTitle,
  });

  @override
  State<SpotTheHazardScreen> createState() => _SpotTheHazardScreenState();
}

class _SpotTheHazardScreenState extends State<SpotTheHazardScreen> {
  List<HazardSession> _sessions = [];
  int _sessionIndex = 0;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  _Phase _phase = _Phase.intro;
  final Set<int> _found = {};
  Offset? _lastMiss;
  int _quizIndex = 0;
  final Map<int, int> _quizAnswers = {};
  int _startTimestamp = 0;
  int _xpEarned = 0;
  int _totalXp = 0;

  HazardSession? get _session =>
      _sessions.isEmpty ? null : _sessions[_sessionIndex];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions =
          await gamificationService.getHazardSessions(widget.courseId);
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final sessions =
          await gamificationService.generateHazardSessions(widget.courseId);
      setState(() {
        _sessions = sessions;
        _sessionIndex = 0;
        _generating = false;
        _phase = _Phase.intro;
      });
    } catch (e) {
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  void _startSession() {
    setState(() {
      _found.clear();
      _lastMiss = null;
      _quizIndex = 0;
      _quizAnswers.clear();
      _startTimestamp = DateTime.now().millisecondsSinceEpoch;
      _phase = _Phase.playing;
    });
  }

  void _tapScene(Offset frac) {
    final s = _session!;
    const aspect = 16 / 9;
    for (int i = 0; i < s.hazardRegions.length; i++) {
      if (_found.contains(i)) continue;
      final reg = s.hazardRegions[i];
      final dx = frac.dx - reg.cx;
      final dy = (frac.dy - reg.cy) / aspect;
      if (dx * dx + dy * dy <= reg.r * reg.r) {
        setState(() => _found.add(i));
        if (_found.length == s.hazardRegions.length) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _phase = _Phase.quiz);
          });
        }
        return;
      }
    }
    setState(() {
      _lastMiss = frac;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _lastMiss = null);
    });
  }

  void _answerQuiz(int optionIndex) {
    if (_session == null) return;
    setState(() {
      _quizAnswers[_quizIndex] = optionIndex;
    });
  }

  void _nextQuiz() {
    if (_session == null) return;
    if (_quizIndex < _session!.quizQuestions.length - 1) {
      setState(() => _quizIndex++);
    } else {
      _submitResult();
    }
  }

  Future<void> _submitResult() async {
    final s = _session!;
    final elapsed =
        ((DateTime.now().millisecondsSinceEpoch - _startTimestamp) / 1000)
            .round();
    final correct = _quizAnswers.entries
        .where((e) => s.quizQuestions[e.key].correctIndex == e.value)
        .length;

    setState(() => _loading = true);
    try {
      final res = await gamificationService.submitHazardAttempt(
        learnerId: widget.learnerId,
        sessionId: s.sessionId,
        courseId: widget.courseId,
        hazardsFound: _found.length,
        totalHazards: s.hazardRegions.length,
        quizCorrect: correct,
        quizTotal: s.quizQuestions.length,
        timeTakenSecs: elapsed,
      );
      setState(() {
        _xpEarned = res['xp_earned'] as int;
        _totalXp = res['total_xp'] as int;
        _loading = false;
        _phase = _Phase.result;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _phase = _Phase.result;
      });
    }
  }

  void _nextScenario() {
    if (_sessionIndex < _sessions.length - 1) {
      setState(() {
        _sessionIndex++;
        _phase = _Phase.intro;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _generating) {
      return Scaffold(
        backgroundColor: ArrestoColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _generating
                    ? 'AI is generating hazard scenarios for this course…\nThis may take 30–60 seconds.'
                    : 'Loading…',
                textAlign: TextAlign.center,
                style: ArrestoText.base(color: ArrestoColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: ArrestoColors.background,
        appBar: AppBar(
          backgroundColor: ArrestoColors.surface,
          elevation: 0,
          title: Text('Spot the Hazard',
              style: ArrestoText.base(color: ArrestoColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: ArrestoColors.red),
                const SizedBox(height: 12),
                Text('Something went wrong',
                    style: ArrestoText.lg(color: ArrestoColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        ArrestoText.small(color: ArrestoColors.textMuted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _load,
                  style: FilledButton.styleFrom(
                      backgroundColor: ArrestoColors.amber,
                      foregroundColor: ArrestoColors.ink),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return _NoSessionsView(
        courseTitle: widget.courseTitle,
        onGenerate: _generate,
      );
    }

    final s = _session!;

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      appBar: AppBar(
        backgroundColor: ArrestoColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spot the Hazard',
                style: ArrestoText.base(color: ArrestoColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700)),
            Text(
              'Scenario ${_sessionIndex + 1}/${_sessions.length} · ${s.title}',
              style: ArrestoText.xs(color: ArrestoColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Regenerate',
            onPressed: _generate,
          ),
        ],
      ),
      body: switch (_phase) {
        _Phase.intro => _IntroView(session: s, onStart: _startSession),
        _Phase.playing => _PlayView(
            session: s,
            found: _found,
            lastMiss: _lastMiss,
            onTap: _tapScene,
          ),
        _Phase.quiz => _QuizView(
            session: s,
            quizIndex: _quizIndex,
            answers: _quizAnswers,
            onAnswer: _answerQuiz,
            onNext: _nextQuiz,
          ),
        _Phase.result => _ResultView(
            session: s,
            found: _found.length,
            quizAnswers: _quizAnswers,
            xpEarned: _xpEarned,
            totalXp: _totalXp,
            isLastSession: _sessionIndex >= _sessions.length - 1,
            onNext: _nextScenario,
          ),
      },
    );
  }
}

// ── Intro View ─────────────────────────────────────────────────────────────────

class _IntroView extends StatelessWidget {
  final HazardSession session;
  final VoidCallback onStart;
  const _IntroView({required this.session, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ArrestoColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ArrestoColors.cardBorder),
              boxShadow: ArrestoColors.sh2,
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: ArrestoColors.amberSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search_rounded,
                      size: 32, color: ArrestoColors.amberStrong),
                ),
                const SizedBox(height: 16),
                Text(session.title,
                    style: ArrestoText.xl(color: ArrestoColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(session.sceneDescription,
                    style: ArrestoText.base(color: ArrestoColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip(
                        icon: Icons.warning_amber_rounded,
                        label: '${session.hazardRegions.length} hazards'),
                    _StatChip(
                        icon: Icons.quiz_rounded,
                        label: '${session.quizQuestions.length} questions'),
                    _StatChip(
                        icon: Icons.star_rounded,
                        label: '${session.xpReward} XP'),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: ArrestoColors.amber,
                      foregroundColor: ArrestoColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Start Spotting',
                        style: ArrestoText.base(color: ArrestoColors.ink)
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          if (session.imageUrl == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ArrestoColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ArrestoColors.blue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: ArrestoColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No image generated for this scenario — hazards are shown as interactive markers.',
                      style: ArrestoText.xs(color: ArrestoColors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ArrestoColors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: ArrestoText.xs(color: ArrestoColors.textSecondary)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Play View ─────────────────────────────────────────────────────────────────

class _PlayView extends StatelessWidget {
  final HazardSession session;
  final Set<int> found;
  final Offset? lastMiss;
  final void Function(Offset frac) onTap;

  const _PlayView({
    required this.session,
    required this.found,
    required this.lastMiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = session.hazardRegions.length - found.length;
    return Column(
      children: [
        // Progress bar
        Container(
          color: ArrestoColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('$remaining hazard${remaining == 1 ? '' : 's'} remaining',
                  style: ArrestoText.small(color: ArrestoColors.textSecondary)
                      .copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              ...List.generate(session.hazardRegions.length, (i) {
                return Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: found.contains(i)
                        ? ArrestoColors.green
                        : ArrestoColors.lineStrong,
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: session.imageUrl != null
              ? _PhotoScene(
                  session: session,
                  found: found,
                  lastMiss: lastMiss,
                  onTap: onTap,
                )
              : _DrawnScene(session: session, found: found, onTap: onTap),
        ),
      ],
    );
  }
}

class _PhotoScene extends StatelessWidget {
  final HazardSession session;
  final Set<int> found;
  final Offset? lastMiss;
  final void Function(Offset frac) onTap;

  const _PhotoScene({
    required this.session,
    required this.found,
    required this.lastMiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            return GestureDetector(
              onTapDown: (details) {
                final frac = Offset(
                  details.localPosition.dx / w,
                  details.localPosition.dy / h,
                );
                onTap(frac);
              },
              child: Stack(
                children: [
                  // Background image
                  Positioned.fill(
                    child: Image.network(
                      session.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: ArrestoColors.surface,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: Colors.white54, size: 48),
                        ),
                      ),
                    ),
                  ),
                  // Dark overlay (light)
                  Positioned.fill(
                    child: Container(
                        color: Colors.black.withOpacity(0.15)),
                  ),
                  // Found markers
                  ...List.generate(session.hazardRegions.length, (i) {
                    if (!found.contains(i)) return const SizedBox.shrink();
                    final reg = session.hazardRegions[i];
                    return Positioned(
                      left: reg.cx * w - 20,
                      top: reg.cy * h - 20,
                      child: _FoundMarker(label: reg.label),
                    );
                  }),
                  // Miss flash
                  if (lastMiss != null)
                    Positioned(
                      left: lastMiss!.dx * w - 16,
                      top: lastMiss!.dy * h - 16,
                      child: const _MissMarker(),
                    ),
                  // Hint: tap anywhere label
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Tap on the hazards',
                            style: ArrestoText.xs(color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DrawnScene extends StatelessWidget {
  final HazardSession session;
  final Set<int> found;
  final void Function(Offset frac) onTap;

  const _DrawnScene(
      {required this.session, required this.found, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            return GestureDetector(
              onTapDown: (details) {
                final frac = Offset(
                  details.localPosition.dx / w,
                  details.localPosition.dy / h,
                );
                onTap(frac);
              },
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1B2A3B), Color(0xFF0D1117)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Grid lines hint
                    Positioned.fill(
                      child: CustomPaint(painter: _GridPainter()),
                    ),
                    // Scene description text
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Text(
                        session.sceneDescription,
                        style: ArrestoText.xs(color: Colors.white60),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Hazard markers
                    ...List.generate(session.hazardRegions.length, (i) {
                      final reg = session.hazardRegions[i];
                      final isFound = found.contains(i);
                      return Positioned(
                        left: reg.cx * w - 24,
                        top: reg.cy * h - 24,
                        child: _HazardMarker(
                          found: isFound,
                          label: reg.label,
                        ),
                      );
                    }),
                    // Tap hint
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Tap on the hazard markers',
                              style: ArrestoText.xs(color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
          Offset(size.width * i / 4, 0), Offset(size.width * i / 4, size.height), paint);
      canvas.drawLine(
          Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _HazardMarker extends StatelessWidget {
  final bool found;
  final String label;
  const _HazardMarker({required this.found, required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: found ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: found ? ArrestoColors.green.withOpacity(0.9) : Colors.amber.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: (found ? ArrestoColors.green : Colors.amber).withOpacity(0.5),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(
          found ? Icons.check_rounded : Icons.warning_amber_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _FoundMarker extends StatelessWidget {
  final String label;
  const _FoundMarker({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ArrestoColors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: ArrestoColors.green.withOpacity(0.5), blurRadius: 10),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style:
                  const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _MissMarker extends StatelessWidget {
  const _MissMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: ArrestoColors.red.withOpacity(0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
    );
  }
}

// ── Quiz View ─────────────────────────────────────────────────────────────────

class _QuizView extends StatelessWidget {
  final HazardSession session;
  final int quizIndex;
  final Map<int, int> answers;
  final ValueChanged<int> onAnswer;
  final VoidCallback onNext;

  const _QuizView({
    required this.session,
    required this.quizIndex,
    required this.answers,
    required this.onAnswer,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final q = session.quizQuestions[quizIndex];
    final selected = answers[quizIndex];
    final isAnswered = selected != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Row(
            children: [
              Text(
                'Knowledge Check · ${quizIndex + 1}/${session.quizQuestions.length}',
                style: ArrestoText.small(color: ArrestoColors.textMuted)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ...List.generate(session.quizQuestions.length, (i) {
                Color c = ArrestoColors.lineStrong;
                if (i < quizIndex) c = ArrestoColors.green;
                if (i == quizIndex) c = ArrestoColors.amber;
                return Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: c),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Question
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ArrestoColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ArrestoColors.cardBorder),
              boxShadow: ArrestoColors.sh1,
            ),
            child: Text(q.question,
                style: ArrestoText.lg(color: ArrestoColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600, height: 1.5)),
          ),
          const SizedBox(height: 16),

          // Options
          ...List.generate(q.options.length, (i) {
            final label = String.fromCharCode(65 + i);
            Color bg = ArrestoColors.surface;
            Color border = ArrestoColors.cardBorder;
            Color textColor = ArrestoColors.textPrimary;

            if (isAnswered) {
              if (i == q.correctIndex) {
                bg = ArrestoColors.greenSoft;
                border = ArrestoColors.green;
                textColor = ArrestoColors.green;
              } else if (i == selected) {
                bg = ArrestoColors.redSoft;
                border = ArrestoColors.red;
                textColor = ArrestoColors.red;
              }
            } else if (i == selected) {
              bg = ArrestoColors.amberSoft;
              border = ArrestoColors.amberStrong;
            }

            return GestureDetector(
              onTap: isAnswered ? null : () => onAnswer(i),
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
                        color: (isAnswered && i == q.correctIndex) ||
                                (!isAnswered && i == selected)
                            ? border
                            : ArrestoColors.bg2,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (isAnswered && i == q.correctIndex) ||
                                      (!isAnswered && i == selected)
                                  ? Colors.white
                                  : ArrestoColors.textMuted,
                            )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(q.options[i],
                            style: ArrestoText.base(color: textColor))),
                    if (isAnswered && i == q.correctIndex)
                      const Icon(Icons.check_circle_rounded,
                          color: ArrestoColors.green, size: 18),
                    if (isAnswered && i == selected && i != q.correctIndex)
                      const Icon(Icons.cancel_rounded,
                          color: ArrestoColors.red, size: 18),
                  ],
                ),
              ),
            );
          }),

          // Explanation
          if (isAnswered) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ArrestoColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ArrestoColors.blue),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded,
                      size: 16, color: ArrestoColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(q.explanation,
                        style: ArrestoText.small(color: ArrestoColors.blue)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: ArrestoColors.amber,
                  foregroundColor: ArrestoColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  quizIndex < session.quizQuestions.length - 1
                      ? 'Next Question'
                      : 'See Results',
                  style: ArrestoText.base(color: ArrestoColors.ink)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Result View ───────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final HazardSession session;
  final int found;
  final Map<int, int> quizAnswers;
  final int xpEarned;
  final int totalXp;
  final bool isLastSession;
  final VoidCallback onNext;

  const _ResultView({
    required this.session,
    required this.found,
    required this.quizAnswers,
    required this.xpEarned,
    required this.totalXp,
    required this.isLastSession,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final quizCorrect = quizAnswers.entries
        .where((e) => session.quizQuestions[e.key].correctIndex == e.value)
        .length;
    final total = session.hazardRegions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ArrestoColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ArrestoColors.cardBorder),
              boxShadow: ArrestoColors.sh2,
            ),
            child: Column(
              children: [
                Text('Great Work!',
                    style: ArrestoText.xl(color: ArrestoColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(session.title,
                    style: ArrestoText.base(color: ArrestoColors.textMuted)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ResultStat(
                      label: 'Hazards Found',
                      value: '$found/$total',
                      color: found == total
                          ? ArrestoColors.green
                          : ArrestoColors.amber,
                    ),
                    _ResultStat(
                      label: 'Quiz Score',
                      value: '$quizCorrect/${session.quizQuestions.length}',
                      color: quizCorrect == session.quizQuestions.length
                          ? ArrestoColors.green
                          : ArrestoColors.blue,
                    ),
                    _ResultStat(
                      label: 'XP Earned',
                      value: '+$xpEarned',
                      color: ArrestoColors.amberStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: ArrestoColors.amber,
                      foregroundColor: ArrestoColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isLastSession ? 'Finish' : 'Next Scenario',
                      style: ArrestoText.base(color: ArrestoColors.ink)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Hazard review
          ...List.generate(session.hazardRegions.length, (i) {
            final reg = session.hazardRegions[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ArrestoColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ArrestoColors.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ArrestoColors.greenSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 14, color: ArrestoColors.green),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reg.label,
                            style: ArrestoText.small(color: ArrestoColors.textPrimary)
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(reg.note,
                            style: ArrestoText.xs(
                                color: ArrestoColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ResultStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: ArrestoText.xs(color: ArrestoColors.textMuted)),
      ],
    );
  }
}

// ── No Sessions View ──────────────────────────────────────────────────────────

class _NoSessionsView extends StatelessWidget {
  final String courseTitle;
  final VoidCallback onGenerate;

  const _NoSessionsView(
      {required this.courseTitle, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrestoColors.background,
      appBar: AppBar(
        backgroundColor: ArrestoColors.surface,
        elevation: 0,
        title: Text('Spot the Hazard',
            style: ArrestoText.base(color: ArrestoColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ArrestoColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 36, color: ArrestoColors.amberStrong),
              ),
              const SizedBox(height: 20),
              Text('No Hazard Scenarios Yet',
                  style: ArrestoText.xl(color: ArrestoColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Generate AI-powered hazard scenarios based on the course "$courseTitle".',
                style: ArrestoText.base(color: ArrestoColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate with AI'),
                style: FilledButton.styleFrom(
                  backgroundColor: ArrestoColors.amber,
                  foregroundColor: ArrestoColors.ink,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
