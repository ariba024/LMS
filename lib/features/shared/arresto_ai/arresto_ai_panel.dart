import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_ai_logo.dart';

/// Context about the lesson the learner is currently watching, passed into the
/// AI companion so it can answer about *this* lesson and the current section.
class AiLessonContext {
  final String lessonId;
  final String courseId;
  final String lessonTitle;
  final int timestampSecs;
  final String? transcript;

  const AiLessonContext({
    required this.lessonId,
    required this.courseId,
    required this.lessonTitle,
    required this.timestampSecs,
    this.transcript,
  });

  String get timestampLabel {
    final m = timestampSecs ~/ 60;
    final s = timestampSecs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

enum _Voice { idle, listening, processing, speaking }

class ArrestoAIPanel extends StatefulWidget {
  final String? seedQuestion;
  final AiLessonContext? lessonContext;
  const ArrestoAIPanel({super.key, this.seedQuestion, this.lessonContext});

  @override
  State<ArrestoAIPanel> createState() => _ArrestoAIPanelState();
}

class _ArrestoAIPanelState extends State<ArrestoAIPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  bool _typing = false;

  // ── Voice: speech-to-text ──
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  bool _sttDenied = false;
  bool _listening = false;
  String? _voiceError;

  // ── Voice: text-to-speech ──
  final FlutterTts _tts = FlutterTts();
  int? _speakingIndex;
  bool _paused = false;

  bool get _speaking => _speakingIndex != null && !_paused;

  _Voice get _voiceState {
    if (_listening) return _Voice.listening;
    if (_typing) return _Voice.processing;
    if (_speaking) return _Voice.speaking;
    return _Voice.idle;
  }

  @override
  void initState() {
    super.initState();
    _initTts();
    _initStt();
    if (widget.seedQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _send(widget.seedQuestion!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }

  void _track(String event) {
    final ctx = widget.lessonContext;
    debugPrint('[analytics] ai_companion:$event '
        'lesson=${ctx?.lessonId ?? "-"} course=${ctx?.courseId ?? "-"} '
        't=${ctx?.timestampSecs ?? "-"}');
  }

  // ── Speech-to-text setup ────────────────────────────────────────────────────
  Future<void> _initStt() async {
    try {
      _sttReady = await _stt.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _sttDenied = err.errorMsg.contains('denied') ||
                err.errorMsg.contains('not-allowed') ||
                err.errorMsg.contains('permission');
            _voiceError = _friendlyMicError(err.errorMsg);
          });
        },
      );
    } catch (_) {
      _sttReady = false;
    }
    if (mounted) setState(() {});
  }

  String _friendlyMicError(String raw) {
    if (raw.contains('denied') || raw.contains('not-allowed') || raw.contains('permission')) {
      return 'Microphone access is blocked. Allow it in your browser\'s site settings, then retry.';
    }
    if (raw.contains('network')) return 'Network issue reaching speech service. Check your connection.';
    if (raw.contains('no-speech') || raw.contains('noMatch')) return 'Didn\'t catch that — try speaking again.';
    return 'Voice input isn\'t available right now. You can still type.';
  }

  Future<void> _toggleListen() async {
    _clearVoiceError();
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    // (Re)initialise if a prior attempt failed (e.g. user just granted access).
    if (!_sttReady) await _initStt();
    if (!_sttReady) {
      setState(() => _voiceError =
          'Speech recognition isn\'t supported in this browser. Try Chrome, Edge, or Safari.');
      return;
    }
    // Stop any TTS so the two don't fight over the audio session.
    await _stopSpeak();
    _track('voice_listen_start');
    setState(() => _listening = true);
    await _stt.listen(
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      onResult: (SpeechRecognitionResult r) {
        if (!mounted) return;
        setState(() => _controller.text = r.recognizedWords);
        if (r.finalResult) {
          final text = r.recognizedWords.trim();
          setState(() => _listening = false);
          if (text.isNotEmpty) {
            _track('voice_listen_result');
            _send(text);
            _controller.clear();
          }
        }
      },
    );
  }

  void _clearVoiceError() {
    if (_voiceError != null) setState(() => _voiceError = null);
  }

  // ── Text-to-speech setup ────────────────────────────────────────────────────
  Future<void> _initTts() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() { _speakingIndex = null; _paused = false; });
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() { _speakingIndex = null; _paused = false; });
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() { _speakingIndex = null; _paused = false; });
    });
  }

  String _stripForSpeech(String md) => md
      .replaceAll('**', '')
      .replaceAll(RegExp(r'[•✨📍📝①②③④⑤]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _speak(int index) async {
    if (_listening) await _stt.stop();
    await _tts.stop();
    _track('voice_speak');
    setState(() { _speakingIndex = index; _paused = false; });
    await _tts.speak(_stripForSpeech(_messages[index].text));
  }

  Future<void> _pauseResume(int index) async {
    if (_paused) {
      // flutter_tts has no native resume; restart this message from the top.
      setState(() => _paused = false);
      await _tts.speak(_stripForSpeech(_messages[index].text));
    } else {
      await _tts.pause();
      setState(() => _paused = true);
    }
  }

  Future<void> _stopSpeak() async {
    await _tts.stop();
    if (mounted) setState(() { _speakingIndex = null; _paused = false; });
  }

  // ── Chat ──────────────────────────────────────────────────────────────────
  void _send(String text) async {
    if (text.trim().isEmpty) return;
    _track('ask');
    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _typing = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _typing = false;
      _messages.add(_Message(text: _mockResponse(text), isUser: false));
    });
    _scrollToBottom();
  }

  String _mockResponse(String q) {
    final lc = widget.lessonContext;
    final lower = q.toLowerCase();
    final title = lc?.lessonTitle ?? 'this lesson';

    if (lower.contains('summarize') || lower.contains('summary')) {
      return 'Here\'s a summary of "$title":\n\n'
          '• Fall protection is required at 6 ft (construction) / 4 ft (general industry).\n'
          '• Anchor points must support at least 5,000 lbs (22 kN) per worker.\n'
          '• Always inspect equipment — webbing, D-rings, buckles, stitching — before each use.\n'
          '• Calculate total fall clearance to avoid hitting a lower level.';
    }
    if (lower.contains('explain') && lc != null) {
      return 'At ${lc.timestampLabel} in "$title", the focus is on connecting your '
          'lanyard correctly. The key point: verify your anchor point is rated for '
          'at least 22 kN before clipping in, and keep the connection above your '
          'dorsal D-ring to minimise free-fall distance.';
    }
    if (lower.contains('quiz') || lower.contains('generate')) {
      return 'Here are 3 practice questions on "$title":\n\n'
          '1. What is the minimum anchor rating for a personal fall arrest system?\n'
          '2. Name three things to check when inspecting a harness.\n'
          '3. What is the maximum permitted free-fall distance under OSHA?\n\n'
          'Want the answers, or to take the full graded quiz?';
    }
    if (lower.contains('anchor')) {
      return 'Anchor points for personal fall arrest systems must support a minimum of 5,000 lbs (22 kN) per attached worker, or be designed and tested by a qualified person under a supervised fall arrest system.';
    }
    if (lower.contains('inspect') || lower.contains('harness')) {
      return 'Before each use, inspect your harness for: ① Cut, frayed, or worn webbing ② Damaged stitching ③ Corroded or bent hardware ④ Damaged D-rings ⑤ Deformed buckles. Remove from service if any defects are found.';
    }
    if (lower.contains('free-fall') || lower.contains('6-foot')) {
      return 'The 6-foot (1.8 m) free-fall rule means your fall arrest system must stop a fall within 6 feet of where you started falling. This limits forces on your body and ensures adequate clearance above the lower level.';
    }
    return 'That\'s a great question about fall protection! Based on the course material, the key principles are: always use certified equipment, inspect before each use, and ensure your system has adequate clearance below your working position. Would you like more detail on any specific aspect?';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: ArrestoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: ArrestoColors.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: ArrestoColors.ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const ArrestoAiLogo(size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arresto AI', style: ArrestoText.h4(color: Colors.white)),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: ArrestoColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                                widget.lessonContext != null
                                    ? 'On: ${widget.lessonContext!.lessonTitle}'
                                    : 'Online — Fall Protection Expert',
                                overflow: TextOverflow.ellipsis,
                                style: ArrestoText.xs(color: Colors.white54)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(onChip: _send, lessonContext: widget.lessonContext)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_typing ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) return const _TypingIndicator();
                      final msg = _messages[i];
                      return _MessageBubble(
                        msg: msg,
                        canSpeak: !msg.isUser,
                        isSpeaking: _speakingIndex == i && !_paused,
                        isPaused: _speakingIndex == i && _paused,
                        onSpeak: () => _speak(i),
                        onPauseResume: () => _pauseResume(i),
                        onStop: _stopSpeak,
                      );
                    },
                  ),
          ),
          // Voice status / error
          if (_voiceError != null)
            _VoiceErrorBar(message: _voiceError!, onRetry: _toggleListen, onDismiss: _clearVoiceError)
          else if (_voiceState != _Voice.idle)
            _VoiceStatusBar(state: _voiceState),
          // Input + voice controls
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: ArrestoColors.line)),
            ),
            child: Row(
              children: [
                _MicButton(
                  listening: _listening,
                  disabled: _sttDenied,
                  onTap: _toggleListen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask Arresto AI, or tap the mic…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (v) {
                      _send(v);
                      _controller.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _send(_controller.text);
                    _controller.clear();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: ArrestoColors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, size: 18, color: ArrestoColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Microphone button with pulse-while-listening ──────────────────────────────
class _MicButton extends StatefulWidget {
  final bool listening;
  final bool disabled;
  final VoidCallback onTap;
  const _MicButton({required this.listening, required this.disabled, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.listening;
    return Tooltip(
      message: widget.disabled
          ? 'Microphone blocked — enable it in site settings'
          : listening
              ? 'Stop listening'
              : 'Speak your question',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (listening)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) {
                    final t = _pulse.value;
                    return Container(
                      width: 28 + 16 * t,
                      height: 28 + 16 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ArrestoColors.red.withValues(alpha: (1 - t) * 0.35),
                      ),
                    );
                  },
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.disabled
                      ? ArrestoColors.bg2
                      : listening
                          ? ArrestoColors.red
                          : ArrestoColors.bg2,
                  border: Border.all(
                      color: listening ? ArrestoColors.red : ArrestoColors.line),
                ),
                child: Icon(
                  widget.disabled
                      ? Icons.mic_off_rounded
                      : listening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                  size: 20,
                  color: listening ? Colors.white : ArrestoColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Voice status pill ─────────────────────────────────────────────────────────
class _VoiceStatusBar extends StatelessWidget {
  final _Voice state;
  const _VoiceStatusBar({required this.state});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final IconData icon;
    late final Color color;
    switch (state) {
      case _Voice.listening:
        label = 'Listening…';
        icon = Icons.mic_rounded;
        color = ArrestoColors.red;
        break;
      case _Voice.processing:
        label = 'Processing…';
        icon = Icons.bubble_chart_rounded;
        color = ArrestoColors.orange;
        break;
      case _Voice.speaking:
        label = 'Speaking…';
        icon = Icons.volume_up_rounded;
        color = ArrestoColors.green;
        break;
      case _Voice.idle:
        label = '';
        icon = Icons.circle;
        color = ArrestoColors.textMuted;
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: ArrestoText.small(color: color).copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _VoiceErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry, onDismiss;
  const _VoiceErrorBar({required this.message, required this.onRetry, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: ArrestoColors.redSoft,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: ArrestoColors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: ArrestoText.xs(color: ArrestoColors.red))),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
            child: Text('Retry', style: ArrestoText.xs(color: ArrestoColors.red).copyWith(fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded, size: 16, color: ArrestoColors.red),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onChip;
  final AiLessonContext? lessonContext;
  const _EmptyState({required this.onChip, this.lessonContext});

  static const _generic = [
    'What is the minimum anchor strength?',
    'How do I inspect a full-body harness?',
    'Explain the 6-foot free-fall rule.',
  ];

  @override
  Widget build(BuildContext context) {
    final lc = lessonContext;
    final suggestions = lc != null
        ? [
            '✨ Summarize this lesson',
            '📍 Explain current section (${lc.timestampLabel})',
            '📝 Generate quiz questions',
          ]
        : _generic;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ArrestoAiLogo(size: 56),
            const SizedBox(height: 12),
            Text(
                lc != null
                    ? 'Ask me about "${lc.lessonTitle}"'
                    : 'Ask me anything about fall protection',
                style: ArrestoText.bodyMd(color: ArrestoColors.ink),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Type or tap the mic to talk',
                style: ArrestoText.xs(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((s) {
                return GestureDetector(
                  onTap: () => onChip(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ArrestoColors.bg2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ArrestoColors.line),
                    ),
                    child: Text(s, style: ArrestoText.small().copyWith(fontWeight: FontWeight.w500)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat bubble (with per-message voice controls for AI replies) ──────────────
class _MessageBubble extends StatelessWidget {
  final _Message msg;
  final bool canSpeak, isSpeaking, isPaused;
  final VoidCallback onSpeak, onPauseResume, onStop;

  const _MessageBubble({
    required this.msg,
    required this.canSpeak,
    required this.isSpeaking,
    required this.isPaused,
    required this.onSpeak,
    required this.onPauseResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final active = isSpeaking || isPaused;
    return Column(
      crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!msg.isUser) ...[
              const ArrestoAiLogo(size: 28),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                decoration: BoxDecoration(
                  color: msg.isUser ? ArrestoColors.amber : ArrestoColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                    bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                  ),
                  border: msg.isUser ? null : Border.all(color: ArrestoColors.cardBorder),
                  boxShadow: msg.isUser ? null : ArrestoColors.sh1,
                ),
                child: Text(
                  msg.text,
                  style: ArrestoText.body(
                    color: msg.isUser ? ArrestoColors.ink : ArrestoColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Voice controls under AI replies
        if (canSpeak)
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 10),
            child: Row(
              children: [
                if (!active)
                  _voiceChip(Icons.volume_up_rounded, 'Listen', onSpeak)
                else ...[
                  _voiceChip(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      isPaused ? 'Resume' : 'Pause', onPauseResume),
                  const SizedBox(width: 6),
                  _voiceChip(Icons.stop_rounded, 'Stop', onStop),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _voiceChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ArrestoColors.bg2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ArrestoColors.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: ArrestoColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: ArrestoText.xs()),
        ]),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
        ..repeat(reverse: true);
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) c.forward();
      });
      _controllers.add(c);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ArrestoAiLogo(size: 28),
        const SizedBox(width: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ArrestoColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ArrestoColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _controllers[i],
                builder: (_, __) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: ArrestoColors.textMuted
                        .withValues(alpha: 0.3 + 0.7 * _controllers[i].value),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  const _Message({required this.text, required this.isUser});
}
