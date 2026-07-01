import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/course_service.dart';
import '../../../core/services/video_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/chip_group.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/course_thumb.dart';
import '../../../core/widgets/arresto_ai_mascot.dart';
import '../../../data/providers/api_providers.dart';

class CourseGeneratorWizard extends ConsumerStatefulWidget {
  const CourseGeneratorWizard({super.key});

  @override
  ConsumerState<CourseGeneratorWizard> createState() =>
      _CourseGeneratorWizardState();
}

class _CourseGeneratorWizardState
    extends ConsumerState<CourseGeneratorWizard> {
  int _step = 0;

  // Step 0: Requirements
  final _titleCtrl        = TextEditingController();
  final _topicCtrl        = TextEditingController();
  final _descCtrl         = TextEditingController();
  final _objectivesCtrl   = TextEditingController();
  final _userInstructCtrl = TextEditingController();
  String _audience       = 'Construction workers';
  String _difficulty     = 'Beginner';
  String _courseLength   = '60-90 minutes';

  // Step 1: Sources
  String? _selectedDoc;

  // Step 4: Style — video render style id
  String _videoStyle = 'modern';

  // Step 5: Language
  String _language = 'English';

  // Step 6: Voices
  String _transcriptVoice = 'ritu';
  String _videoVoice = 'ritu';

  // Course script output
  Map<String, dynamic>? _courseScript;
  String? _scriptId;

  // Language display name → BCP-47 code
  static const _langCode = {
    'English':   'en',
    'Hindi':     'hi',
  };

  // Step 8: Publish settings (lifted so the bottom-bar button can read them)
  String _publishModeName   = 'Publish Now';
  bool   _notifyLearners    = true;
  bool   _requireCompletion = true;
  String _assignTo          = 'all';
  String _assignLabel       = 'All Active Learners';
  bool   _publishing        = false;
  bool   _published         = false;
  bool   _videoQueued       = false;

  String get _publishModeApi => switch (_publishModeName) {
        'Save as Draft' => 'draft',
        'Schedule'      => 'scheduled',
        _               => 'now',
      };

  Future<void> _publishCourse() async {
    if (_scriptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate the course script first (Step 4).')),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      await CourseService.publishCourse(
        _scriptId!,
        publishMode:       _publishModeApi,
        notifyLearners:    _notifyLearners,
        requireCompletion: _requireCompletion,
        assignTo:          _assignTo,
      );
      if (!mounted) return;
      setState(() { _published = true; _publishing = false; });

      // Queue video generation for all lessons (fire-and-forget)
      // Skipped when user chose 'No Video' — they can generate later from the course page.
      if (_publishModeApi != 'draft' && _videoStyle != 'none') {
        final langCode = _langCode[_language] ?? 'en';
        VideoService.generateAll(_scriptId!, style: _videoStyle, lang: langCode, voice: _videoVoice)
            .then((count) {
          if (!mounted) return;
          setState(() => _videoQueued = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video generation started for $count lesson(s) — style: $_videoStyle, lang: $langCode'),
              duration: const Duration(seconds: 5),
            ),
          );
        }).catchError((Object e) {
          debugPrint('[VideoGen] failed to queue: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Course published, but video generation failed: $e')),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _topicCtrl.dispose();
    _descCtrl.dispose();
    _objectivesCtrl.dispose();
    _userInstructCtrl.dispose();
    super.dispose();
  }

  static const _steps = [
    'Requirements',
    'Sources',
    'Packs',
    'Script',
    'Style',
    'Language',
    'Review',
    'Assessment',
    'Publish',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Stepper header (glass) ──
          _glassBar(
            border: const Border(
                bottom: BorderSide(color: ArrestoColors.cardBorder)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ArrestoColors.amber, ArrestoColors.orange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                ArrestoColors.amber.withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 20, color: Color(0xFF1B1B1D)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Course Generator',
                              style: ArrestoText.h3().copyWith(fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(
                              'Create AI-powered interactive safety training in minutes',
                              style:
                                  ArrestoText.xs(color: ArrestoColors.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ArrestoColors.amberSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color:
                                ArrestoColors.amber.withValues(alpha: 0.35)),
                      ),
                      child: Text('Step ${_step + 1} of ${_steps.length}',
                          style: ArrestoText.xs(color: ArrestoColors.amber)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedArrestoProgressBar(
                  value: (_step + 1) / _steps.length,
                  tone: ProgressTone.orange,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 58,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _steps.length,
                    itemBuilder: (ctx, i) => _StepPill(
                      index: i,
                      label: _steps[i],
                      done: i < _step,
                      active: i == _step,
                      onTap: () => setState(() => _step = i),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Step content (centered, generous whitespace) ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: _step == 0 ? 1180 : 960),
                  child: _buildStep(_step),
                ),
              ),
            ),
          ),

          // ── Navigation (glass) ──
          _glassBar(
            border:
                const Border(top: BorderSide(color: ArrestoColors.cardBorder)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                if (_step == 0) ...[
                  ArrestoButton(
                    label: 'Save Draft',
                    variant: ArrestoButtonVariant.ghost,
                    icon: const Icon(Icons.bookmark_border_rounded),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Draft kept for this session.')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ArrestoButton(
                    label: 'Preview',
                    variant: ArrestoButtonVariant.ghost,
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _step = _steps.length - 3),
                  ),
                ] else if (_step > 0)
                  ArrestoButton(
                    label: 'Back',
                    variant: ArrestoButtonVariant.ghost,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _step--),
                  ),
                const Spacer(),
                if (_step < _steps.length - 1)
                  _GradientButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => setState(() => _step++),
                  )
                else
                  _GradientButton(
                    label: _videoQueued
                        ? 'Published · Videos queued!'
                        : _published
                            ? 'Published!'
                            : _publishing
                                ? 'Publishing…'
                                : 'Publish Course',
                    icon: _published
                        ? Icons.check_circle_rounded
                        : Icons.rocket_launch_rounded,
                    loading: _publishing,
                    onPressed:
                        (_publishing || _published) ? null : _publishCourse,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Translucent bar used for the stepper header and nav footer. Uses a solid
  /// translucent fill (no live BackdropFilter) so it stays cheap even with the
  /// animated backdrop and the shell's own glass header/sidebar already blurring.
  Widget _glassBar({
    required Widget child,
    Border? border,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ArrestoColors.surface.withValues(alpha: 0.82),
        border: border,
      ),
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1008),
          child: child,
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    return switch (step) {
      0 => _StepRequirements(
          titleCtrl: _titleCtrl,
          topicCtrl: _topicCtrl,
          descCtrl: _descCtrl,
          objectivesCtrl: _objectivesCtrl,
          userInstructCtrl: _userInstructCtrl,
          audience: _audience,
          onAudienceChanged: (v) {
            if (v != null) setState(() => _audience = v);
          },
          difficulty: _difficulty,
          onDifficultyChanged: (v) => setState(() => _difficulty = v),
          courseLength: _courseLength,
          onCourseLengthChanged: (v) => setState(() => _courseLength = v),
          language: _language,
          onLanguageChanged: (v) => setState(() => _language = v),
        ),
      1 => _StepSources(
          selectedDoc: _selectedDoc,
          onSelect: (v) => setState(() => _selectedDoc = v),
        ),
      2 => _StepPacks(),
      3 => _StepScript(
          selectedDoc: _selectedDoc,
          titleCtrl: _titleCtrl,
          topicCtrl: _topicCtrl,
          descCtrl: _descCtrl,
          objectivesCtrl: _objectivesCtrl,
          userInstructCtrl: _userInstructCtrl,
          audience: _audience,
          difficulty: _difficulty,
          courseLength: _courseLength,
          language: _language,
          onComplete: (script) => setState(() => _courseScript = script),
          onScriptId: (id) => setState(() { _scriptId = id; _published = false; }),
        ),
      4 => _StepStyle(
          initialStyle: _videoStyle,
          onStyleChanged: (s) => setState(() => _videoStyle = s),
        ),
      5 => _StepLanguage(
          language: _language,
          onLanguageChanged: (v) => setState(() => _language = v),
          transcriptVoice: _transcriptVoice,
          onTranscriptVoiceChanged: (v) => setState(() => _transcriptVoice = v),
          videoVoice: _videoVoice,
          onVideoVoiceChanged: (v) => setState(() => _videoVoice = v),
        ),
      6 => _StepReview(
          title: _titleCtrl.text,
          audience: _audience,
          difficulty: _difficulty,
          courseLength: _courseLength,
          language: _language,
          videoStyle: _videoStyle,
          transcriptVoice: _transcriptVoice,
          videoVoice: _videoVoice,
          courseScript: _courseScript,
          scriptId: _scriptId,
        ),
      7 => _StepAssessment(scriptId: _scriptId),
      8 => _StepPublish(
          scriptId: _scriptId,
          modeName: _publishModeName,
          notifyLearners: _notifyLearners,
          requireCompletion: _requireCompletion,
          assignLabel: _assignLabel,
          onModeChanged: (v) => setState(() => _publishModeName = v),
          onNotifyChanged: (v) => setState(() => _notifyLearners = v),
          onRequireChanged: (v) => setState(() => _requireCompletion = v),
          onAssignChanged: (label, apiValue) => setState(() {
            _assignLabel = label;
            _assignTo = apiValue;
          }),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ── Stepper pill ──────────────────────────────────────────────────────────────

class _StepPill extends StatelessWidget {
  final int index;
  final String label;
  final bool done;
  final bool active;
  final VoidCallback onTap;
  const _StepPill({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final circleColor = done
        ? ArrestoColors.green
        : active
            ? ArrestoColors.orange
            : ArrestoColors.bg2;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? ArrestoColors.amberSoft
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? ArrestoColors.amber.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            if (index > 0)
              Container(
                width: 14,
                height: 2,
                margin: const EdgeInsets.only(right: 8),
                color: (done || active)
                    ? ArrestoColors.orange
                    : ArrestoColors.line,
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: ArrestoColors.orange.withValues(alpha: 0.4),
                          blurRadius: 10,
                        )
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : Text('${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            active ? Colors.white : ArrestoColors.textMuted,
                      )),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? ArrestoColors.amber
                    : done
                        ? ArrestoColors.green
                        : ArrestoColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Primary gradient button (the wizard's focal CTA) ────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  const _GradientButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.loading = false,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: _hover && enabled
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [ArrestoColors.amber, ArrestoColors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : ArrestoColors.bg2,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: ArrestoColors.amber
                        .withValues(alpha: _hover ? 0.45 : 0.28),
                    blurRadius: _hover ? 24 : 16,
                    spreadRadius: _hover ? 1 : 0,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.loading)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1B1B1D)),
                    )
                  else
                    Icon(widget.icon,
                        size: 17,
                        color: enabled
                            ? const Color(0xFF1B1B1D)
                            : ArrestoColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? const Color(0xFF1B1B1D)
                          : ArrestoColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 1: Requirements ──────────────────────────────────────────────────────

class _StepRequirements extends StatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController topicCtrl;
  final TextEditingController descCtrl;
  final TextEditingController objectivesCtrl;
  final TextEditingController userInstructCtrl;
  final String audience;
  final ValueChanged<String?> onAudienceChanged;
  final String difficulty;
  final ValueChanged<String> onDifficultyChanged;
  final String courseLength;
  final ValueChanged<String> onCourseLengthChanged;
  final String language;
  final ValueChanged<String> onLanguageChanged;

  const _StepRequirements({
    required this.titleCtrl,
    required this.topicCtrl,
    required this.descCtrl,
    required this.objectivesCtrl,
    required this.userInstructCtrl,
    required this.audience,
    required this.onAudienceChanged,
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.courseLength,
    required this.onCourseLengthChanged,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  State<_StepRequirements> createState() => _StepRequirementsState();
}

class _StepRequirementsState extends State<_StepRequirements> {
  @override
  void initState() {
    super.initState();
    // Live-echo the course name/topic/objectives into the preview panel as the
    // user types (purely local UI state — no app state/logic changes).
    widget.titleCtrl.addListener(_onChange);
    widget.topicCtrl.addListener(_onChange);
    widget.objectivesCtrl.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    widget.titleCtrl.removeListener(_onChange);
    widget.topicCtrl.removeListener(_onChange);
    widget.objectivesCtrl.removeListener(_onChange);
    super.dispose();
  }

  void _suggestObjectives() {
    final topic = widget.topicCtrl.text.trim();
    final subject = topic.isEmpty ? 'this topic' : topic;
    final text = '• Identify key hazards related to $subject.\n'
        '• Apply correct safety procedures and use of PPE.\n'
        '• Respond appropriately to ${widget.audience.toLowerCase()} scenarios.\n'
        '• Demonstrate compliance with relevant safety standards.';
    widget.objectivesCtrl.text = text;
    widget.objectivesCtrl.selection =
        TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final form = _buildForm();
    final panel = _LiveAiPanel(
      courseName: widget.titleCtrl.text.trim(),
      difficulty: widget.difficulty,
      language: widget.language,
      courseLength: widget.courseLength,
    );

    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth >= 880;
      if (!wide) {
        return Column(children: [form, const SizedBox(height: 16), panel]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: form),
          const SizedBox(width: 18),
          Expanded(flex: 3, child: panel),
        ],
      );
    });
  }

  Widget _buildForm() {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.description_rounded,
            title: 'Course Requirements',
            subtitle: 'Define what you want to teach',
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBlock(
                  label: 'Course Name',
                  child: _GlassField(
                    controller: widget.titleCtrl,
                    icon: Icons.title_rounded,
                    hint: 'e.g. Working at Heights — Foundation',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _FieldBlock(
                  label: 'Topic',
                  child: _GlassField(
                    controller: widget.topicCtrl,
                    icon: Icons.track_changes_rounded,
                    hint: 'e.g. Fall protection principles',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldBlock(
            label: 'Description',
            child: _GlassField(
              controller: widget.descCtrl,
              icon: Icons.notes_rounded,
              hint: 'Describe the course focus and key themes...',
              minLines: 3,
              maxLines: 5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBlock(
                  label: 'Target Audience',
                  child: _PremiumDropdown(
                    value: widget.audience,
                    icon: Icons.groups_rounded,
                    items: const [
                      'Construction workers',
                      'Site supervisors',
                      'Safety officers',
                      'All workers',
                    ],
                    onChanged: widget.onAudienceChanged,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _FieldBlock(
                  label: 'Difficulty',
                  child: _SegmentedDifficulty(
                    selected: widget.difficulty,
                    onChanged: widget.onDifficultyChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Learning Objectives — AI smart editor ──
          _FieldBlock(
            label: 'Learning Objectives',
            trailing: _AiChip(label: 'Generate', onTap: _suggestObjectives),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _GlassField(
                  controller: widget.objectivesCtrl,
                  icon: Icons.checklist_rounded,
                  hint:
                      'List what learners will be able to do after this course...',
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.objectivesCtrl.text.length} characters · tap ✨ Generate for AI suggestions',
                  style: ArrestoText.xs(color: ArrestoColors.textMuted2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBlock(
                  label: 'Course Length',
                  child: _PremiumDropdown(
                    value: widget.courseLength,
                    icon: Icons.schedule_rounded,
                    items: const [
                      '15-20 minutes',
                      '30-45 minutes',
                      '60-90 minutes',
                      '2-3 hours',
                      '3+ hours',
                    ],
                    onChanged: (v) {
                      if (v != null) widget.onCourseLengthChanged(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _FieldBlock(
                  label: 'Course Language',
                  child: _PremiumDropdown(
                    value: widget.language,
                    icon: Icons.translate_rounded,
                    items: const ['English', 'Hindi'],
                    onChanged: (v) {
                      if (v != null) widget.onLanguageChanged(v);
                    },
                  ),
                ),
              ),
            ],
          ),

          // ── Generation Instructions ──
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ArrestoColors.orangeTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: ArrestoColors.orange.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 16, color: ArrestoColors.orange),
                    const SizedBox(width: 6),
                    Text('Generation Instructions',
                        style: ArrestoText.label()
                            .copyWith(color: ArrestoColors.orange)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Type exactly how you want the course generated. '
                  'The AI will follow these strictly — language, topics, structure, tone, anything.',
                  style: ArrestoText.xs(color: ArrestoColors.textMuted),
                ),
                const SizedBox(height: 12),
                _GlassField(
                  controller: widget.userInstructCtrl,
                  icon: Icons.edit_note_rounded,
                  hint:
                      'e.g. Generate the entire course in Hindi. Cover topics in this order: '
                      '1. Legal framework  2. Hazard identification  3. PPE use. '
                      'Include 3 quiz questions after each module.',
                  minLines: 5,
                  maxLines: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Premium form building blocks ────────────────────────────────────────────

class _FieldBlock extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;
  const _FieldBlock({required this.label, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: ArrestoText.label()),
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _GlassField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int minLines;
  final int? maxLines;
  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  final FocusNode _fn = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _fn.addListener(() => setState(() => _focused = _fn.hasFocus));
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines == null || widget.maxLines! > 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: multiline ? 12 : 3),
      decoration: BoxDecoration(
        color: ArrestoColors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? ArrestoColors.amber : ArrestoColors.cardBorder,
          width: 1.4,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: ArrestoColors.amber.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: multiline ? 10 : 0, right: 10),
            child: Icon(widget.icon,
                size: 17,
                color: _focused ? ArrestoColors.amber : ArrestoColors.textMuted),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _fn,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              style: const TextStyle(
                  fontSize: 14, color: Colors.white, height: 1.5),
              cursorColor: ArrestoColors.amber,
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                    color: ArrestoColors.textMuted2, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  const _PremiumDropdown({
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: ArrestoColors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArrestoColors.cardBorder, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: ArrestoColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(14),
                dropdownColor: ArrestoColors.surfaceSoft,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: ArrestoColors.textMuted),
                style: const TextStyle(
                    fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                items: items
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedDifficulty extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _SegmentedDifficulty(
      {required this.selected, required this.onChanged});

  static const _opts = [
    ('Beginner', Icons.eco_rounded),
    ('Intermediate', Icons.trending_up_rounded),
    ('Advanced', Icons.bolt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ArrestoColors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArrestoColors.cardBorder, width: 1.4),
      ),
      child: Row(
        children: [
          for (final o in _opts)
            Expanded(
              child: _SegItem(
                label: o.$1,
                icon: o.$2,
                active: selected == o.$1,
                onTap: () => onChanged(o.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _SegItem(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: active ? 1.0 : 0.97,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [ArrestoColors.amber, ArrestoColors.orange])
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ArrestoColors.amber.withValues(alpha: 0.35),
                      blurRadius: 12,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: active
                      ? const Color(0xFF1B1B1D)
                      : ArrestoColors.textMuted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? const Color(0xFF1B1B1D)
                        : ArrestoColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AiChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ArrestoColors.amberSoft,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: ArrestoColors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 12, color: ArrestoColors.amber),
            const SizedBox(width: 4),
            Text(label,
                style: ArrestoText.xs(color: ArrestoColors.amber)
                    .copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Live AI Preview panel ─────────────────────────────────────────────────────

({String duration, int modules, int assessments, int media}) _estimate(
    String len) {
  switch (len) {
    case '15-20 minutes':
      return (duration: '18m', modules: 2, assessments: 3, media: 6);
    case '30-45 minutes':
      return (duration: '42m', modules: 4, assessments: 6, media: 12);
    case '2-3 hours':
      return (duration: '2h 30m', modules: 9, assessments: 18, media: 28);
    case '3+ hours':
      return (duration: '3h 45m', modules: 12, assessments: 24, media: 40);
    case '60-90 minutes':
    default:
      return (duration: '1h 20m', modules: 6, assessments: 12, media: 18);
  }
}

class _LiveAiPanel extends StatelessWidget {
  final String courseName;
  final String difficulty;
  final String language;
  final String courseLength;
  const _LiveAiPanel({
    required this.courseName,
    required this.difficulty,
    required this.language,
    required this.courseLength,
  });

  @override
  Widget build(BuildContext context) {
    final est = _estimate(courseLength);
    return Column(
      children: [
        ArrestoCard(
          glow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Course Blueprint', style: ArrestoText.h4()),
                        Text('Live preview',
                            style: ArrestoText.xs(
                                color: ArrestoColors.textMuted)),
                      ],
                    ),
                  ),
                  const _PulseDot(),
                ],
              ),
              const SizedBox(height: 14),
              const _BlueprintGraphic(),
              const SizedBox(height: 14),
              Text(
                courseName.isEmpty ? 'Untitled course' : courseName,
                style: ArrestoText.bodyBold(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _PreviewStat(
                  icon: Icons.schedule_rounded,
                  label: 'Estimated Duration',
                  value: est.duration),
              _PreviewStat(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: 'Difficulty',
                  value: difficulty),
              _PreviewStat(
                  icon: Icons.widgets_rounded,
                  label: 'Modules',
                  value: '${est.modules}'),
              _PreviewStat(
                  icon: Icons.quiz_rounded,
                  label: 'Assessments',
                  value: '${est.assessments}'),
              _PreviewStat(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Media Elements',
                  value: '${est.media}'),
              _PreviewStat(
                  icon: Icons.translate_rounded,
                  label: 'Language',
                  value: language),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('AI Confidence Score',
                      style: ArrestoText.xs(color: ArrestoColors.textMuted)),
                  const Spacer(),
                  Text('92%',
                      style: ArrestoText.smallBold(color: ArrestoColors.green)),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedArrestoProgressBar(
                  value: 0.92, tone: ProgressTone.green, height: 6),
              const SizedBox(height: 4),
              Text('High quality course expected',
                  style: ArrestoText.xs(color: ArrestoColors.green)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _DockedAssistant(),
      ],
    );
  }
}

class _BlueprintGraphic extends StatelessWidget {
  const _BlueprintGraphic();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          radius: 0.9,
          colors: [Color(0xFF14202E), Color(0xFF0E1116)],
        ),
        border: Border.all(color: ArrestoColors.cardBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: ArrestoColors.blue.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 4),
              ],
            ),
          ),
          Icon(Icons.hexagon_outlined,
              size: 62, color: ArrestoColors.blue.withValues(alpha: 0.9)),
          const Icon(Icons.auto_awesome_rounded,
              size: 24, color: Colors.white),
        ],
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PreviewStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: ArrestoColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: ArrestoColors.amber),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: ArrestoText.small(color: ArrestoColors.textSecondary))),
          Text(value, style: ArrestoText.smallBold()),
        ],
      ),
    );
  }
}

class _DockedAssistant extends StatelessWidget {
  const _DockedAssistant();

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ArrestoAiAvatar(size: 38, circle: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arresto AI', style: ArrestoText.bodyBold()),
                    Row(
                      children: [
                        const _PulseDot(),
                        const SizedBox(width: 5),
                        Text('Ready · your course co-pilot',
                            style: ArrestoText.xs(
                                color: ArrestoColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ArrestoColors.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ArrestoColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_rounded,
                    size: 15, color: ArrestoColors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: a clear topic + audience produces the sharpest, most compliant course.',
                    style: ArrestoText.xs(color: ArrestoColors.textSecondary),
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

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: ArrestoColors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ArrestoColors.green.withValues(alpha: 0.15 + 0.45 * t),
                blurRadius: 4 + 6 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Step 2: Sources ───────────────────────────────────────────────────────────

class _StepSources extends ConsumerWidget {
  final String? selectedDoc;
  final ValueChanged<String> onSelect;

  const _StepSources({this.selectedDoc, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsApiProvider);

    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.upload_file_rounded,
            title: 'Source Documents',
            subtitle: 'Pick a document from the knowledge base to build from',
          ),
          const SizedBox(height: 16),

          // Upload zone (UI only — upload via Admin → Settings)
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: ArrestoColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ArrestoColors.lineStrong),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_rounded,
                      size: 24, color: ArrestoColors.textMuted2),
                  const SizedBox(height: 4),
                  Text('Upload new files via Admin → Settings',
                      style: ArrestoText.small()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Knowledge Base Documents', style: ArrestoText.label()),
          const SizedBox(height: 8),

          docsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child:
                    CircularProgressIndicator(color: ArrestoColors.orange),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: ArrestoColors.textMuted2, size: 32),
                  const SizedBox(height: 8),
                  Text('Could not load documents',
                      style: ArrestoText.small()),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(documentsApiProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (docs) {
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      const Icon(Icons.folder_open_rounded,
                          color: ArrestoColors.textMuted2, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'No documents in the knowledge base yet.\nUpload files via Admin → Settings.',
                        style: ArrestoText.small(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final isSelected = selectedDoc == doc.sourceFile;
                  return GestureDetector(
                    onTap: () => onSelect(doc.sourceFile),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ArrestoColors.amberSoft
                            : ArrestoColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? ArrestoColors.amber
                              : ArrestoColors.line,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: ArrestoColors.redSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              doc.ext,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ArrestoColors.red),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc.displayName,
                                    style: ArrestoText.bodyBold(),
                                    overflow: TextOverflow.ellipsis),
                                Text('${doc.chunkCount} chunks',
                                    style: ArrestoText.xs()),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: ArrestoColors.amber, size: 20)
                          else
                            const Icon(Icons.radio_button_unchecked_rounded,
                                color: ArrestoColors.textMuted2, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          if (selectedDoc != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: ArrestoColors.green, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Selected: ${selectedDoc!.split('/').last.split('\\').last}',
                  style: ArrestoText.small(color: ArrestoColors.green),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Step 3: Packs ─────────────────────────────────────────────────────────────

class _StepPacks extends StatelessWidget {
  static const _packs = [
    ('AS/NZS Standards', 'Australian & NZ safety standards', 42,
        Icons.book_rounded, ArrestoColors.blue),
    ('WorkSafe Guidelines', 'Workplace health & safety guidelines', 28,
        Icons.security_rounded, ArrestoColors.green),
    ('OSHA Library', 'US occupational safety standards', 87,
        Icons.account_balance_rounded, ArrestoColors.orange),
    ('ISO Documents', 'International safety standards', 34,
        Icons.public_rounded, ArrestoColors.amber),
    ('Arresto Internal', 'Company-specific procedures', 16,
        Icons.business_rounded, ArrestoColors.red),
    ('Training Videos', 'Reference training materials', 22,
        Icons.video_library_rounded, ArrestoColors.blue),
  ];

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.library_books_rounded,
            title: 'Knowledge Packs',
            subtitle: 'Select reference materials for the AI',
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: _packs.length,
            itemBuilder: (ctx, i) {
              final p = _packs[i];
              return _PackCard(
                name: p.$1,
                desc: p.$2,
                docs: p.$3,
                icon: p.$4,
                color: p.$5,
                selected: i < 2,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatefulWidget {
  final String name;
  final String desc;
  final int docs;
  final IconData icon;
  final Color color;
  final bool selected;

  const _PackCard({
    required this.name,
    required this.desc,
    required this.docs,
    required this.icon,
    required this.color,
    required this.selected,
  });

  @override
  State<_PackCard> createState() => _PackCardState();
}

class _PackCardState extends State<_PackCard> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _selected = !_selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _selected
              ? widget.color.withOpacity(0.08)
              : ArrestoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selected ? widget.color : ArrestoColors.line,
            width: _selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: widget.color, size: 20),
                const Spacer(),
                Checkbox(
                  value: _selected,
                  onChanged: (v) =>
                      setState(() => _selected = v ?? false),
                  activeColor: widget.color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.name, style: ArrestoText.bodyBold()),
            Text('${widget.docs} documents', style: ArrestoText.xs()),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: Script ────────────────────────────────────────────────────────────

class _StepScript extends StatefulWidget {
  final String? selectedDoc;
  final TextEditingController titleCtrl;
  final TextEditingController topicCtrl;
  final TextEditingController descCtrl;
  final TextEditingController objectivesCtrl;
  final TextEditingController userInstructCtrl;
  final String audience;
  final String difficulty;
  final String courseLength;
  final String language;
  final ValueChanged<Map<String, dynamic>> onComplete;
  final ValueChanged<String> onScriptId;

  const _StepScript({
    required this.selectedDoc,
    required this.titleCtrl,
    required this.topicCtrl,
    required this.descCtrl,
    required this.objectivesCtrl,
    required this.userInstructCtrl,
    required this.audience,
    required this.difficulty,
    required this.courseLength,
    required this.language,
    required this.onComplete,
    required this.onScriptId,
  });

  @override
  State<_StepScript> createState() => _StepScriptState();
}

class _StepScriptState extends State<_StepScript> {
  bool _generating = false;
  double _progress = 0;
  bool _done = false;
  String? _error;
  String _stage = '';
  Map<String, dynamic>? _courseScript;

  Future<void> _generate() async {
    if (widget.selectedDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Select a source document in Step 2 first.')),
      );
      return;
    }

    setState(() {
      _generating = true;
      _progress = 0;
      _error = null;
      _done = false;
      _stage = 'Starting generation…';
      _courseScript = null;
    });

    try {
      // Build a comprehensive instructions string from all form fields.
      // Strip trailing periods before appending — the backend parser uses
      // field-label lookaheads as delimiters, not sentence-ending periods.
      String _norm(String s) => s.trimRight().endsWith('.') ? s.trimRight() : s.trimRight();
      final parts = <String>[];
      final topic = widget.topicCtrl.text.trim();
      final desc = widget.descCtrl.text.trim();
      final objectives = widget.objectivesCtrl.text.trim();
      if (topic.isNotEmpty) parts.add('Topic focus: ${_norm(topic)}.');
      if (desc.isNotEmpty) parts.add('Course description: ${_norm(desc)}.');
      parts.add('Difficulty level: ${widget.difficulty}.');
      if (objectives.isNotEmpty) parts.add('Learning objectives: ${_norm(objectives)}.');
      final instructions = parts.isEmpty ? null : parts.join(' ');

      final rawUserInstructions = widget.userInstructCtrl.text.trim();

      final jobId = await CourseService.generateCourse(
        sourceFile: widget.selectedDoc!,
        courseTitle: widget.titleCtrl.text.trim().isEmpty
            ? null
            : widget.titleCtrl.text.trim(),
        targetAudience: widget.audience,
        instructions: instructions,
        userInstructions: rawUserInstructions.isEmpty ? null : rawUserInstructions,
        language: widget.language,
        durationRange: widget.courseLength,
      );

      // Register the job ID immediately — before polling — so navigating away
      // from this step doesn't lose the ID when the widget unmounts.
      widget.onScriptId(jobId);

      // Poll until completed or failed
      while (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        final s = await CourseService.getJobStatus(jobId);
        if (!mounted) return;

        final raw = s['status'] as String? ?? '';
        final progress =
            (s['progress'] as num?)?.toDouble() ?? _progress;
        final step = s['step'] as String? ?? _stage;

        setState(() {
          _progress = progress;
          _stage = step;
        });

        if (raw == 'completed') {
          final script =
              s['course_script'] as Map<String, dynamic>?;
          setState(() {
            _generating = false;
            _done = true;
            _courseScript = script;
          });
          if (script != null) widget.onComplete(script);
          break;
        } else if (raw == 'failed') {
          setState(() {
            _generating = false;
            _error =
                s['error'] as String? ?? 'Generation failed.';
          });
          break;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.auto_fix_high_rounded,
                title: 'Script Generation',
                subtitle:
                    'Generate the full course script from your source',
              ),
              const SizedBox(height: 16),

              if (widget.selectedDoc == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ArrestoColors.amberSoft,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: ArrestoColors.amber),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: ArrestoColors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No source document selected. Go back to Step 2 to pick one.',
                        style: ArrestoText.small(),
                      ),
                    ),
                  ]),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ArrestoColors.greenSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: ArrestoColors.green
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.description_rounded,
                        color: ArrestoColors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Source: ${widget.selectedDoc!.split('/').last.split('\\').last}',
                        style: ArrestoText.small(
                            color: ArrestoColors.green),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),

              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ArrestoColors.redSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ArrestoColors.red),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: ArrestoColors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: ArrestoText.small(
                                color: ArrestoColors.red))),
                  ]),
                ),
                const SizedBox(height: 12),
                ArrestoButton(
                  label: 'Try Again',
                  fullWidth: true,
                  variant: ArrestoButtonVariant.orange,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _generate,
                ),
              ] else if (!_generating && !_done) ...[
                ArrestoButton(
                  label: 'Generate Script',
                  fullWidth: true,
                  size: ArrestoButtonSize.lg,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  variant: ArrestoButtonVariant.orange,
                  onPressed: _generate,
                ),
              ] else if (_generating) ...[
                AnimatedArrestoProgressBar(
                  value: _progress,
                  tone: ProgressTone.orange,
                ),
                const SizedBox(height: 8),
                Text(_stage.isEmpty ? 'Processing…' : _stage,
                    style: ArrestoText.small()),
              ],
            ],
          ),
        ),
        if (_done) ...[
          const SizedBox(height: 16),
          _CourseOutline(courseScript: _courseScript),
        ],
      ],
    );
  }
}

// ── Course Outline ────────────────────────────────────────────────────────────

class _CourseOutline extends StatelessWidget {
  final Map<String, dynamic>? courseScript;

  const _CourseOutline({this.courseScript});

  @override
  Widget build(BuildContext context) {
    // courseScript structure from backend:
    // { course_title, estimated_total_duration_min,
    //   modules: [{ module_number, module_title, lessons: [{ lesson_number, lesson_title }] }] }
    final title =
        courseScript?['course_title'] as String? ?? 'Generated Course';
    final durationMin =
        (courseScript?['estimated_total_duration_min'] as num?)?.toInt() ?? 0;
    final modules = courseScript?['modules'] as List? ?? [];
    final totalLessons = modules.fold<int>(0, (sum, m) {
      final lessons = (m as Map<String, dynamic>)['lessons'] as List? ?? [];
      return sum + lessons.length;
    });

    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Course Outline', style: ArrestoText.h3()),
              ),
              const Icon(Icons.check_circle_rounded,
                  color: ArrestoColors.green, size: 18),
              const SizedBox(width: 4),
              Text('Generated',
                  style: ArrestoText.small(color: ArrestoColors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: ArrestoText.bodyBold()),
          const SizedBox(height: 4),
          Row(children: [
            if (totalLessons > 0) ...[
              Icon(Icons.menu_book_rounded,
                  size: 12, color: ArrestoColors.textMuted),
              const SizedBox(width: 3),
              Text('$totalLessons lessons', style: ArrestoText.small()),
              const SizedBox(width: 10),
            ],
            if (durationMin > 0) ...[
              Icon(Icons.schedule_rounded,
                  size: 12, color: ArrestoColors.textMuted),
              const SizedBox(width: 3),
              Text('$durationMin min', style: ArrestoText.small()),
            ],
          ]),
          const SizedBox(height: 14),
          if (modules.isNotEmpty)
            ...modules.asMap().entries.map((entry) {
              final mod = entry.value as Map<String, dynamic>;
              final modTitle =
                  mod['module_title'] as String? ?? 'Module ${entry.key + 1}';
              final lessons = (mod['lessons'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ArrestoColors.line),
                ),
                child: Theme(
                  data: ThemeData(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: entry.key == 0,
                    title: Text(modTitle, style: ArrestoText.bodyBold()),
                    iconColor: ArrestoColors.orange,
                    children: lessons.asMap().entries.map((le) {
                      final lessonTitle = le.value['lesson_title'] as String? ??
                          'Lesson ${le.key + 1}';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.play_circle_outline_rounded,
                            size: 16, color: ArrestoColors.orange),
                        title: Text(lessonTitle, style: ArrestoText.body()),
                      );
                    }).toList(),
                  ),
                ),
              );
            })
          else
            ..._mockModules.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ArrestoColors.line),
                  ),
                  child: Theme(
                    data: ThemeData(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(m.$1, style: ArrestoText.bodyBold()),
                      iconColor: ArrestoColors.orange,
                      children: m.$2
                          .map((lesson) => ListTile(
                                dense: true,
                                leading: const Icon(
                                    Icons.video_library_rounded,
                                    size: 16,
                                    color: ArrestoColors.orange),
                                title: Text(lesson, style: ArrestoText.body()),
                              ))
                          .toList(),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  static const _mockModules = [
    ('Module 1 — Introduction to Fall Protection', [
      'What is fall protection?',
      'Regulatory framework',
      'Statistics and case studies',
    ]),
    ('Module 2 — Equipment & Systems', [
      'Harness types and selection',
      'Anchor point requirements',
      'Connecting devices',
      'Inspection procedures',
    ]),
    ('Module 3 — Practical Application', [
      'Pre-use inspection checklist',
      'Donning and adjustment',
      'Working safely at height',
      'Emergency response',
    ]),
  ];
}

// ── Step 5: Style ─────────────────────────────────────────────────────────────

class _StepStyle extends StatefulWidget {
  final String initialStyle;
  final ValueChanged<String> onStyleChanged;
  const _StepStyle({required this.initialStyle, required this.onStyleChanged});

  @override
  State<_StepStyle> createState() => _StepStyleState();
}

class _StepStyleState extends State<_StepStyle> {
  int _selected = 0;

  // (display label, description, CourseStyle, video style id)
  static const _styles = [
    ('Avatar Presenter', 'AI talking-head avatar with narration (HeyGen)',
        CourseStyle.hybrid,     'hybrid'),
    ('Animated Scene', 'Voice-over video with animated background (HeyGen)',
        CourseStyle.animated,   'animated_scene'),
    ('Whiteboard', 'Hand-drawn whiteboard animation · Free',
        CourseStyle.whiteboard, 'whiteboard_doodle'),
    ('Animated Slides', 'Motion-graphics slide deck · Free',
        CourseStyle.claude,     'modern'),
    ('No Video', 'Publish now — generate videos later from the course page',
        CourseStyle.none,       'none'),
  ];

  @override
  void initState() {
    super.initState();
    final idx = _styles.indexWhere((s) => s.$4 == widget.initialStyle);
    if (idx >= 0) _selected = idx;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Video Style', style: ArrestoText.h3()),
        const SizedBox(height: 6),
        Text('Select the visual style for your course videos',
            style: ArrestoText.small()),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.9,
          ),
          itemCount: _styles.length,
          itemBuilder: (ctx, i) {
            final s = _styles[i];
            final isSelected = _selected == i;
            return GestureDetector(
              onTap: () {
                setState(() => _selected = i);
                widget.onStyleChanged(_styles[i].$4);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: ArrestoColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? ArrestoColors.orange
                        : ArrestoColors.cardBorder,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? ArrestoColors.sh3
                      : ArrestoColors.sh1,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Column(
                    children: [
                      CourseThumb(style: s.$3, height: 120),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(s.$1, style: ArrestoText.h4()),
                              const SizedBox(height: 4),
                              Text(s.$2,
                                  style: ArrestoText.small(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              if (isSelected) ...[
                                const Spacer(),
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: ArrestoColors.orange),
                                    const SizedBox(width: 4),
                                    Text('Selected',
                                        style: ArrestoText.small(
                                            color:
                                                ArrestoColors.orange)
                                          ..copyWith(
                                              fontWeight:
                                                  FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (_styles[_selected].$4 == 'none') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBDBDBD)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF616161)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Course will be published without videos. '
                    'To generate videos later, open the course from the Courses page.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF616161), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_styles[_selected].$4 == 'hybrid' ||
                   _styles[_selected].$4 == 'animated_scene') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFF856404)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Requires HEYGEN_API_KEY — set it in .env to enable this style.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF856404), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Step 6: Language ──────────────────────────────────────────────────────────

class _StepLanguage extends StatefulWidget {
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final String transcriptVoice;
  final ValueChanged<String> onTranscriptVoiceChanged;
  final String videoVoice;
  final ValueChanged<String> onVideoVoiceChanged;

  const _StepLanguage({
    required this.language,
    required this.onLanguageChanged,
    required this.transcriptVoice,
    required this.onTranscriptVoiceChanged,
    required this.videoVoice,
    required this.onVideoVoiceChanged,
  });

  @override
  State<_StepLanguage> createState() => _StepLanguageState();
}

class _StepLanguageState extends State<_StepLanguage> {
  static const _languages = [
    ('English',   '🇮🇳', 'en'),
    ('Hindi',     '🇮🇳', 'hi'),
  ];

  static const _voices = [
    ('ritu',    'Ritu',    'Female', false),
    ('rahul',   'Rahul',   'Male',   true),
    ('kavitha', 'Kavitha', 'Female', false),
    ('gokul',   'Gokul',   'Male',   true),
    ('priya',   'Priya',   'Female', false),
    ('kavya',   'Kavya',   'Female', false),
    ('ishita',  'Ishita',  'Female', false),
    ('pooja',   'Pooja',   'Female', false),
    ('simran',  'Simran',  'Female', false),
    ('neha',    'Neha',    'Female', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card 1: Language
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.language_rounded,
                title: 'Course Language',
                subtitle: 'Select the primary language for content generation',
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.8,
                ),
                itemCount: _languages.length,
                itemBuilder: (ctx, i) {
                  final l = _languages[i];
                  final isSelected = widget.language == l.$1;
                  return GestureDetector(
                    onTap: () => widget.onLanguageChanged(l.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ArrestoColors.amberSoft
                            : ArrestoColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? ArrestoColors.amber
                              : ArrestoColors.line,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(l.$2,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(l.$1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? ArrestoColors.amberStrong
                                      : ArrestoColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card 2: Transcript Voice
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.mic_rounded,
                title: 'Transcript Narration Voice',
                subtitle: 'Voice for lesson audio narration (Sarvam Bulbul-v3)',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ArrestoColors.blueSoft.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: ArrestoColors.blue.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: ArrestoColors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Used when learners play lesson narration audio',
                      style: ArrestoText.xs(color: ArrestoColors.blue),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _voices.map((v) {
                  final selected = widget.transcriptVoice == v.$1;
                  final isMale = v.$4;
                  return GestureDetector(
                    onTap: () =>
                        widget.onTranscriptVoiceChanged(v.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? ArrestoColors.blueSoft
                            : ArrestoColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? ArrestoColors.blue
                              : ArrestoColors.line,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMale
                                ? Icons.person_2_rounded
                                : Icons.person_rounded,
                            size: 14,
                            color: selected
                                ? ArrestoColors.blue
                                : ArrestoColors.textMuted2,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(v.$2,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? ArrestoColors.blue
                                        : ArrestoColors.textPrimary,
                                  )),
                              Text(v.$3,
                                  style: ArrestoText.xs(
                                      color: selected
                                          ? ArrestoColors.blue
                                          : null)),
                            ],
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded,
                                size: 14,
                                color: ArrestoColors.blue),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card 3: Video Voice
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.videocam_rounded,
                title: 'Video Generation Voice',
                subtitle: 'Voice for AI-generated lesson videos (Sarvam Bulbul-v3)',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ArrestoColors.orangeTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: ArrestoColors.orange.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: ArrestoColors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Used for the voiceover in generated MP4 lesson videos',
                      style:
                          ArrestoText.xs(color: ArrestoColors.orange),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _voices.map((v) {
                  final selected = widget.videoVoice == v.$1;
                  final isMale = v.$4;
                  return GestureDetector(
                    onTap: () => widget.onVideoVoiceChanged(v.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? ArrestoColors.orangeTint
                            : ArrestoColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? ArrestoColors.orange
                              : ArrestoColors.line,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMale
                                ? Icons.person_2_rounded
                                : Icons.person_rounded,
                            size: 14,
                            color: selected
                                ? ArrestoColors.orange
                                : ArrestoColors.textMuted2,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(v.$2,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? ArrestoColors.orange
                                        : ArrestoColors.textPrimary,
                                  )),
                              Text(v.$3,
                                  style: ArrestoText.xs(
                                      color: selected
                                          ? ArrestoColors.orange
                                          : null)),
                            ],
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded,
                                size: 14,
                                color: ArrestoColors.orange),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Step 7: Review ────────────────────────────────────────────────────────────

class _StepReview extends StatefulWidget {
  final String title;
  final String audience;
  final String difficulty;
  final String courseLength;
  final String language;
  final String videoStyle;
  final String transcriptVoice;
  final String videoVoice;
  final Map<String, dynamic>? courseScript;
  final String? scriptId;

  const _StepReview({
    required this.title,
    required this.audience,
    required this.difficulty,
    required this.courseLength,
    required this.language,
    required this.videoStyle,
    required this.transcriptVoice,
    required this.videoVoice,
    this.courseScript,
    this.scriptId,
  });

  @override
  State<_StepReview> createState() => _StepReviewState();
}

class _StepReviewState extends State<_StepReview> {
  // Track which modules are expanded in the outline
  final Set<int> _expandedModules = {0};

  static const _styleLabels = {
    'animated_scene':    'Animated Scene',
    'whiteboard_doodle': 'Whiteboard',
    'modern':            'Animated Slides',
    'hybrid':            'Avatar Presenter',
  };

  static const _styleIcons = {
    'animated_scene':    Icons.animation_rounded,
    'whiteboard_doodle': Icons.draw_rounded,
    'modern':            Icons.slideshow_rounded,
    'hybrid':            Icons.record_voice_over_rounded,
  };

  static const _styleToThumb = {
    'animated_scene':    CourseStyle.animated,
    'whiteboard_doodle': CourseStyle.whiteboard,
    'modern':            CourseStyle.claude,
    'hybrid':            CourseStyle.hybrid,
  };

  static const _voiceLabels = {
    'ritu':    'Ritu',
    'rahul':   'Rahul',
    'kavitha': 'Kavitha',
    'gokul':   'Gokul',
    'priya':   'Priya',
    'kavya':   'Kavya',
    'ishita':  'Ishita',
    'pooja':   'Pooja',
    'simran':  'Simran',
    'neha':    'Neha',
  };

  static const _voiceGenders = {
    'ritu':    'Female',
    'rahul':   'Male',
    'kavitha': 'Female',
    'gokul':   'Male',
    'priya':   'Female',
    'kavya':   'Female',
    'ishita':  'Female',
    'pooja':   'Female',
    'simran':  'Female',
    'neha':    'Female',
  };

  @override
  Widget build(BuildContext context) {
    final script     = widget.courseScript;
    final hasScript  = script != null;

    final displayTitle = script?['course_title'] as String? ??
        (widget.title.isNotEmpty ? widget.title : 'Untitled Course');
    final description  = script?['description'] as String? ?? '';
    final objectives   = (script?['learning_objectives'] as List?)
            ?.map((o) => o.toString())
            .toList() ??
        [];
    final modules      = (script?['modules'] as List?) ?? [];
    final totalLessons = modules.fold<int>(0, (sum, m) {
      final ls = (m as Map<String, dynamic>)['lessons'] as List? ?? [];
      return sum + ls.length;
    });
    final duration =
        (script?['estimated_total_duration_min'] as num?)?.toInt() ?? 0;

    final eyebrow = [
      if (widget.audience.isNotEmpty) widget.audience.toUpperCase(),
      if (widget.difficulty.isNotEmpty) widget.difficulty.toUpperCase(),
    ].join(' · ');

    final thumbStyle =
        _styleToThumb[widget.videoStyle] ?? CourseStyle.claude;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Course', style: ArrestoText.h3()),
        const SizedBox(height: 4),
        Text('Confirm everything looks correct before publishing.',
            style: ArrestoText.small()),
        const SizedBox(height: 20),

        // ── No-script warning ───────────────────────────────────────────────
        if (!hasScript) ...[
          _WarningBanner(
            icon: widget.scriptId != null
                ? Icons.hourglass_top_rounded
                : Icons.warning_amber_rounded,
            color: const Color(0xFFF59E0B),
            message: widget.scriptId != null
                ? 'Script is still generating — check Step 4 for progress before publishing.'
                : 'Script not generated yet — go back to Step 4 (Script) and generate the course script first.',
          ),
          const SizedBox(height: 16),
        ],

        // ── Course header card ──────────────────────────────────────────────
        ArrestoCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: CourseThumb(style: thumbStyle, height: 160),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow.isNotEmpty)
                      Text(eyebrow, style: ArrestoText.eyebrow()),
                    const SizedBox(height: 4),
                    Text(displayTitle, style: ArrestoText.h2()),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(description,
                          style: ArrestoText.small(
                              color: ArrestoColors.textMuted),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _Chip(Icons.menu_book_rounded,
                            '$totalLessons lesson${totalLessons == 1 ? '' : 's'}'),
                        _Chip(Icons.schedule_rounded,
                            duration > 0 ? '$duration min' : widget.courseLength),
                        _Chip(Icons.language_rounded, widget.language),
                        _Chip(Icons.bar_chart_rounded, widget.difficulty),
                        if (hasScript)
                          _Chip(Icons.check_circle_rounded, 'Script ready',
                              color: ArrestoColors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Learning objectives ─────────────────────────────────────────────
        if (objectives.isNotEmpty) ...[
          _SectionLabel('Learning Objectives'),
          const SizedBox(height: 8),
          ArrestoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: objectives.asMap().entries.map((e) {
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: e.key < objectives.length - 1 ? 8 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 1, right: 10),
                        decoration: BoxDecoration(
                          color: ArrestoColors.amber.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: ArrestoText.small(color: ArrestoColors.orange)
                                .copyWith(fontSize: 10),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(e.value, style: ArrestoText.small()),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Module / lesson outline ─────────────────────────────────────────
        if (modules.isNotEmpty) ...[
          _SectionLabel('Course Outline'),
          const SizedBox(height: 8),
          ...modules.asMap().entries.map((me) {
            final mi      = me.key;
            final mod     = me.value as Map<String, dynamic>;
            final mTitle  = mod['module_title'] as String? ?? 'Module ${mi + 1}';
            final lessons = (mod['lessons'] as List?) ?? [];
            final isOpen  = _expandedModules.contains(mi);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ArrestoCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() {
                        if (isOpen) {
                          _expandedModules.remove(mi);
                        } else {
                          _expandedModules.add(mi);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: ArrestoColors.amber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'M${mi + 1}',
                                  style: ArrestoText.small(color: ArrestoColors.orange)
                                      .copyWith(fontSize: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mTitle,
                                      style: ArrestoText.body()),
                                  Text(
                                      '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}',
                                      style: ArrestoText.small(
                                          color: ArrestoColors.textMuted)),
                                ],
                              ),
                            ),
                            Icon(
                              isOpen
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: ArrestoColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isOpen)
                      ...lessons.asMap().entries.map((le) {
                        final li      = le.key;
                        final lesson  = le.value as Map<String, dynamic>;
                        final lTitle  = lesson['lesson_title'] as String? ??
                            'Lesson ${li + 1}';
                        final lMin    =
                            (lesson['duration_minutes'] as num?)?.toInt();
                        final isLast  = li == lessons.length - 1;
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: ArrestoColors.line, width: 1),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                16, 10, 16, isLast ? 12 : 10),
                            child: Row(
                              children: [
                                const SizedBox(width: 38),
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: ArrestoColors.textMuted
                                        .withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(lTitle,
                                      style: ArrestoText.small()),
                                ),
                                if (lMin != null)
                                  Text('$lMin min',
                                      style: ArrestoText.small(
                                          color: ArrestoColors.textMuted)),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // ── Settings summary ────────────────────────────────────────────────
        _SectionLabel('Generation Settings'),
        const SizedBox(height: 8),
        ArrestoCard(
          child: Column(
            children: [
              _SettingRow(
                icon: _styleIcons[widget.videoStyle] ??
                    Icons.smart_display_rounded,
                label: 'Video Style',
                value: _styleLabels[widget.videoStyle] ?? widget.videoStyle,
              ),
              _SettingDivider(),
              _SettingRow(
                icon: Icons.record_voice_over_rounded,
                label: 'Transcript Voice',
                value:
                    '${_voiceLabels[widget.transcriptVoice] ?? widget.transcriptVoice}'
                    ' (${_voiceGenders[widget.transcriptVoice] ?? '—'})',
              ),
              _SettingDivider(),
              _SettingRow(
                icon: Icons.videocam_rounded,
                label: 'Video Voice',
                value:
                    '${_voiceLabels[widget.videoVoice] ?? widget.videoVoice}'
                    ' (${_voiceGenders[widget.videoVoice] ?? '—'})',
              ),
              _SettingDivider(),
              _SettingRow(
                icon: Icons.timer_rounded,
                label: 'Course Length',
                value: widget.courseLength.isNotEmpty
                    ? widget.courseLength
                    : '—',
              ),
              _SettingDivider(),
              _SettingRow(
                icon: Icons.people_rounded,
                label: 'Target Audience',
                value: widget.audience.isNotEmpty ? widget.audience : '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Review sub-widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ArrestoText.small(color: ArrestoColors.textMuted),
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label,
      {this.color = ArrestoColors.textMuted});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: ArrestoText.small(color: color)),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SettingRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ArrestoColors.textMuted),
        const SizedBox(width: 10),
        Text(label, style: ArrestoText.small(color: ArrestoColors.textMuted)),
        const Spacer(),
        Text(value, style: ArrestoText.small()),
      ],
    );
  }
}

class _SettingDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
          height: 1, thickness: 1, color: ArrestoColors.line),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _WarningBanner(
      {required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: ArrestoText.small(color: color)),
          ),
        ],
      ),
    );
  }
}

// ── Step 8: Assessment ────────────────────────────────────────────────────────

class _StepAssessment extends StatefulWidget {
  final String? scriptId;
  const _StepAssessment({this.scriptId});

  @override
  State<_StepAssessment> createState() => _StepAssessmentState();
}

class _StepAssessmentState extends State<_StepAssessment> {
  bool _generating = false;
  bool _done = false;
  double _progress = 0;

  final _questionsCtrl  = TextEditingController(text: '5');
  final _passCtrl       = TextEditingController(text: '70');
  final _timeCtrl       = TextEditingController(text: '30');
  final _retakesCtrl    = TextEditingController(text: '3');

  @override
  void dispose() {
    _questionsCtrl.dispose();
    _passCtrl.dispose();
    _timeCtrl.dispose();
    _retakesCtrl.dispose();
    super.dispose();
  }

  int get _questionCount => int.tryParse(_questionsCtrl.text.trim()) ?? 5;

  Future<void> _generate() async {
    setState(() { _generating = true; _progress = 0; _done = false; });
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _progress = (i + 1) / 4);
    }
    if (widget.scriptId != null) {
      try {
        await CourseService.saveAssessmentConfig(
          widget.scriptId!,
          numQuestions: _questionCount,
          passPct:      int.tryParse(_passCtrl.text.trim()) ?? 70,
          timeMin:      int.tryParse(_timeCtrl.text.trim()) ?? 30,
          retakes:      int.tryParse(_retakesCtrl.text.trim()) ?? 3,
        );
      } catch (_) {
        // config save failed — non-blocking, user can still proceed
      }
    }
    if (!mounted) return;
    setState(() { _generating = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.quiz_rounded,
            title: 'Assessment Configuration',
            subtitle: 'Configure and generate the course assessment',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _numField('Questions', _questionsCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Pass %', _passCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Time (min)', _timeCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Retakes', _retakesCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Question Types', style: ArrestoText.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              ArrestoChip(label: 'Multiple Choice', active: true),
              ArrestoChip(label: 'True/False', active: true),
              ArrestoChip(label: 'Scenario', active: false),
              ArrestoChip(label: 'Descriptive', active: false),
            ],
          ),
          const SizedBox(height: 16),
          if (!_generating && !_done)
            ArrestoButton(
              label: 'Generate Assessment',
              fullWidth: true,
              variant: ArrestoButtonVariant.orange,
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: _generate,
            ),
          if (_generating) ...[
            AnimatedArrestoProgressBar(
                value: _progress, tone: ProgressTone.orange),
            const SizedBox(height: 6),
            Text('Generating $_questionCount questions…',
                style: ArrestoText.small()),
          ],
          if (_done) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: ArrestoColors.green, size: 18),
                const SizedBox(width: 6),
                Text('$_questionCount questions generated',
                    style: ArrestoText.body(color: ArrestoColors.green)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArrestoText.label()),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

// ── Step 9: Publish ───────────────────────────────────────────────────────────

class _StepPublish extends StatelessWidget {
  final String? scriptId;
  final String modeName;
  final bool notifyLearners;
  final bool requireCompletion;
  final String assignLabel;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<bool> onNotifyChanged;
  final ValueChanged<bool> onRequireChanged;
  final void Function(String label, String apiValue) onAssignChanged;

  const _StepPublish({
    this.scriptId,
    required this.modeName,
    required this.notifyLearners,
    required this.requireCompletion,
    required this.assignLabel,
    required this.onModeChanged,
    required this.onNotifyChanged,
    required this.onRequireChanged,
    required this.onAssignChanged,
  });

  static const _assignLabels = ['All Active Learners', 'Selected Groups', 'No one yet'];
  static const _assignValues = ['all', 'groups', 'none'];

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.rocket_launch_rounded,
            title: 'Publish Course',
            subtitle: 'Set publishing options and assign to learners',
          ),
          const SizedBox(height: 16),
          if (scriptId == null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: ArrestoColors.amberSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ArrestoColors.amber),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: ArrestoColors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Generate the course script (Step 4) before publishing.',
                    style: ArrestoText.small(),
                  ),
                ),
              ]),
            ),
          Text('Publish Mode', style: ArrestoText.label()),
          const SizedBox(height: 8),
          ChipGroup(
            options: const ['Publish Now', 'Save as Draft', 'Schedule'],
            selected: modeName,
            onChanged: onModeChanged,
          ),
          const SizedBox(height: 16),
          Text('Assign to Learners', style: ArrestoText.label()),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: assignLabel,
            dropdownColor: ArrestoColors.surface,
            style: ArrestoText.body(color: ArrestoColors.textPrimary),
            decoration: const InputDecoration(),
            items: _assignLabels
                .map((l) => DropdownMenuItem(
                    value: l,
                    child: Text(l,
                        style: ArrestoText.body(
                            color: ArrestoColors.textPrimary))))
                .toList(),
            onChanged: (label) {
              if (label == null) return;
              final idx = _assignLabels.indexOf(label);
              onAssignChanged(label, idx >= 0 ? _assignValues[idx] : 'all');
            },
          ),
          const SizedBox(height: 16),
          _toggle('Notify learners on publish', notifyLearners, onNotifyChanged),
          _toggle('Require completion for certificate', requireCompletion, onRequireChanged),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: ArrestoText.body(color: ArrestoColors.textPrimary))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: ArrestoColors.amber,
          ),
        ],
      ),
    );
  }
}
