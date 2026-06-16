// ════════════════════════════════════════════════════════════════════════════
//  Interactive Question Overlay  —  STANDALONE handoff copy
// ────────────────────────────────────────────────────────────────────────────
//  A centred modal that appears ON TOP of a (paused) lesson video. Supports four
//  question types and three answer input modes (Choose / Voice / Type), with a
//  blurred dark backdrop and fade + scale entrance/exit animations.
//
//  This copy is SELF-CONTAINED: all colours, text styles and the brand mark are
//  inlined, so it compiles in any Flutter project with ZERO project-specific
//  imports. The only external dependency is the speech_to_text package (for the
//  Voice answer mode); if you don't need voice, see the note in _toggleListen().
//
//  ── INSTALL ──────────────────────────────────────────────────────────────────
//    1. Drop this file anywhere under lib/ (e.g. lib/components/).
//    2. Add to pubspec.yaml:
//         dependencies:
//           speech_to_text: ^7.0.0
//       then run: flutter pub get
//    3. (Web) Voice uses the browser Web Speech API — works on Chrome, Edge,
//       Safari and most mobile browsers. Must be served over https or localhost.
//
//  ── USAGE ────────────────────────────────────────────────────────────────────
//    Place it inside the Stack that sits over your video, toggled by a flag.
//    Pausing the video and resuming it is the parent's job (see callbacks).
//
//    Stack(children: [
//      MyVideoWidget(...),
//      if (showQuestion)
//        InteractiveQuestionOverlay(
//          question: InteractiveQuestion(
//            type: QuestionType.multipleChoice,
//            prompt: "What's the accepted minimum rating for a fall-arrest anchor?",
//            options: ['10 kN', '22 kN', '5 kN', 'Any steel beam'],
//            correctIndex: 1,
//          ),
//          index: 1, total: 1, companionName: 'Aria',
//          onSubmit: (result) {
//            // result.correct / result.answer / result.mode
//            setState(() => showQuestion = false);
//            resumeVideo();
//          },
//          onSkip: () {
//            setState(() => showQuestion = false);
//            resumeVideo();
//          },
//        ),
//    ])
//
//  ── THEMING ──────────────────────────────────────────────────────────────────
//    Tweak the colours in the `_C` class and the styles in `_T` to match your
//    design system. Replace `_BrandLogo` with your own logo widget if desired.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

// ── Inline palette (edit to match your brand) ─────────────────────────────────
class _C {
  static const ink = Color(0xFF1A1A1A);
  static const surface = Color(0xFFFFFFFF);
  static const bg2 = Color(0xFFF4F4F5);
  static const line = Color(0xFFE4E4E7);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF3F3F46);
  static const textMuted = Color(0xFF71717A);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFEF3C7);
  static const orange = Color(0xFFEA580C);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFDCFCE7);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEE2E2);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFDBEAFE);
}

// ── Inline text styles ────────────────────────────────────────────────────────
class _T {
  static TextStyle h3({Color c = _C.textPrimary}) =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c, height: 1.3);
  static TextStyle bodyBold({Color c = _C.textPrimary}) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c);
  static TextStyle body({Color c = _C.textSecondary}) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: c, height: 1.4);
  static TextStyle small({Color c = _C.textMuted}) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c);
  static TextStyle smallBold({Color c = _C.textPrimary}) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c);
  static TextStyle xs({Color c = _C.textMuted}) =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: c);
}

const List<BoxShadow> _sh1 = [
  BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
];

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
  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _dismiss(VoidCallback then) => _anim.reverse().whenComplete(then);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Positioned.fill(
          child: Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8 * _fade.value, sigmaY: 8 * _fade.value),
                child: Container(color: Colors.black.withValues(alpha: 0.55 * _fade.value)),
              ),
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
  bool _revealed = false;

  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false, _listening = false;
  String _transcript = '';
  String? _voiceError;

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
  // If you don't need voice answers, delete this method, the AnswerMode.voice
  // entry in `_modes`, _voiceSection(), the _PulsingMic widget, and the
  // speech_to_text imports.
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
        setState(() =>
            _voiceError = 'Speech recognition isn\'t supported here. Try Chrome, Edge or Safari.');
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
    bool correct = true; // open answers = participation unless gradeable
    if (q.correctIndex != null && q.hasChoices) {
      correct = answer.toLowerCase().contains(q.resolvedOptions[q.correctIndex!].toLowerCase());
    }
    widget.onSubmit(QuestionResult(correct: correct, answer: answer, mode: _mode));
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.of(context).size.height * 0.86),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: maxW < 560 ? 16 : 0),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16)),
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
                    Text(q.prompt, style: _T.h3()),
                    const SizedBox(height: 16),
                    if (_modes.length > 1) _modeSwitcher(),
                    const SizedBox(height: 16),
                    _answerSection(),
                    if (_voiceError != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.error_outline_rounded, size: 15, color: _C.red),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_voiceError!, style: _T.xs(c: _C.red))),
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

  Widget _header() {
    final progress = widget.total > 0 ? widget.index / widget.total : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 14),
      child: Column(children: [
        Row(children: [
          const _BrandLogo(size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Knowledge check', style: _T.bodyBold()),
              Text('${widget.companionName} · let\'s check your understanding', style: _T.xs()),
            ]),
          ),
          Text('${widget.index} / ${widget.total}', style: _T.smallBold(c: _C.textMuted)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: _C.bg2,
            valueColor: const AlwaysStoppedAnimation(_C.amber),
          ),
        ),
      ]),
    );
  }

  Widget _typeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _C.blueSoft, borderRadius: BorderRadius.circular(8)),
      child: Text(q.typeLabel,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.blue)),
    );
  }

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
        color: _C.bg2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.line),
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
                  color: active ? _C.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active ? _sh1 : null,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(iconFor(m), size: 15, color: active ? _C.orange : _C.textMuted),
                  const SizedBox(width: 6),
                  Text(labelFor(m),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? _C.ink : _C.textMuted)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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

        Color bg = _C.surface;
        Color border = _C.line;
        if (_revealed && isCorrect) {
          bg = _C.greenSoft;
          border = _C.green;
        } else if (_revealed && isSelected && !isCorrect) {
          bg = _C.redSoft;
          border = _C.red;
        } else if (isSelected) {
          bg = _C.amberSoft;
          border = _C.amber;
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
              border:
                  Border.all(color: border, width: isSelected || (_revealed && isCorrect) ? 1.5 : 1),
            ),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: isSelected ? _C.ink : _C.bg2),
                alignment: Alignment.center,
                child: Text(letter,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : _C.textMuted)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(q.resolvedOptions[i], style: _T.bodyBold())),
              if (_revealed && isCorrect)
                const Icon(Icons.check_circle_rounded, color: _C.green, size: 20),
              if (_revealed && isSelected && !isCorrect)
                const Icon(Icons.cancel_rounded, color: _C.red, size: 20),
            ]),
          ),
        );
      }),
    );
  }

  Widget _voiceSection() {
    return Column(children: [
      GestureDetector(onTap: _toggleListen, child: _PulsingMic(listening: _listening)),
      const SizedBox(height: 10),
      Text(_listening ? 'Listening… speak your answer' : 'Tap the mic and say your answer',
          style: _T.small(c: _listening ? _C.red : _C.textMuted)),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.line),
        ),
        child: Text(_transcript.isEmpty ? 'Your transcript will appear here…' : _transcript,
            style: _transcript.isEmpty ? _T.small(c: _C.textMuted) : _T.body()),
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
      Text('$len / $_maxChars', style: _T.xs(c: len >= _maxChars ? _C.red : _C.textMuted)),
    ]);
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.line))),
      child: Row(children: [
        TextButton(
          onPressed: widget.onSkip,
          style: TextButton.styleFrom(foregroundColor: _C.textMuted),
          child: const Text('Skip'),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _canSubmit && !_revealed ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: _C.amber,
            foregroundColor: _C.ink,
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
      child: Stack(alignment: Alignment.center, children: [
        if (widget.listening)
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value;
              return Container(
                width: 56 + 32 * t,
                height: 56 + 32 * t,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _C.red.withValues(alpha: (1 - t) * 0.35)),
              );
            },
          ),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.listening ? _C.red : _C.amber,
            boxShadow: [
              BoxShadow(
                  color: (widget.listening ? _C.red : _C.amber).withValues(alpha: 0.4),
                  blurRadius: 18),
            ],
          ),
          child: Icon(widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: widget.listening ? Colors.white : _C.ink, size: 28),
        ),
      ]),
    );
  }
}

// ── Brand mark (amber tile + open book + sparkle) — swap for your own logo ─────
class _BrandLogo extends StatelessWidget {
  final double size;
  const _BrandLogo({this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.amber, _C.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: CustomPaint(painter: _BrandMarkPainter()),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final cx = s * 0.5, sy = s * 0.205, r = s * 0.135, w = s * 0.045;
    final spark = Path()
      ..moveTo(cx, sy - r)
      ..quadraticBezierTo(cx + w, sy - w, cx + r, sy)
      ..quadraticBezierTo(cx + w, sy + w, cx, sy + r)
      ..quadraticBezierTo(cx - w, sy + w, cx - r, sy)
      ..quadraticBezierTo(cx - w, sy - w, cx, sy - r)
      ..close();
    canvas.drawPath(spark, fill);

    final left = Path()
      ..moveTo(s * 0.50, s * 0.45)
      ..lineTo(s * 0.19, s * 0.51)
      ..lineTo(s * 0.19, s * 0.77)
      ..lineTo(s * 0.50, s * 0.71);
    final right = Path()
      ..moveTo(s * 0.50, s * 0.45)
      ..lineTo(s * 0.81, s * 0.51)
      ..lineTo(s * 0.81, s * 0.77)
      ..lineTo(s * 0.50, s * 0.71);
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
    canvas.drawLine(Offset(s * 0.50, s * 0.45), Offset(s * 0.50, s * 0.71), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
