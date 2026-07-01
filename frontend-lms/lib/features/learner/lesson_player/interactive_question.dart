// ════════════════════════════════════════════════════════════════════════════
//  Interactive Question Overlay  —  premium in-video knowledge-check component
// ────────────────────────────────────────────────────────────────────────────
//  A centred modal that appears ON TOP of a (paused) lesson video. Supports four
//  question types and three answer input modes (Choose / Voice / Type), with a
//  blurred dark backdrop and fade + scale entrance/exit animations.
//
//  DEPENDENCIES (already in this project's pubspec.yaml):
//    • speech_to_text: ^7.0.0          ← Voice answers (browser Web Speech API)
//    • ../../../core/theme/colors.dart       (ArrestoColors)
//    • ../../../core/theme/typography.dart    (ArrestoText)
//    • ../../../core/widgets/arresto_ai_logo.dart (ArrestoAiLogo — brand mark)
//
//  USAGE — drop this inside a Stack that sits over your video:
//    Stack(children: [
//      VideoPlayerWidget(...),
//      if (showQuestion)
//        InteractiveQuestionOverlay(
//          question: InteractiveQuestion(
//            type: QuestionType.multipleChoice,
//            prompt: "What's the accepted minimum rating for a fall-arrest anchor?",
//            options: ['10 kN', '22 kN', '5 kN', 'Any steel beam'],
//            correctIndex: 1,
//          ),
//          index: 1, total: 1, companionName: 'Aria',
//          onSubmit: (result) { /* award XP, resume video */ },
//          onSkip:   () { /* resume video */ },
//        ),
//    ])
//
//  The component is fully self-contained: it owns its animation controller and
//  its own speech-recognition instance.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_ai_mascot.dart';

// ── Public model ──────────────────────────────────────────────────────────────
enum QuestionType { multipleChoice, trueFalse, voice, text }

enum AnswerMode { choose, voice, type }

class InteractiveQuestion {
  final QuestionType type;
  final String prompt;

  /// Options for [QuestionType.multipleChoice]. For [QuestionType.trueFalse]
  /// leave empty — `['True', 'False']` is used automatically.
  final List<String> options;

  /// Index into the resolved options that is correct (null = open answer).
  final int? correctIndex;

  const InteractiveQuestion({
    required this.type,
    required this.prompt,
    this.options = const [],
    this.correctIndex,
  });

  List<String> get resolvedOptions =>
      type == QuestionType.trueFalse ? const ['True', 'False'] : options;

  bool get hasChoices => resolvedOptions.isNotEmpty;

  String get typeLabel => switch (type) {
        QuestionType.multipleChoice => 'Multiple choice',
        QuestionType.trueFalse => 'True / False',
        QuestionType.voice => 'Voice answer',
        QuestionType.text => 'Text answer',
      };
}

class QuestionResult {
  final bool correct;
  final String answer;
  final AnswerMode mode;
  const QuestionResult({required this.correct, required this.answer, required this.mode});
}

// ── Overlay (backdrop + animation wrapper) ────────────────────────────────────
class InteractiveQuestionOverlay extends StatefulWidget {
  final InteractiveQuestion question;
  final int index;
  final int total;
  final String companionName;
  final ValueChanged<QuestionResult> onSubmit;
  final VoidCallback onSkip;

  const InteractiveQuestionOverlay({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.onSkip,
    this.index = 1,
    this.total = 1,
    this.companionName = 'Aria',
  });

  @override
  State<InteractiveQuestionOverlay> createState() => _InteractiveQuestionOverlayState();
}

class _InteractiveQuestionOverlayState extends State<InteractiveQuestionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 200),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _anim, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _dismiss(VoidCallback then) {
    _anim.reverse().whenComplete(then);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Positioned.fill(
          child: Stack(
            children: [
              // Blurred dark backdrop
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 8 * _fade.value,
                  sigmaY: 8 * _fade.value,
                ),
                child: Container(color: Colors.black.withValues(alpha: 0.55 * _fade.value)),
              ),
              // Card
              Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: _QuestionCard(
                      question: widget.question,
                      index: widget.index,
                      total: widget.total,
                      companionName: widget.companionName,
                      onSubmit: (r) => _dismiss(() => widget.onSubmit(r)),
                      onSkip: () => _dismiss(widget.onSkip),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── The card itself ───────────────────────────────────────────────────────────
class _QuestionCard extends StatefulWidget {
  final InteractiveQuestion question;
  final int index, total;
  final String companionName;
  final ValueChanged<QuestionResult> onSubmit;
  final VoidCallback onSkip;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.total,
    required this.companionName,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late AnswerMode _mode;
  int? _selected;
  bool _revealed = false; // shows correct/incorrect colours after submit (choose)

  // Voice
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false, _listening = false;
  String _transcript = '';
  String? _voiceError;

  // Type
  final _textCtrl = TextEditingController();
  static const _maxChars = 300;

  InteractiveQuestion get q => widget.question;

  List<AnswerMode> get _modes => [
        if (q.hasChoices) AnswerMode.choose,
        AnswerMode.voice,
        AnswerMode.type,
      ];

  @override
  void initState() {
    super.initState();
    _mode = q.hasChoices ? AnswerMode.choose : AnswerMode.type;
    _textCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _stt.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Voice ──
  Future<void> _toggleListen() async {
    setState(() => _voiceError = null);
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    if (!_sttReady) {
      _sttReady = await _stt.initialize(
        onStatus: (s) {
          if (mounted && (s == 'done' || s == 'notListening')) setState(() => _listening = false);
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _voiceError = e.errorMsg.contains('denied') || e.errorMsg.contains('not-allowed')
                  ? 'Microphone blocked — allow it in your browser settings.'
                  : 'Voice unavailable. Try Chrome, Edge or Safari, or type instead.';
            });
          }
        },
      );
      if (!_sttReady) {
        setState(() => _voiceError =
            'Speech recognition isn\'t supported here. Try Chrome, Edge or Safari.');
        return;
      }
    }
    setState(() {
      _listening = true;
      _transcript = '';
    });
    await _stt.listen(
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      onResult: (SpeechRecognitionResult r) {
        if (mounted) {
          setState(() {
            _transcript = r.recognizedWords;
            if (r.finalResult) _listening = false;
          });
        }
      },
    );
  }

  // ── Submit ──
  bool get _canSubmit => switch (_mode) {
        AnswerMode.choose => _selected != null,
        AnswerMode.voice => _transcript.trim().isNotEmpty,
        AnswerMode.type => _textCtrl.text.trim().isNotEmpty,
      };

  void _submit() {
    if (!_canSubmit) return;

    if (_mode == AnswerMode.choose) {
      final correct = q.correctIndex != null && _selected == q.correctIndex;
      setState(() => _revealed = true);
      // brief reveal of right/wrong before closing
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        widget.onSubmit(QuestionResult(
          correct: correct,
          answer: q.resolvedOptions[_selected!],
          mode: AnswerMode.choose,
        ));
      });
      return;
    }

    final answer = _mode == AnswerMode.voice ? _transcript.trim() : _textCtrl.text.trim();
    bool correct = true; // open answers count as participation unless we can grade
    if (q.correctIndex != null && q.hasChoices) {
      final target = q.resolvedOptions[q.correctIndex!].toLowerCase();
      correct = answer.toLowerCase().contains(target);
    }
    widget.onSubmit(QuestionResult(correct: correct, answer: answer, mode: _mode));
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.of(context).size.height * 0.86),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: maxW < 560 ? 16 : 0),
        decoration: BoxDecoration(
          color: ArrestoColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _typeBadge(),
                    const SizedBox(height: 12),
                    Text(q.prompt, style: ArrestoText.h3()),
                    const SizedBox(height: 16),
                    if (_modes.length > 1) _modeSwitcher(),
                    const SizedBox(height: 16),
                    _answerSection(),
                    if (_voiceError != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.error_outline_rounded, size: 15, color: ArrestoColors.red),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_voiceError!, style: ArrestoText.xs(color: ArrestoColors.red))),
                      ]),
                    ],
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  // ── Header (brand + progress) ──
  Widget _header() {
    final progress = widget.total > 0 ? widget.index / widget.total : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 14),
      child: Column(
        children: [
          Row(children: [
            const ArrestoAiAvatar(size: 38, circle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Knowledge check', style: ArrestoText.bodyBold()),
                Text('${widget.companionName} · let\'s check your understanding', style: ArrestoText.xs()),
              ]),
            ),
            Text('${widget.index} / ${widget.total}', style: ArrestoText.smallBold(color: ArrestoColors.textMuted)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: ArrestoColors.bg2,
              valueColor: const AlwaysStoppedAnimation(ArrestoColors.amber),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: ArrestoColors.blueSoft, borderRadius: BorderRadius.circular(8)),
      child: Text(q.typeLabel,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ArrestoColors.blue)),
    );
  }

  // ── Choose / Voice / Type switcher ──
  Widget _modeSwitcher() {
    IconData iconFor(AnswerMode m) => switch (m) {
          AnswerMode.choose => Icons.format_list_bulleted_rounded,
          AnswerMode.voice => Icons.graphic_eq_rounded,
          AnswerMode.type => Icons.edit_rounded,
        };
    String labelFor(AnswerMode m) => switch (m) {
          AnswerMode.choose => 'Choose',
          AnswerMode.voice => 'Voice',
          AnswerMode.type => 'Type',
        };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ArrestoColors.bg2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ArrestoColors.line),
      ),
      child: Row(
        children: _modes.map((m) {
          final active = m == _mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? ArrestoColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active ? ArrestoColors.sh1 : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconFor(m), size: 15, color: active ? ArrestoColors.orange : ArrestoColors.textMuted),
                    const SizedBox(width: 6),
                    Text(labelFor(m),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? ArrestoColors.ink : ArrestoColors.textMuted,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Answer section per mode ──
  Widget _answerSection() => switch (_mode) {
        AnswerMode.choose => _chooseSection(),
        AnswerMode.voice => _voiceSection(),
        AnswerMode.type => _typeSection(),
      };

  Widget _chooseSection() {
    return Column(
      children: List.generate(q.resolvedOptions.length, (i) {
        final letter = String.fromCharCode(65 + i);
        final isSelected = _selected == i;
        final isCorrect = i == q.correctIndex;

        Color bg = ArrestoColors.surface;
        Color border = ArrestoColors.line;
        if (_revealed && isCorrect) {
          bg = ArrestoColors.greenSoft;
          border = ArrestoColors.green;
        } else if (_revealed && isSelected && !isCorrect) {
          bg = ArrestoColors.redSoft;
          border = ArrestoColors.red;
        } else if (isSelected) {
          bg = ArrestoColors.amberSoft;
          border = ArrestoColors.amber;
        }

        return GestureDetector(
          onTap: _revealed ? null : () => setState(() => _selected = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: isSelected || (_revealed && isCorrect) ? 1.5 : 1),
            ),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? ArrestoColors.ink : ArrestoColors.bg2,
                ),
                alignment: Alignment.center,
                child: Text(letter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : ArrestoColors.textMuted,
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(q.resolvedOptions[i], style: ArrestoText.bodyBold())),
              if (_revealed && isCorrect)
                const Icon(Icons.check_circle_rounded, color: ArrestoColors.green, size: 20),
              if (_revealed && isSelected && !isCorrect)
                const Icon(Icons.cancel_rounded, color: ArrestoColors.red, size: 20),
            ]),
          ),
        );
      }),
    );
  }

  Widget _voiceSection() {
    return Column(children: [
      GestureDetector(
        onTap: _toggleListen,
        child: _PulsingMic(listening: _listening),
      ),
      const SizedBox(height: 10),
      Text(
        _listening ? 'Listening… speak your answer' : 'Tap the mic and say your answer',
        style: ArrestoText.small(color: _listening ? ArrestoColors.red : ArrestoColors.textMuted),
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ArrestoColors.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArrestoColors.line),
        ),
        child: Text(
          _transcript.isEmpty ? 'Your transcript will appear here…' : _transcript,
          style: _transcript.isEmpty
              ? ArrestoText.small(color: ArrestoColors.textMuted)
              : ArrestoText.body(),
        ),
      ),
    ]);
  }

  Widget _typeSection() {
    final len = _textCtrl.text.characters.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      TextField(
        controller: _textCtrl,
        minLines: 3,
        maxLines: 6,
        maxLength: _maxChars,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        decoration: const InputDecoration(
          hintText: 'Type your answer…',
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      const SizedBox(height: 4),
      Text('$len / $_maxChars',
          style: ArrestoText.xs(color: len >= _maxChars ? ArrestoColors.red : ArrestoColors.textMuted)),
    ]);
  }

  // ── Footer (skip + submit) ──
  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ArrestoColors.line)),
      ),
      child: Row(children: [
        TextButton(
          onPressed: widget.onSkip,
          style: TextButton.styleFrom(foregroundColor: ArrestoColors.textMuted),
          child: const Text('Skip'),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _canSubmit && !_revealed ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: ArrestoColors.amber,
            foregroundColor: ArrestoColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          child: const Text('Submit answer'),
        ),
      ]),
    );
  }
}

// ── Pulsing microphone button ─────────────────────────────────────────────────
class _PulsingMic extends StatefulWidget {
  final bool listening;
  const _PulsingMic({required this.listening});

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.listening)
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = _c.value;
                return Container(
                  width: 56 + 32 * t,
                  height: 56 + 32 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ArrestoColors.red.withValues(alpha: (1 - t) * 0.35),
                  ),
                );
              },
            ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.listening ? ArrestoColors.red : ArrestoColors.amber,
              boxShadow: [
                BoxShadow(
                  color: (widget.listening ? ArrestoColors.red : ArrestoColors.amber).withValues(alpha: 0.4),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(
              widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: widget.listening ? Colors.white : ArrestoColors.ink,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
