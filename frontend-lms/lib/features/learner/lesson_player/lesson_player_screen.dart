// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/button.dart';
import '../../../core/services/tutor_service.dart';
import '../../../data/providers/api_providers.dart';
import '../../../data/models/lesson.dart' show CourseLesson;

// ── Note model ────────────────────────────────────────────────────────────────
class _Note {
  final String timestamp;
  final String text;
  _Note(this.timestamp, this.text);
}

// ── Lesson player screen ──────────────────────────────────────────────────────
class LessonPlayerScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;
  const LessonPlayerScreen(
      {super.key, required this.courseId, required this.lessonId});

  @override
  ConsumerState<LessonPlayerScreen> createState() =>
      _LessonPlayerScreenState();
}

class _LessonPlayerScreenState
    extends ConsumerState<LessonPlayerScreen> {
  // ── Audio ──────────────────────────────────────────────────────────────────
  html.AudioElement? _audio;
  bool _isPlaying = false;
  double _position = 0;
  double _duration = 0;
  String? _initedForLesson; // guard against re-init on same lesson

  // ── Tutor session ──────────────────────────────────────────────────────────
  String? _sessionId;
  bool _sessionLoading = false;

  // ── Checkpoint quiz ───────────────────────────────────────────────────────
  bool _checkpointLoading = false;

  // ── UI state ───────────────────────────────────────────────────────────────
  String _activeTab = 'Notes';
  final _noteCtrl = TextEditingController();
  final List<_Note> _notes = [];
  int _xp = 120;

  @override
  void dispose() {
    _audio?.pause();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Audio helpers ──────────────────────────────────────────────────────────

  void _initAudio(CourseLesson lesson) {
    if (_initedForLesson == lesson.id) return;
    _initedForLesson = lesson.id;

    final moduleNum = CourseLesson.moduleNumFromId(lesson.id);
    final lessonNum = CourseLesson.lessonNumFromId(lesson.id);
    final url =
        TutorService.audioUrl(widget.courseId, moduleNum, lessonNum);

    _audio?.pause();
    _audio = html.AudioElement();
    _audio!.src = url;
    _audio!.preload = 'metadata';

    _audio!.onLoadedMetadata.listen((_) {
      if (!mounted) return;
      final d = (_audio!.duration as num).toDouble();
      setState(() => _duration = d.isNaN || d.isInfinite ? 0 : d);
    });
    _audio!.onTimeUpdate.listen((_) {
      if (!mounted) return;
      setState(() => _position = (_audio!.currentTime as num).toDouble());
    });
    _audio!.onEnded.listen((_) {
      if (!mounted) return;
      setState(() { _isPlaying = false; });
    });
    _audio!.onError.listen((_) {
      if (!mounted) return;
      setState(() { _isPlaying = false; });
    });
  }

  void _togglePlay() {
    if (_audio == null) return;
    if (_isPlaying) {
      _audio!.pause();
    } else {
      _audio!.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _seekTo(double fraction) {
    if (_audio == null || _duration == 0) return;
    _audio!.currentTime = fraction.clamp(0.0, 1.0) * _duration;
  }

  // ── Tutor session helpers ──────────────────────────────────────────────────

  Future<void> _ensureSession(CourseLesson lesson) async {
    if (_sessionId != null || _sessionLoading) return;
    // Check if there's already a session for this course
    final sessionMap = ref.read(tutorSessionMapProvider);
    if (sessionMap.containsKey(widget.courseId)) {
      setState(() => _sessionId = sessionMap[widget.courseId]);
      return;
    }
    setState(() => _sessionLoading = true);
    try {
      final learnerId = ref.read(learnerIdProvider);
      final session = await TutorService.createSession(
        scriptId: widget.courseId,
        learnerId: learnerId,
        startModule: CourseLesson.moduleNumFromId(lesson.id),
        startLesson: CourseLesson.lessonNumFromId(lesson.id),
      );
      if (!mounted) return;
      ref.read(tutorSessionMapProvider.notifier).update(
            (m) => {...m, widget.courseId: session.sessionId},
          );
      setState(() {
        _sessionId = session.sessionId;
        _sessionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sessionLoading = false);
    }
  }

  // ── UI actions ─────────────────────────────────────────────────────────────

  void _openAiChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TutorChatSheet(
        sessionId: _sessionId,
        lessonTitle: '',
      ),
    );
  }

  Future<void> _markComplete(BuildContext context) async {
    if (_checkpointLoading) return;
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tutor session not ready — wait a moment and try again.')));
      return;
    }
    setState(() => _checkpointLoading = true);
    try {
      final questions =
          await TutorService.completeLessonCheckpoint(_sessionId!);
      setState(() { _checkpointLoading = false; _xp += 20; });
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CheckpointSheet(
          sessionId: _sessionId!,
          questions: questions,
          onComplete: (earnedXp) => setState(() => _xp += earnedXp),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkpointLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkpoint error: $e')));
    }
  }

  String _fmtSecs(double secs) {
    final s = secs.toInt();
    final m = s ~/ 60;
    final rem = s % 60;
    return '${m.toString().padLeft(1, '0')}:${rem.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(courseLessonsProvider(widget.courseId));

    return lessonsAsync.when(
      loading: () => Column(children: [
          _buildTopBar(context, null, null),
          const Expanded(child: Center(
            child: CircularProgressIndicator(color: ArrestoColors.orange),
          )),
        ]),
      error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: ArrestoColors.textMuted2, size: 48),
            const SizedBox(height: 12),
            Text('Could not load lesson', style: ArrestoText.bodyMd()),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.invalidate(courseLessonsProvider(widget.courseId)),
              child: const Text('Retry'),
            ),
          ]),
        ),
      data: (lessons) {
        final lesson = lessons.firstWhere(
          (l) => l.id == widget.lessonId,
          orElse: () => lessons.isNotEmpty ? lessons.first
              : CourseLesson(
                  id: widget.lessonId,
                  courseId: widget.courseId,
                  module: '',
                  moduleNum: 1,
                  title: 'Lesson',
                  durationSecs: 0),
        );

        // Initialize audio and tutor session once per lesson
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initAudio(lesson);
          _ensureSession(lesson);
        });

        final lessonIndex = lessons.indexWhere((l) => l.id == widget.lessonId);
        final hasPrev = lessonIndex > 0;
        final hasNext = lessonIndex < lessons.length - 1;
        final progress =
            _duration > 0 ? (_position / _duration).clamp(0.0, 1.0) : 0.0;
        final isWide = MediaQuery.of(context).size.width > 900;

        return Column(children: [
            _buildTopBar(context, lesson, lessons),
            Expanded(
              child: isWide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: _buildLeftPanel(
                          context, lesson, lessons, lessonIndex,
                          hasPrev, hasNext, progress,
                        ),
                      ),
                      SizedBox(
                        width: 300,
                        child: _buildRightSidebar(context, lesson, lessons,
                            lessonIndex, progress),
                      ),
                    ])
                  : SingleChildScrollView(
                      child: Column(children: [
                        _buildAudioBox(progress),
                        _buildRightSidebar(context, lesson, lessons,
                            lessonIndex, progress),
                      ]),
                    ),
            ),
          ]);
      },
    );
  }

  // ── Top breadcrumb bar ─────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, CourseLesson? lesson,
      List<CourseLesson>? lessons) {
    return Container(
      color: ArrestoColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        TextButton.icon(
          onPressed: () =>
              context.go('/learner/course/${widget.courseId}'),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text('Back to course', style: ArrestoText.bodyMd()),
          style: TextButton.styleFrom(foregroundColor: ArrestoColors.ink),
        ),
        if (lesson != null) ...[
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: ArrestoColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lesson.title,
              style: ArrestoText.bodySm(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (_sessionLoading)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  color: ArrestoColors.orange, strokeWidth: 2),
            ),
          ),
      ]),
    );
  }

  // ── Left panel ─────────────────────────────────────────────────────────────

  Widget _buildLeftPanel(
    BuildContext context,
    CourseLesson lesson,
    List<CourseLesson> lessons,
    int lessonIndex,
    bool hasPrev,
    bool hasNext,
    double progress,
  ) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Lesson header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${lesson.module} · Lesson ${lessonIndex + 1} of ${lessons.length}',
              style: ArrestoText.small(),
            ),
            const SizedBox(height: 2),
            Text(lesson.title, style: ArrestoText.h2()),
          ]),
        ),

        // Audio player
        _buildAudioBox(progress),

        // Controls row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            ArrestoButton(
              label: 'Prev',
              variant: ArrestoButtonVariant.ghost,
              size: ArrestoButtonSize.sm,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: hasPrev
                  ? () {
                      _audio?.pause();
                      context.go('/learner/lesson/${widget.courseId}/${lessons[lessonIndex - 1].id}');
                    }
                  : null,
            ),
            const Spacer(),
            ArrestoButton(
              label: _checkpointLoading ? 'Loading…' : 'Mark Complete',
              size: ArrestoButtonSize.sm,
              variant: ArrestoButtonVariant.ghost,
              icon: const Icon(Icons.check_circle_outline_rounded),
              onPressed: _checkpointLoading
                  ? null
                  : () => _markComplete(context),
            ),
            const SizedBox(width: 8),
            ArrestoButton(
              label: 'Next lesson',
              size: ArrestoButtonSize.sm,
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: hasNext
                  ? () {
                      _audio?.pause();
                      context.go('/learner/lesson/${widget.courseId}/${lessons[lessonIndex + 1].id}');
                    }
                  : null,
            ),
          ]),
        ),

        const Divider(height: 1),

        // Tabs
        _buildTabBar(lesson),

        const Divider(height: 1),

        // Tab content
        Padding(
          padding: const EdgeInsets.all(20),
          child: _buildTabContent(lesson),
        ),

        // Lesson list
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.list_rounded, size: 18, color: ArrestoColors.orange),
              const SizedBox(width: 8),
              Text('All lessons', style: ArrestoText.h3()),
            ]),
            const SizedBox(height: 12),
            ...lessons
                .where((l) => l.id != lesson.id)
                .take(4)
                .map((l) => _LessonRow(
                      lesson: l,
                      onTap: () {
                        _audio?.pause();
                        context.go('/learner/lesson/${widget.courseId}/${l.id}');
                      },
                    )),
          ]),
        ),
      ]),
    );
  }

  // ── Audio player visual ────────────────────────────────────────────────────

  Widget _buildAudioBox(double progress) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: const Color(0xFF111111),
        child: Stack(children: [
          // Gradient backdrop
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1a1a1a), Color(0xFF0d0d0d)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Center play button
          if (!_isPlaying)
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: ArrestoColors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: ArrestoColors.amber.withValues(alpha: 0.4),
                          blurRadius: 24)
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: ArrestoColors.ink, size: 40),
                ),
              ),
            ),

          // Playing indicator (top-right pause button)
          if (_isPlaying)
            Positioned(
              right: 16, top: 16,
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pause_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),

          // Audio label
          if (_duration == 0)
            Positioned(
              top: 16, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Audio narration • Loading…',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xDD000000), Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
              child: Column(children: [
                // Seek bar
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: ArrestoColors.amber,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: ArrestoColors.amber,
                    overlayColor:
                        ArrestoColors.amber.withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) => _seekTo(v),
                  ),
                ),
                // Controls row
                Row(children: [
                  _ctrl(Icons.replay_10_rounded, () {
                    if (_audio != null) {
                      _audio!.currentTime =
                          ((_audio!.currentTime as num).toDouble() - 10).clamp(0.0, _duration);
                    }
                  }),
                  _ctrl(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    _togglePlay,
                  ),
                  _ctrl(Icons.forward_10_rounded, () {
                    if (_audio != null) {
                      _audio!.currentTime =
                          ((_audio!.currentTime as num).toDouble() + 10).clamp(0.0, _duration);
                    }
                  }),
                  const SizedBox(width: 6),
                  Text(
                    '${_fmtSecs(_position)} / ${_duration > 0 ? _fmtSecs(_duration) : '--:--'}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.volume_up_rounded,
                          color: Colors.white70, size: 14),
                      SizedBox(width: 4),
                      Text('Audio',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _ctrl(IconData icon, VoidCallback onTap) => IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
      );

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _buildTabBar(CourseLesson lesson) {
    return Row(
      children: ['Notes', 'Transcript', 'Resources'].map((tab) {
        final active = tab == _activeTab;
        return GestureDetector(
          onTap: () => setState(() => _activeTab = tab),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active
                      ? ArrestoColors.orange
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                tab,
                style: active
                    ? ArrestoText.bodyBold(color: ArrestoColors.orange)
                    : ArrestoText.body(),
              ),
              if (tab == 'Notes' && _notes.isNotEmpty) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: ArrestoColors.orange,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('${_notes.length}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabContent(CourseLesson lesson) {
    if (_activeTab == 'Notes') return _buildNotesTab();
    if (_activeTab == 'Transcript') return _buildTranscriptTab(lesson);
    return _buildResourcesTab();
  }

  // ── Notes tab ──────────────────────────────────────────────────────────────

  Widget _buildNotesTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 4,
            decoration:
                const InputDecoration(hintText: 'Write a note…'),
          ),
        ),
        const SizedBox(width: 10),
        ArrestoButton(
          label: 'Add note',
          size: ArrestoButtonSize.sm,
          onPressed: () {
            final text = _noteCtrl.text.trim();
            if (text.isEmpty) return;
            final s = _position.toInt();
            final m = s ~/ 60;
            final sec = s % 60;
            final ts =
                '${m.toString().padLeft(1, '0')}:${sec.toString().padLeft(2, '0')}';
            setState(() => _notes.add(_Note(ts, text)));
            _noteCtrl.clear();
          },
        ),
      ]),
      const SizedBox(height: 12),
      if (_notes.isEmpty)
        Text('No notes yet. Add one above!', style: ArrestoText.small())
      else
        ..._notes.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ArrestoColors.amberSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: ArrestoColors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: ArrestoColors.amber,
                      borderRadius: BorderRadius.circular(6)),
                  child:
                      Text(e.value.timestamp, style: ArrestoText.xs()),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(e.value.text, style: ArrestoText.body())),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 15, color: ArrestoColors.textMuted),
                  onPressed: () =>
                      setState(() => _notes.removeAt(e.key)),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ]),
            )),
    ]);
  }

  // ── Transcript tab ─────────────────────────────────────────────────────────

  Widget _buildTranscriptTab(CourseLesson lesson) {
    final script = lesson.narrationScript;
    if (script == null || script.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transcript — ${lesson.title}',
              style: ArrestoText.bodyBold()),
          const SizedBox(height: 12),
          Text(
            'Audio narration transcript will appear here once the lesson audio has been generated.',
            style: ArrestoText.body(color: ArrestoColors.textMuted),
          ),
        ],
      );
    }

    // Split narration script into readable paragraphs
    final paragraphs = script
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transcript — ${lesson.title}',
            style: ArrestoText.bodyBold()),
        const SizedBox(height: 12),
        ...paragraphs.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(p, style: ArrestoText.body()),
            )),
      ],
    );
  }

  // ── Resources tab ──────────────────────────────────────────────────────────

  Widget _buildResourcesTab() {
    final docsAsync =
        ref.watch(documentsApiProvider);
    return docsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ArrestoColors.orange),
      ),
      error: (e, _) => Text(
        'Could not load resources: $e',
        style: ArrestoText.small(color: ArrestoColors.red),
      ),
      data: (docs) {
        if (docs.isEmpty) {
          return Text(
            'No knowledge-base documents uploaded yet.',
            style: ArrestoText.body(color: ArrestoColors.textMuted),
          );
        }
        return Column(
          children: docs.take(6).map((doc) {
            final isPdf = doc.ext == 'PDF';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ArrestoColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ArrestoColors.line),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPdf
                        ? ArrestoColors.redSoft
                        : ArrestoColors.greenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.description_rounded,
                      size: 18,
                      color: isPdf
                          ? ArrestoColors.red
                          : ArrestoColors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(doc.displayName,
                        style: ArrestoText.bodyBold(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${doc.ext} · ${doc.chunkCount} chunks',
                        style: ArrestoText.xs()),
                  ]),
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Right sidebar ──────────────────────────────────────────────────────────

  Widget _buildRightSidebar(
    BuildContext context,
    CourseLesson lesson,
    List<CourseLesson> lessons,
    int lessonIndex,
    double progress,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Learning companion card
        ArrestoCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ArrestoColors.amberSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    color: ArrestoColors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Learning companion',
                    style: ArrestoText.bodyBold()),
                Text('Powered by Arresto AI', style: ArrestoText.xs()),
              ]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.play_arrow_rounded,
                  size: 14, color: ArrestoColors.orange),
              const SizedBox(width: 4),
              Text('NOW PLAYING', style: ArrestoText.eyebrow()),
            ]),
            Text(lesson.title,
                style: ArrestoText.bodyBold(),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            _progressRow('Lesson progress', progress, ArrestoColors.amber),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(children: [
                Text('$_xp',
                    style: ArrestoText.stat()
                        .copyWith(color: ArrestoColors.orange)),
                Text('XP', style: ArrestoText.xs()),
              ])),
              Expanded(child: Column(children: [
                Text('${lessons.length}', style: ArrestoText.stat()),
                Text('Lessons', style: ArrestoText.xs()),
              ])),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ArrestoButton(
                label: _sessionId != null
                    ? 'Ask Arresto AI'
                    : (_sessionLoading ? 'Connecting…' : 'Ask Arresto AI'),
                variant: ArrestoButtonVariant.dark,
                icon: const Icon(Icons.smart_toy_rounded),
                onPressed:
                    () => _openAiChat(context),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Course progress
        ArrestoCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Course progress', style: ArrestoText.bodyBold()),
            const SizedBox(height: 4),
            Text(
              'Lesson ${lessonIndex + 1} of ${lessons.length}',
              style: ArrestoText.xs(),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: lessons.isEmpty ? 0 : (lessonIndex + 1) / lessons.length,
                backgroundColor: ArrestoColors.amberSoft,
                valueColor:
                    const AlwaysStoppedAnimation(ArrestoColors.amber),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            ...lessons.take(8).map((l) {
              final isActive = l.id == lesson.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: isActive
                      ? null
                      : () {
                          _audio?.pause();
                          context.go(
                              '/learner/lesson/${widget.courseId}/${l.id}');
                        },
                  child: Row(children: [
                    Icon(
                      l.completed
                          ? Icons.check_circle_rounded
                          : (isActive
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded),
                      size: 16,
                      color: l.completed
                          ? ArrestoColors.green
                          : (isActive
                              ? ArrestoColors.orange
                              : ArrestoColors.textMuted2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.title,
                        style: isActive
                            ? ArrestoText.bodyBold(
                                color: ArrestoColors.orange)
                            : ArrestoText.body(
                                color: ArrestoColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _progressRow(String label, double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: ArrestoText.small()),
        const Spacer(),
        Text('${(value * 100).round()}%',
            style: ArrestoText.smallBold()),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

// ── Lesson row in sidebar ─────────────────────────────────────────────────────
class _LessonRow extends StatelessWidget {
  final CourseLesson lesson;
  final VoidCallback onTap;
  const _LessonRow({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ArrestoColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ArrestoColors.line),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: ArrestoColors.amberSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_circle_outline_rounded,
                size: 16, color: ArrestoColors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(lesson.title,
                  style: ArrestoText.bodyBold(),
                  overflow: TextOverflow.ellipsis),
              Text('${lesson.module}', style: ArrestoText.xs()),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: ArrestoColors.textMuted),
        ]),
      ),
    );
  }
}

// ── Tutor chat bottom sheet ───────────────────────────────────────────────────
class _TutorChatSheet extends ConsumerStatefulWidget {
  final String? sessionId;
  final String lessonTitle;
  const _TutorChatSheet(
      {required this.sessionId, required this.lessonTitle});

  @override
  ConsumerState<_TutorChatSheet> createState() => _TutorChatSheetState();
}

class _TutorChatSheetState extends ConsumerState<_TutorChatSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = false;

  final List<({String text, bool isAi})> _messages = [
    (
      text:
          'Hi! I\'m Arresto AI, your learning companion. Ask me anything about this lesson.',
      isAi: true,
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() {
      _messages.add((text: msg, isAi: false));
      _loading = true;
    });
    _scrollToBottom();
    try {
      final String reply;
      if (widget.sessionId != null) {
        reply = await TutorService.chat(widget.sessionId!, msg);
      } else {
        // No session yet — fallback to general chat
        final chatService =
            await Future.value('Session not ready. Please wait a moment and try again.');
        reply = chatService;
      }
      if (!mounted) return;
      setState(() {
        _messages.add((text: reply, isAi: true));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add((
          text: 'Sorry, I couldn\'t connect right now. Please try again.',
          isAi: true,
        ));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: ArrestoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: ArrestoColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ArrestoColors.amberSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: ArrestoColors.orange, size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arresto AI', style: ArrestoText.bodyBold()),
              Text('Lesson tutor', style: ArrestoText.xs()),
            ]),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    SizedBox(width: 12),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ArrestoColors.orange),
                    ),
                    SizedBox(width: 8),
                    Text('Thinking…',
                        style: TextStyle(
                            color: ArrestoColors.textMuted,
                            fontSize: 12)),
                  ]),
                );
              }
              final m = _messages[i];
              return Align(
                alignment: m.isAi
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: m.isAi
                        ? ArrestoColors.bg2
                        : ArrestoColors.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    m.text,
                    style: ArrestoText.body(
                        color: m.isAi
                            ? ArrestoColors.ink
                            : Colors.white),
                  ),
                ),
              );
            },
          ),
        ),

        // Input
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'Ask about this lesson…',
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(999))),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: ArrestoColors.orange,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
                onPressed: _send,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Checkpoint quiz bottom sheet ───────────────────────────────────────────────
class _CheckpointSheet extends StatefulWidget {
  final String sessionId;
  final List<TutorQuizQuestion> questions;
  final void Function(int xp) onComplete;
  const _CheckpointSheet({
    required this.sessionId,
    required this.questions,
    required this.onComplete,
  });

  @override
  State<_CheckpointSheet> createState() => _CheckpointSheetState();
}

class _CheckpointSheetState extends State<_CheckpointSheet> {
  int _currentIdx = 0;
  final Map<String, String> _answers = {};
  final Map<String, ({bool correct, String correctAnswer, String explanation})>
      _results = {};
  bool _submitting = false;

  TutorQuizQuestion get _current =>
      widget.questions[_currentIdx];

  Future<void> _selectAnswer(String key) async {
    if (_answers.containsKey(_current.questionId)) return;
    _answers[_current.questionId] = key;
    setState(() => _submitting = true);
    try {
      final result = await TutorService.submitAnswer(
          widget.sessionId, _current.questionId, key);
      if (!mounted) return;
      _results[_current.questionId] = (
        correct: result.correct,
        correctAnswer: result.correctAnswer,
        explanation: result.explanation,
      );
      setState(() => _submitting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  void _next() {
    if (_currentIdx < widget.questions.length - 1) {
      setState(() => _currentIdx++);
    } else {
      final correct = _results.values.where((r) => r.correct).length;
      widget.onComplete(correct * 10);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _current;
    final answered = _answers.containsKey(q.questionId);
    final result = _results[q.questionId];
    final opts = q.options.entries.toList();

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: ArrestoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ArrestoColors.amberSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: ArrestoColors.orange, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lesson Checkpoint', style: ArrestoText.bodyBold()),
            Text(
                'Question ${_currentIdx + 1} of ${widget.questions.length}',
                style: ArrestoText.xs()),
          ]),
        ]),
        const SizedBox(height: 16),
        Text(q.question, style: ArrestoText.h3()),
        const SizedBox(height: 12),
        ...opts.map((opt) {
          final selected = _answers[q.questionId] == opt.key;
          final isCorrect = result?.correctAnswer == opt.key;
          Color bg = ArrestoColors.surface;
          Color border = ArrestoColors.line;
          if (answered) {
            if (selected && result?.correct == true) {
              bg = ArrestoColors.greenSoft;
              border = ArrestoColors.green;
            } else if (selected && result?.correct == false) {
              bg = ArrestoColors.redSoft;
              border = ArrestoColors.red;
            } else if (isCorrect) {
              bg = ArrestoColors.greenSoft;
              border = ArrestoColors.green;
            }
          }
          return GestureDetector(
            onTap: answered || _submitting
                ? null
                : () => _selectAnswer(opt.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? ArrestoColors.ink
                        : ArrestoColors.bg2,
                  ),
                  alignment: Alignment.center,
                  child: Text(opt.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : ArrestoColors.textMuted,
                      )),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(opt.value,
                        style: ArrestoText.bodyBold())),
              ]),
            ),
          );
        }),
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
            child: Text(
              result.explanation,
              style: ArrestoText.body(
                  color: result.correct
                      ? ArrestoColors.green
                      : ArrestoColors.red),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (answered)
          SizedBox(
            width: double.infinity,
            child: ArrestoButton(
              label: _currentIdx < widget.questions.length - 1
                  ? 'Next Question'
                  : 'Complete Lesson ✓',
              onPressed: _next,
            ),
          ),
      ]),
    );
  }
}
