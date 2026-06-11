import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/api/models.dart';
import '../../../core/api/course_service.dart';
import '../../../core/api/document_service.dart';
import '../../../core/api/video_service.dart';
import '../../../core/providers/library_provider.dart';
import '../../../shared/widgets/arresto_button.dart';
import '../../../shared/widgets/arresto_card.dart';
import '../../../shared/widgets/arresto_badge.dart';
import '../../../shared/widgets/progress_bar.dart';

class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});
  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  // ── Document source ───────────────────────────────────────────────
  bool _useUpload = false;
  String? _uploadFilename;
  List<int>? _uploadBytes;
  String? _selectedDoc;

  // ── Settings ──────────────────────────────────────────────────────
  final _titleCtrl        = TextEditingController();
  final _audienceCtrl     = TextEditingController(text: 'Learners');
  final _instructionsCtrl = TextEditingController();
  String _courseFormat = 'standard';
  String _language     = 'en';

  // ── Generation state ──────────────────────────────────────────────
  bool _uploading  = false;
  bool _generating = false;
  int _progress    = 0;
  String _step     = '';
  CourseScript? _script;
  String? _scriptId;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _audienceCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  bool get _canGenerate {
    if (_generating) return false;
    if (_useUpload) return _uploadFilename != null && _uploadBytes != null;
    return _selectedDoc != null;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() { _uploadFilename = file.name; _uploadBytes = file.bytes!; });
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true; _uploading = false;
      _error = null; _progress = 0; _step = 'Preparing…';
      _script = null; _scriptId = null;
    });

    try {
      String docName;
      if (_useUpload) {
        setState(() { _uploading = true; _step = 'Uploading document…'; });
        await DocumentService.uploadDocument(_uploadBytes!, _uploadFilename!);
        ref.read(documentsProvider.notifier).refresh();
        docName = _uploadFilename!;
        setState(() { _uploading = false; _step = 'Starting generation…'; });
      } else {
        docName = _selectedDoc!;
        setState(() => _step = 'Starting generation…');
      }

      final jobId = await CourseService.generateCourse(
        sourceFile:     docName,
        courseTitle:    _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        targetAudience: _audienceCtrl.text.trim().isEmpty ? 'Learners' : _audienceCtrl.text.trim(),
        instructions:   _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
        courseFormat:   _courseFormat,
      );

      await _pollJob(jobId);
    } catch (e) {
      if (mounted) setState(() { _generating = false; _uploading = false; _error = e.toString(); });
    }
  }

  Future<void> _pollJob(String jobId) async {
    int errors = 0;
    while (true) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final job = await CourseService.getJobStatus(jobId);
        errors = 0;
        if (mounted) setState(() { _progress = job.progress; _step = job.step; });

        if (job.isCompleted) {
          if (job.courseScript != null) {
            final script = CourseScript.fromJson({'script_id': jobId, 'course_script': job.courseScript});
            await ref.read(libraryProvider.notifier).refresh();
            if (mounted) setState(() { _generating = false; _script = script; _scriptId = jobId; });
          } else {
            if (mounted) setState(() { _generating = false; _error = 'Generation completed but no script was returned.'; });
          }
          break;
        }

        if (job.isFailed) {
          if (mounted) setState(() { _generating = false; _error = job.error ?? 'Generation failed.'; });
          break;
        }
      } catch (e) {
        errors++;
        if (errors >= 5) {
          if (mounted) setState(() { _generating = false; _error = 'Lost connection after $errors retries.\n\n$e'; });
          break;
        }
        if (mounted) setState(() => _step = 'Retrying… ($errors/5 errors)');
      }
    }
  }

  void _reset() => setState(() {
    _script = null; _error = null; _scriptId = null;
    _selectedDoc = null; _uploadFilename = null; _uploadBytes = null;
    _titleCtrl.clear(); _instructionsCtrl.clear();
    _progress = 0; _step = '';
  });

  @override
  Widget build(BuildContext context) {
    // ── Rich preview once generation is complete ──────────────────
    if (_script != null) {
      return _GeneratedPreview(
        script:      _script!,
        scriptId:    _scriptId ?? '',
        defaultLang: _language,
        onReset:     _reset,
      );
    }

    final docsAsync = ref.watch(documentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Course Generator',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AColors.ink)),
        const Text('Generate AI-powered courses from your documents',
            style: TextStyle(fontSize: 14, color: AColors.textMuted)),
        const SizedBox(height: 28),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Left: form ─────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(children: [

              // ── 1. Source Document ─────────────────────────────────
              ACard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('1. Source Document',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AColors.ink)),
                  const SizedBox(height: 4),
                  const Text('Upload a new file, or select an existing document from the knowledge base.',
                      style: TextStyle(fontSize: 13, color: AColors.textMuted)),
                  const SizedBox(height: 16),

                  Row(children: [
                    _Chip(
                      label: 'Use Existing',
                      selected: !_useUpload,
                      onTap: () => setState(() { _useUpload = false; _uploadFilename = null; _uploadBytes = null; }),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Upload New File',
                      selected: _useUpload,
                      onTap: () => setState(() { _useUpload = true; _selectedDoc = null; }),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  if (_useUpload) ...[
                    GestureDetector(
                      onTap: _pickFile,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                        decoration: BoxDecoration(
                          color: _uploadFilename != null ? AColors.amberSoft : AColors.bg2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _uploadFilename != null ? AColors.amber : AColors.cardBorder,
                            width: _uploadFilename != null ? 2 : 1,
                          ),
                        ),
                        child: Column(children: [
                          Icon(
                            _uploadFilename != null ? Icons.description_rounded : Icons.upload_file_rounded,
                            size: 36,
                            color: _uploadFilename != null ? AColors.orange : AColors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _uploadFilename ?? 'Click to browse',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _uploadFilename != null ? FontWeight.w600 : FontWeight.normal,
                              color: _uploadFilename != null ? AColors.ink : AColors.textSecond,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _uploadFilename != null ? 'Click to change file' : 'PDF, DOCX, or PPTX',
                            style: const TextStyle(fontSize: 12, color: AColors.textMuted),
                          ),
                        ]),
                      ),
                    ),
                  ] else ...[
                    docsAsync.when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                      error: (e, _) => Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AColors.redSoft, borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Could not load documents',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AColors.red)),
                          const SizedBox(height: 4),
                          Text('$e', style: const TextStyle(fontSize: 12, color: AColors.red)),
                          const SizedBox(height: 10),
                          AButton(
                            label: 'Retry', size: AButtonSize.sm, variant: AButtonVariant.ghost,
                            onPressed: () => ref.read(documentsProvider.notifier).refresh(),
                          ),
                        ]),
                      ),
                      data: (docs) => docs.isEmpty
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('No documents in the knowledge base yet.',
                                  style: TextStyle(color: AColors.textMuted, fontSize: 13)),
                              const SizedBox(height: 12),
                              AButton(
                                label: 'Go to Settings',
                                size: AButtonSize.sm, icon: Icons.settings_rounded,
                                onPressed: () => context.go('/admin/settings'),
                              ),
                            ])
                          : Column(
                              children: docs.map((doc) => GestureDetector(
                                onTap: () => setState(() => _selectedDoc = doc.sourceFile),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedDoc == doc.sourceFile ? AColors.amberSoft : AColors.bg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _selectedDoc == doc.sourceFile ? AColors.amber : AColors.cardBorder,
                                      width: _selectedDoc == doc.sourceFile ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AColors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6)),
                                      child: Text(doc.ext, style: const TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.w700, color: AColors.blue)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(doc.displayName, style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: AColors.ink),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('${doc.chunkCount} knowledge chunks',
                                          style: const TextStyle(fontSize: 11, color: AColors.textMuted)),
                                    ])),
                                    if (_selectedDoc == doc.sourceFile)
                                      const Icon(Icons.check_circle_rounded, color: AColors.amber, size: 20),
                                  ]),
                                ),
                              )).toList(),
                            ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),

              // ── 2. Course Settings ─────────────────────────────────
              ACard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('2. Course Settings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AColors.ink)),
                  const SizedBox(height: 20),

                  _FieldLabel('Course Title (optional)'),
                  const SizedBox(height: 6),
                  TextField(controller: _titleCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Defensive Driving Essentials')),
                  const SizedBox(height: 16),

                  _FieldLabel('Target Audience'),
                  const SizedBox(height: 6),
                  TextField(controller: _audienceCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. New site workers, Field supervisors')),
                  const SizedBox(height: 16),

                  _FieldLabel('Language'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: AColors.cardBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _language, isExpanded: true, underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'en',    child: Text('English')),
                        DropdownMenuItem(value: 'en-in', child: Text('English (India)')),
                        DropdownMenuItem(value: 'hi',    child: Text('Hindi  (Sarvam AI)')),
                        DropdownMenuItem(value: 'ta',    child: Text('Tamil')),
                        DropdownMenuItem(value: 'te',    child: Text('Telugu')),
                        DropdownMenuItem(value: 'bn',    child: Text('Bengali')),
                        DropdownMenuItem(value: 'gu',    child: Text('Gujarati')),
                      ],
                      onChanged: (v) { if (v != null) setState(() => _language = v); },
                    ),
                  ),
                  const SizedBox(height: 16),

                  _FieldLabel('Course Format'),
                  const SizedBox(height: 8),
                  Row(children: [
                    _Chip(
                      label: 'Standard', sublabel: 'AI designs structure',
                      selected: _courseFormat == 'standard',
                      onTap: () => setState(() => _courseFormat = 'standard'),
                    ),
                    const SizedBox(width: 10),
                    _Chip(
                      label: 'Blueprint', sublabel: 'You define structure',
                      selected: _courseFormat == 'custom',
                      onTap: () => setState(() => _courseFormat = 'custom'),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _FieldLabel(
                    _courseFormat == 'custom'
                        ? 'Blueprint Instructions (required)'
                        : 'Instructions (optional)',
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _instructionsCtrl,
                    maxLines: 7,
                    decoration: InputDecoration(
                      hintText: _courseFormat == 'custom'
                          ? 'Describe the exact structure:\n• Slide count and topics\n• Quiz placement\n• Language (e.g. Hindi)\n• Specific requirements'
                          : 'Optional guidance for the AI:\n• Tone or style\n• Focus areas\n• Topics to skip',
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          const SizedBox(width: 20),

          // ── Right: Generate panel ──────────────────────────────────
          SizedBox(
            width: 300,
            child: ACard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('3. Generate',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AColors.ink)),
                const SizedBox(height: 12),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AColors.redSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(color: AColors.red, fontSize: 12, height: 1.4)),
                  ),

                if (_generating) ...[
                  Row(children: [
                    Expanded(child: Text(
                      _uploading ? 'Uploading document…' : _step,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AColors.ink),
                    )),
                    Text('$_progress%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AColors.orange)),
                  ]),
                  const SizedBox(height: 8),
                  AProgressBar(value: _progress / 100),
                  const SizedBox(height: 10),
                  const Text(
                    'Claude is reading your document and writing the course. This usually takes 1–3 minutes.',
                    style: TextStyle(fontSize: 11, color: AColors.textMuted, height: 1.4),
                  ),
                ] else ...[
                  if (!_useUpload && _selectedDoc != null)
                    _SummaryRow(Icons.description_outlined, 'Document',
                        _selectedDoc!.length > 28
                            ? '…${_selectedDoc!.substring(_selectedDoc!.length - 28)}'
                            : _selectedDoc!),
                  if (_useUpload && _uploadFilename != null)
                    _SummaryRow(Icons.upload_file_outlined, 'Upload', _uploadFilename!),
                  _SummaryRow(Icons.people_outline_rounded, 'Audience',
                      _audienceCtrl.text.isEmpty ? 'Learners' : _audienceCtrl.text),
                  _SummaryRow(Icons.language_rounded, 'Language', _langLabel(_language)),
                  _SummaryRow(Icons.format_list_bulleted_rounded, 'Format',
                      _courseFormat == 'standard' ? 'Standard' : 'Blueprint'),
                  if (_instructionsCtrl.text.trim().isNotEmpty)
                    _SummaryRow(Icons.notes_rounded, 'Instructions', 'Provided'),
                  const SizedBox(height: 16),
                  const Divider(color: AColors.cardBorder),
                  const SizedBox(height: 16),
                  AButton(
                    label: 'Generate Course',
                    icon: Icons.auto_awesome_rounded,
                    fullWidth: true, size: AButtonSize.lg,
                    onPressed: _canGenerate ? _generate : null,
                  ),
                  if (!_canGenerate)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Select or upload a document first.',
                          style: TextStyle(fontSize: 11, color: AColors.textMuted),
                          textAlign: TextAlign.center),
                    ),
                ],
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

String _langLabel(String code) {
  const m = {
    'en': 'English', 'en-in': 'English (India)',
    'hi': 'Hindi', 'ta': 'Tamil', 'te': 'Telugu',
    'bn': 'Bengali', 'gu': 'Gujarati',
  };
  return m[code] ?? code;
}

// ════════════════════════════════════════════════════════════════════════════
// Rich preview — shown after generation completes (LMSarresto3 template)
// ════════════════════════════════════════════════════════════════════════════

class _GeneratedPreview extends StatelessWidget {
  const _GeneratedPreview({
    required this.script,
    required this.scriptId,
    required this.defaultLang,
    required this.onReset,
  });
  final CourseScript script;
  final String scriptId;
  final String defaultLang;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Action row
        Row(children: [
          AButton(
            label: 'View in Library',
            icon: Icons.library_books_rounded,
            onPressed: () => context.go('/admin/courses'),
          ),
          const SizedBox(width: 10),
          AButton(
            label: 'Generate Another',
            icon: Icons.refresh_rounded,
            variant: AButtonVariant.ghost,
            onPressed: onReset,
          ),
        ]),
        const SizedBox(height: 20),

        // ── Gradient header card ───────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text('Course generated successfully',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Text(script.title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            if (script.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(script.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
            ],
            if (script.objectives.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: script.objectives.map((o) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(o, style: const TextStyle(color: Colors.white, fontSize: 11)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              _StatChip(
                icon: Icons.layers_rounded,
                label: script.isCustom
                    ? '${script.items.length} items'
                    : '${script.modules.length} modules',
              ),
              if (!script.isCustom) ...[
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.school_rounded,
                  label: '${script.modules.fold(0, (n, m) => n + m.lessons.length)} lessons',
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Standard course: modules + lessons ─────────────────────
        if (!script.isCustom)
          ...script.modules.map((m) => _ModulePreview(
            module: m, scriptId: scriptId, defaultLang: defaultLang)),

        // ── Blueprint course: items ─────────────────────────────────
        if (script.isCustom)
          ...script.items.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ItemPreview(
              item: e.value, index: e.key,
              scriptId: scriptId, defaultLang: defaultLang,
            ),
          )),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.white),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Module section ────────────────────────────────────────────────────────────

class _ModulePreview extends StatelessWidget {
  const _ModulePreview({required this.module, required this.scriptId, required this.defaultLang});
  final CourseModule module;
  final String scriptId;
  final String defaultLang;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text('${module.moduleNumber}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(module.title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AColors.ink))),
        ]),
      ),
      ...module.lessons.map((l) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _LessonPreview(
          lesson: l, scriptId: scriptId,
          moduleNumber: module.moduleNumber, defaultLang: defaultLang,
        ),
      )),
      const SizedBox(height: 12),
    ]);
  }
}

// ── Lesson card with inline video panel ──────────────────────────────────────

class _LessonPreview extends StatefulWidget {
  const _LessonPreview({
    required this.lesson, required this.scriptId,
    required this.moduleNumber, required this.defaultLang,
  });
  final CourseLesson lesson;
  final String scriptId;
  final int moduleNumber;
  final String defaultLang;
  @override
  State<_LessonPreview> createState() => _LessonPreviewState();
}

class _LessonPreviewState extends State<_LessonPreview> {
  bool _expanded = false;
  late String _lang;
  String _style  = 'animated_scene';
  String? _renderId;
  VideoRender? _render;
  bool _rendering  = false;
  String _renderMsg = '';
  Timer? _pollTimer;

  @override
  void initState() { super.initState(); _lang = widget.defaultLang; }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  Future<void> _startRender() async {
    setState(() { _rendering = true; _renderMsg = 'Starting…'; _renderId = null; _render = null; });
    try {
      final rid = await VideoService.renderLesson(
        scriptId:     widget.scriptId,
        moduleNumber: widget.moduleNumber,
        lessonNumber: widget.lesson.lessonNumber,
        lang: _lang, style: _style,
      );
      setState(() { _renderId = rid; _renderMsg = 'Processing…'; });
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
    } catch (e) {
      setState(() { _rendering = false; _renderMsg = 'Error: $e'; });
    }
  }

  Future<void> _poll() async {
    if (_renderId == null) return;
    try {
      final r = await VideoService.getRenderStatus(_renderId!);
      if (mounted) {
        setState(() { _render = r; _renderMsg = r.status; });
        if (r.isDone) { _pollTimer?.cancel(); setState(() => _rendering = false); }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    return ACard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                    color: Color(0x1A2563EB), shape: BoxShape.circle),
                child: Center(child: Text('${l.lessonNumber}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AColors.ink)),
                if (l.summary.isNotEmpty)
                  Text(l.summary,
                      style: const TextStyle(fontSize: 12, color: AColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              const Icon(Icons.movie_creation_outlined, size: 14, color: AColors.textMuted),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AColors.textMuted),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (l.keyTakeaways.isNotEmpty) ...[
                const Text('Key Takeaways',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AColors.ink)),
                const SizedBox(height: 6),
                ...l.keyTakeaways.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('•  ', style: TextStyle(color: AColors.amber)),
                    Expanded(child: Text(t,
                        style: const TextStyle(fontSize: 13, color: AColors.textSecond))),
                  ]),
                )),
                const SizedBox(height: 14),
              ],
              if (l.narration.isNotEmpty) ...[
                const Text('Narration Preview',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AColors.ink)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AColors.cardBorder),
                  ),
                  child: Text(
                    l.narration.length > 300
                        ? '${l.narration.substring(0, 300)}…'
                        : l.narration,
                    style: const TextStyle(
                        fontSize: 12, color: AColors.textSecond, height: 1.5)),
                ),
                const SizedBox(height: 14),
              ],
              _PreviewVideoPanel(
                lang: _lang, style: _style,
                rendering: _rendering, renderMsg: _renderMsg,
                render: _render, renderId: _renderId,
                onLangChange:  (v) => setState(() => _lang  = v),
                onStyleChange: (v) => setState(() => _style = v),
                onRender: _startRender,
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Blueprint item card with inline video panel ───────────────────────────────

class _ItemPreview extends StatefulWidget {
  const _ItemPreview({
    required this.item, required this.index,
    required this.scriptId, required this.defaultLang,
  });
  final CourseItem item;
  final int index;
  final String scriptId;
  final String defaultLang;
  @override
  State<_ItemPreview> createState() => _ItemPreviewState();
}

class _ItemPreviewState extends State<_ItemPreview> {
  bool _expanded = false;
  late String _lang;
  String _style   = 'animated_scene';
  String? _renderId;
  VideoRender? _render;
  bool _rendering  = false;
  String _renderMsg = '';
  Timer? _pollTimer;

  bool get _renderable =>
      widget.item.type == 'slide' || widget.item.type == 'closing_slide';

  @override
  void initState() { super.initState(); _lang = widget.defaultLang; }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  Future<void> _startRender() async {
    setState(() { _rendering = true; _renderMsg = 'Starting…'; _renderId = null; _render = null; });
    try {
      final rid = await VideoService.renderItem(
        scriptId: widget.scriptId, itemIndex: widget.index,
        lang: _lang, style: _style,
      );
      setState(() { _renderId = rid; _renderMsg = 'Processing…'; });
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
    } catch (e) {
      setState(() { _rendering = false; _renderMsg = 'Error: $e'; });
    }
  }

  Future<void> _poll() async {
    if (_renderId == null) return;
    try {
      final r = await VideoService.getRenderStatus(_renderId!);
      if (mounted) {
        setState(() { _render = r; _renderMsg = r.status; });
        if (r.isDone) { _pollTimer?.cancel(); setState(() => _rendering = false); }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isQuiz = item.type == 'quiz';

    return ACard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              ABadge(item.type,
                  variant: isQuiz ? ABadgeVariant.orange : ABadgeVariant.blue),
              const SizedBox(width: 12),
              Expanded(child: Text(item.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AColors.ink),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (_renderable) ...[
                const Icon(Icons.movie_creation_outlined, size: 14, color: AColors.textMuted),
                const SizedBox(width: 6),
              ],
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: AColors.textMuted, size: 18),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (item.bullets.isNotEmpty) ...[
                const Text('Slide Content',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AColors.ink)),
                const SizedBox(height: 6),
                ...item.bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('•  ', style: TextStyle(color: AColors.amber)),
                    Expanded(child: Text(b,
                        style: const TextStyle(fontSize: 13, color: AColors.textSecond))),
                  ]),
                )),
                const SizedBox(height: 14),
              ],
              if (isQuiz)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AColors.amberSoft, borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.quiz_outlined, size: 16, color: AColors.orange),
                    SizedBox(width: 8),
                    Text('Quiz items cannot be rendered as video.',
                        style: TextStyle(fontSize: 12, color: AColors.orange)),
                  ]),
                ),
              if (_renderable)
                _PreviewVideoPanel(
                  lang: _lang, style: _style,
                  rendering: _rendering, renderMsg: _renderMsg,
                  render: _render, renderId: _renderId,
                  onLangChange:  (v) => setState(() => _lang  = v),
                  onStyleChange: (v) => setState(() => _style = v),
                  onRender: _startRender,
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Shared video panel for preview lesson/item cards ──────────────────────────

class _PreviewVideoPanel extends StatelessWidget {
  const _PreviewVideoPanel({
    required this.lang, required this.style,
    required this.rendering, required this.renderMsg,
    required this.render, required this.renderId,
    required this.onLangChange, required this.onStyleChange,
    required this.onRender,
  });
  final String lang, style, renderMsg;
  final bool rendering;
  final VideoRender? render;
  final String? renderId;
  final ValueChanged<String> onLangChange, onStyleChange;
  final VoidCallback onRender;

  static const _langs = {
    'en':    'English',
    'en-in': 'English (India)',
    'hi':    'Hindi',
    'ta':    'Tamil',
    'te':    'Telugu',
    'bn':    'Bengali',
    'gu':    'Gujarati',
  };
  static const _styles = {
    'animated_scene':    'HeyGen — Animated Scene',
    'whiteboard_doodle': 'HeyGen — Whiteboard Doodle',
    'hybrid':            'HeyGen — Hybrid',
    'modern':            'Free — Modern',
    'flatcolor':         'Free — Flat Color',
    'whiteboard':        'Free — Whiteboard',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.movie_creation_outlined, size: 15, color: Color(0xFF7C3AED)),
          SizedBox(width: 6),
          Text('Generate Teaching Video',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AColors.ink)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Language: ', style: TextStyle(fontSize: 12, color: AColors.textMuted)),
              DropdownButton<String>(
                value: lang, isDense: true, underline: const SizedBox(),
                items: _langs.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: rendering ? null : (v) { if (v != null) onLangChange(v); },
              ),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Style: ', style: TextStyle(fontSize: 12, color: AColors.textMuted)),
              DropdownButton<String>(
                value: style, isDense: true, underline: const SizedBox(),
                items: _styles.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: rendering ? null : (v) { if (v != null) onStyleChange(v); },
              ),
            ]),
          ],
        ),
        const SizedBox(height: 10),
        if (rendering)
          const Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Rendering…', style: TextStyle(fontSize: 12, color: AColors.textMuted)),
          ])
        else ...[
          Row(children: [
            AButton(
              label: 'Render Video',
              icon: Icons.play_arrow_rounded,
              variant: AButtonVariant.dark,
              size: AButtonSize.sm,
              onPressed: onRender,
            ),
            if (render?.isCompleted == true) ...[
              const SizedBox(width: 8),
              AButton(
                label: 'Download MP4',
                icon: Icons.download_rounded,
                variant: AButtonVariant.ghost,
                size: AButtonSize.sm,
                onPressed: () => launchUrl(
                    Uri.parse(VideoService.downloadUrl(renderId!)),
                    mode: LaunchMode.externalApplication),
              ),
            ],
          ]),
          if (renderMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(renderMsg, style: TextStyle(
                  fontSize: 11,
                  color: render?.isFailed == true ? AColors.red : AColors.textMuted)),
            ),
        ],
      ]),
    );
  }
}

// ── Form helper widgets (unchanged) ──────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.sublabel});
  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: sublabel != null ? 10 : 8),
        decoration: BoxDecoration(
          color: selected ? AColors.ink : AColors.bg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AColors.ink : AColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AColors.textSecond)),
          if (sublabel != null)
            Text(sublabel!, style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.white54 : AColors.textMuted)),
        ]),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AColors.ink));
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 14, color: AColors.textMuted),
      const SizedBox(width: 6),
      SizedBox(width: 72, child: Text(label,
          style: const TextStyle(fontSize: 12, color: AColors.textMuted))),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AColors.ink),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );
}
