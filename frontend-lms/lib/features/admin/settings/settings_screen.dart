import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/admin_user_service.dart';
import '../../../core/services/document_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/providers/api_providers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _section = 'Admin Profile';

  static const _navSections = [
    ('Account', ['Admin Profile']),
    ('People', ['User Management', 'Approval Center', 'Roles & Permissions']),
    ('Platform', ['Course Defaults', 'AI Generation', 'Knowledge Base', 'Assessments', 'Certificates']),
    ('Configuration', ['Notifications', 'Branding', 'Languages', 'System']),
    ('Danger Zone', ['Delete Platform Data']),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      body: isWide
          ? Row(
              children: [
                _SettingsNav(
                    sections: _navSections,
                    selected: _section,
                    onSelect: (s) => setState(() => _section = s)),
                Expanded(child: _SettingsContent(section: _section)),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                      icon: Icons.settings_rounded, title: 'Settings'),
                  const SizedBox(height: 16),
                  _SettingsContent(section: _section),
                ],
              ),
            ),
    );
  }
}

class _SettingsNav extends StatelessWidget {
  final List<(String, List<String>)> sections;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SettingsNav({
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: ArrestoColors.surface,
        border: Border(right: BorderSide(color: ArrestoColors.cardBorder)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text('Settings', style: ArrestoText.h3()),
          ),
          ...sections.map((section) {
            final isDanger = section.$1 == 'Danger Zone';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: Text(
                    section.$1,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ArrestoColors.textMuted2,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...section.$2.map((item) {
                  final isActive = selected == item;
                  return GestureDetector(
                    onTap: () => onSelect(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: isActive
                            ? ArrestoColors.amberSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isDanger
                              ? ArrestoColors.red
                              : isActive
                                  ? ArrestoColors.orange
                                  : ArrestoColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  final String section;
  const _SettingsContent({required this.section});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section, style: ArrestoText.h2()),
          const SizedBox(height: 4),
          Text('Manage your $section settings',
              style: ArrestoText.small()),
          const SizedBox(height: 24),
          if (section == 'Admin Profile') _ProfileSettings(),
          if (section == 'User Management') const _UserManagementSettings(),
          if (section == 'AI Generation') _AISettings(),
          if (section == 'Knowledge Base') _KnowledgeBaseSettings(),
          if (section == 'Notifications') _NotificationSettings(),
          if (section == 'Branding') _BrandingSettings(),
          if (section == 'Delete Platform Data') _DangerZone(),
          if (!['Admin Profile', 'User Management', 'AI Generation', 'Knowledge Base', 'Notifications', 'Branding', 'Delete Platform Data'].contains(section))
            ArrestoCard(
              child: Column(children: [
                const Icon(Icons.construction_rounded,
                    color: ArrestoColors.textMuted2, size: 32),
                const SizedBox(height: 8),
                Text('Coming soon', style: ArrestoText.body()),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ProfileSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile Information', style: ArrestoText.h4()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _field('First Name', 'Admin')),
              const SizedBox(width: 12),
              Expanded(child: _field('Last Name', 'User')),
            ],
          ),
          const SizedBox(height: 12),
          _field('Email', 'admin@arresto.com'),
          const SizedBox(height: 12),
          _field('Organisation', 'Arresto Safety Training'),
          const SizedBox(height: 16),
          _toggle('Receive email notifications', true),
          const SizedBox(height: 8),
          _toggle('Two-factor authentication', false),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArrestoText.label()),
        const SizedBox(height: 5),
        TextFormField(initialValue: value),
      ],
    );
  }

  Widget _toggle(String label, bool value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: ArrestoText.body(color: ArrestoColors.textPrimary))),
        Switch(
          value: value,
          onChanged: (_) {},
          activeColor: ArrestoColors.amber,
          activeTrackColor: ArrestoColors.amberSoft,
        ),
      ],
    );
  }
}

class _AISettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Generation Settings', style: ArrestoText.h4()),
          const SizedBox(height: 16),
          ...[
            ('Enable AI course generation', true),
            ('Auto-generate assessments', true),
            ('Use knowledge packs by default', false),
            ('Generate bilingual courses', false),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item.$1, style: ArrestoText.body(color: ArrestoColors.textPrimary))),
                    Switch(
                      value: item.$2,
                      onChanged: (_) {},
                      activeColor: ArrestoColors.amber,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _NotificationSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notification Preferences', style: ArrestoText.h4()),
          const SizedBox(height: 16),
          ...[
            ('Course completion alerts', true),
            ('Assessment submissions', true),
            ('New support tickets', true),
            ('Generation completed', false),
            ('Weekly digest', true),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item.$1, style: ArrestoText.body(color: ArrestoColors.textPrimary))),
                    Switch(
                      value: item.$2,
                      onChanged: (_) {},
                      activeColor: ArrestoColors.amber,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _BrandingSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Brand Settings', style: ArrestoText.h4()),
          const SizedBox(height: 16),
          Text('Primary Colour', style: ArrestoText.label()),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ArrestoColors.amber,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ArrestoColors.lineStrong),
                ),
              ),
              const SizedBox(width: 10),
              Text('#F5BE3F', style: ArrestoText.mono()),
            ],
          ),
          const SizedBox(height: 16),
          Text('Logo Upload', style: ArrestoText.label()),
          const SizedBox(height: 8),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: ArrestoColors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ArrestoColors.lineStrong),
            ),
            child: Center(
              child: Text('Drop logo here or click to upload',
                  style: ArrestoText.small()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Knowledge Base ────────────────────────────────────────────────────────────

class _FileJob {
  final String jobId;
  final String filename;
  String status; // processing | completed | failed
  String? error;
  int? chunksCreated;
  _FileJob({required this.jobId, required this.filename, this.status = 'processing'});
}

class _KnowledgeBaseSettings extends ConsumerStatefulWidget {
  @override
  ConsumerState<_KnowledgeBaseSettings> createState() =>
      _KnowledgeBaseSettingsState();
}

class _KnowledgeBaseSettingsState
    extends ConsumerState<_KnowledgeBaseSettings> {
  bool _picking = false;
  String? _pickError;
  List<_FileJob> _jobs = [];
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _anyProcessing => _jobs.any((j) => j.status == 'processing');

  void _pickAndUpload() {
    final input = html.FileUploadInputElement()
      ..accept = '.pdf,.docx,.pptx,.txt,.csv'
      ..multiple = true;
    input.click();
    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;
      setState(() {
        _picking = true;
        _pickError = null;
        _jobs = [];
      });
      try {
        final loaded = <({String name, List<int> bytes})>[];
        for (final file in files) {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          await reader.onLoadEnd.first;
          final raw = reader.result;
          final bytes = raw is ByteBuffer
              ? raw.asUint8List()
              : Uint8List.fromList(raw as List<int>);
          loaded.add((name: file.name, bytes: bytes));
        }
        final submitted = await DocumentService.startBatchUpload(loaded);
        if (!mounted) return;
        setState(() {
          _picking = false;
          _jobs = submitted
              .map((s) => _FileJob(jobId: s.jobId, filename: s.filename))
              .toList();
        });
        if (_jobs.isNotEmpty) _startPolling();
      } catch (e) {
        if (!mounted) return;
        String msg = 'Upload failed';
        if (e is DioException) {
          final d = e.response?.data;
          if (d is Map && d['detail'] != null) {
            msg = 'Upload failed: ${d['detail']}';
          } else if (e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionTimeout) {
            msg = 'Upload timed out — server may still be processing. Refresh in a moment.';
          } else if (e.type == DioExceptionType.connectionError) {
            msg = 'Upload failed: could not reach the server.';
          } else {
            msg = 'Upload failed: ${e.message ?? e.type.name}';
          }
        } else {
          msg = 'Upload failed: $e';
        }
        setState(() {
          _picking = false;
          _pickError = msg;
        });
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      bool anyLeft = false;
      for (final job in _jobs) {
        if (job.status == 'processing') {
          anyLeft = true;
          try {
            final s = await DocumentService.getJobStatus(job.jobId);
            if (mounted && s.isTerminal) {
              setState(() {
                job.status = s.status;
                job.error = s.error;
                job.chunksCreated = s.chunksCreated;
              });
            }
          } catch (_) {}
        }
      }
      if (!anyLeft) {
        _pollTimer?.cancel();
        ref.invalidate(documentsNotifierProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload card
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload Documents', style: ArrestoText.h4()),
              const SizedBox(height: 4),
              Text(
                'Add PDFs, Word docs, and presentations to the AI knowledge base.',
                style: ArrestoText.small(),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: (_picking || _anyProcessing) ? null : _pickAndUpload,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 90,
                  decoration: BoxDecoration(
                    color: ArrestoColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _picking
                          ? ArrestoColors.orange
                          : ArrestoColors.lineStrong,
                    ),
                  ),
                  child: Center(
                    child: _picking
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: ArrestoColors.orange, strokeWidth: 2.5),
                              ),
                              SizedBox(height: 8),
                              Text('Sending files…'),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_rounded,
                                  size: 30, color: ArrestoColors.textMuted2),
                              const SizedBox(height: 6),
                              Text('Click to upload files', style: ArrestoText.bodyMd()),
                              Text('PDF, DOCX, PPTX, TXT, CSV', style: ArrestoText.small()),
                            ],
                          ),
                  ),
                ),
              ),

              // Error banner
              if (_pickError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ArrestoColors.redSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ArrestoColors.red),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: ArrestoColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_pickError!,
                        style: ArrestoText.small(color: ArrestoColors.red))),
                  ]),
                ),
              ],

              // Per-file progress rows
              if (_jobs.isNotEmpty) ...[
                const SizedBox(height: 14),
                ..._jobs.map((job) => _JobRow(job: job)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Documents list card
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Indexed Documents', style: ArrestoText.h4())),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: ArrestoColors.textMuted),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.read(documentsNotifierProvider.notifier).refresh(),
                ),
              ]),
              const SizedBox(height: 12),
              docsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: ArrestoColors.orange),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: ArrestoColors.textMuted2, size: 28),
                    const SizedBox(height: 8),
                    Text('Could not load: $e',
                        style: ArrestoText.small(),
                        textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () =>
                          ref.read(documentsNotifierProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ]),
                ),
                data: (docs) {
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Column(children: [
                          const Icon(Icons.folder_open_rounded,
                              color: ArrestoColors.textMuted2, size: 32),
                          const SizedBox(height: 8),
                          Text('No documents uploaded yet.',
                              style: ArrestoText.small()),
                        ]),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                            '${docs.length} document${docs.length == 1 ? '' : 's'} · '
                            '${docs.fold(0, (s, d) => s + d.chunkCount)} total chunks',
                            style: ArrestoText.small()),
                      ),
                      ...docs.map((doc) => _DocumentRow(
                        doc: doc,
                        onDeleted: () => ref
                            .read(documentsNotifierProvider.notifier)
                            .refresh(),
                      )),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JobRow extends StatelessWidget {
  final _FileJob job;
  const _JobRow({required this.job});

  @override
  Widget build(BuildContext context) {
    final isProcessing = job.status == 'processing';
    final isComplete   = job.status == 'completed';

    final Color statusColor = isComplete
        ? ArrestoColors.green
        : isProcessing
            ? ArrestoColors.orange
            : ArrestoColors.red;

    final Widget statusIcon = isProcessing
        ? const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                color: ArrestoColors.orange, strokeWidth: 2))
        : Icon(
            isComplete
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: statusColor,
            size: 16,
          );

    final String statusLabel = isProcessing
        ? 'Processing…'
        : isComplete
            ? '${job.chunksCreated ?? 0} chunks indexed'
            : job.error ?? 'Failed';

    final display = job.filename.length > 44
        ? '…${job.filename.substring(job.filename.length - 42)}'
        : job.filename;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isComplete
            ? ArrestoColors.greenSoft
            : isProcessing
                ? ArrestoColors.amberSoft
                : ArrestoColors.redSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        statusIcon,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(display,
                  style: ArrestoText.bodyBold(),
                  overflow: TextOverflow.ellipsis),
              Text(statusLabel, style: ArrestoText.xs(color: statusColor)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Document Row ──────────────────────────────────────────────────────────────

class _DocumentRow extends StatefulWidget {
  final DocumentInfo doc;
  final VoidCallback onDeleted;
  const _DocumentRow({required this.doc, required this.onDeleted});

  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _openingFile = false;
  bool _deleting = false;

  void _viewText() {
    showDialog(
      context: context,
      builder: (_) => _TextViewerDialog(doc: widget.doc),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArrestoColors.surface,
        title: Text('Remove document?', style: ArrestoText.h4()),
        content: Text(
          'This will permanently remove "${widget.doc.displayName}" and all '
          'its indexed chunks from the knowledge base.',
          style: ArrestoText.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: ArrestoColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await DocumentService.deleteDocument(widget.doc.sourceFile);
      if (!mounted) return;
      widget.onDeleted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('"${widget.doc.displayName}" removed from knowledge base.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _openFile() async {
    setState(() => _openingFile = true);
    try {
      final result = await DocumentService.getFileBytes(widget.doc.sourceFile);
      final blob = html.Blob([result.bytes], result.mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      Future.delayed(
        const Duration(seconds: 60),
        () => html.Url.revokeObjectUrl(url),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: ArrestoColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ArrestoColors.line),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: ArrestoColors.redSoft,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.doc.ext,
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
              Text(widget.doc.displayName,
                  style: ArrestoText.bodyBold(),
                  overflow: TextOverflow.ellipsis),
              Text('${widget.doc.chunkCount} chunks',
                  style: ArrestoText.xs()),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.article_rounded, size: 18),
          color: ArrestoColors.textMuted,
          tooltip: 'View extracted text',
          onPressed: _viewText,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (_openingFile)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: ArrestoColors.orange, strokeWidth: 2),
          )
        else
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            color: ArrestoColors.textMuted,
            tooltip: 'Open original file',
            onPressed: _openFile,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if (_deleting)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: ArrestoColors.red, strokeWidth: 2),
          )
        else
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: ArrestoColors.red,
            tooltip: 'Remove from knowledge base',
            onPressed: _delete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ]),
    );
  }
}

// ── Text Viewer Dialog ────────────────────────────────────────────────────────

class _TextViewerDialog extends StatefulWidget {
  final DocumentInfo doc;
  const _TextViewerDialog({required this.doc});

  @override
  State<_TextViewerDialog> createState() => _TextViewerDialogState();
}

class _TextViewerDialogState extends State<_TextViewerDialog> {
  DocumentContent? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final content =
          await DocumentService.getDocumentContent(widget.doc.sourceFile);
      if (mounted) setState(() => _content = content);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ArrestoColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.doc.displayName,
                          style: ArrestoText.h4(),
                          overflow: TextOverflow.ellipsis),
                      if (_content != null)
                        Text(
                          '${_content!.totalChunks} chunks · '
                          '${_content!.assetType.toUpperCase()}',
                          style: ArrestoText.small(),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: ArrestoColors.line),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Failed to load: $_error',
                            style: ArrestoText.small(
                                color: ArrestoColors.red),
                            textAlign: TextAlign.center),
                      ),
                    )
                  : _content == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: ArrestoColors.orange),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(
                            _content!.fullText,
                            style: ArrestoText.mono()
                                .copyWith(fontSize: 13, height: 1.65),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ArrestoColors.redSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArrestoColors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: ArrestoColors.red),
              const SizedBox(width: 8),
              Text('Danger Zone',
                  style: ArrestoText.h4(color: ArrestoColors.red)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
              'These actions are irreversible. Please proceed with extreme caution.',
              style: ArrestoText.body()),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ArrestoColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete All Platform Data'),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Not available'),
                content: const Text(
                  'Platform data deletion is not yet supported. '
                  'Please contact your system administrator.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── User Management ───────────────────────────────────────────────────────────

class _UserManagementSettings extends StatefulWidget {
  const _UserManagementSettings();

  @override
  State<_UserManagementSettings> createState() => _UserManagementSettingsState();
}

class _UserManagementSettingsState extends State<_UserManagementSettings> {
  late Future<List<AdminUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = AdminUserService.listUsers();
  }

  void _refresh() => setState(() => _usersFuture = AdminUserService.listUsers());

  Future<void> _showAddUserDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    final nameCtrl  = TextEditingController();
    String role = 'learner';
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: ArrestoColors.surface,
          title: Text('Add User', style: ArrestoText.h4()),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Display name (optional)')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password (min 8 chars) *'),
                  obscureText: true),
              const SizedBox(height: 12),
              Row(children: [
                Text('Role:', style: ArrestoText.label()),
                const SizedBox(width: 12),
                ChoiceChip(label: const Text('Learner'), selected: role == 'learner',
                    onSelected: (_) => setS(() => role = 'learner')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Admin'), selected: role == 'admin',
                    onSelected: (_) => setS(() => role = 'admin')),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: submitting ? null : () async {
                if (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) return;
                setS(() => submitting = true);
                try {
                  await AdminUserService.createUser(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text,
                    role: role,
                    displayName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _refresh();
                } catch (e) {
                  setS(() => submitting = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: ArrestoColors.amber,
                  foregroundColor: ArrestoColors.ink),
              child: submitting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ArrestoColors.ink))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose(); passCtrl.dispose(); nameCtrl.dispose();
  }

  Future<void> _showResetPasswordDialog(AdminUser user) async {
    final ctrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: ArrestoColors.surface,
          title: Text('Reset Password', style: ArrestoText.h4()),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Set a new password for ${user.email}', style: ArrestoText.bodySm()),
            const SizedBox(height: 12),
            TextField(controller: ctrl, obscureText: true,
                decoration: const InputDecoration(labelText: 'New password (min 8 chars)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: submitting ? null : () async {
                if (ctrl.text.length < 8) return;
                setS(() => submitting = true);
                try {
                  await AdminUserService.resetPassword(user.id, ctrl.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset successfully.')));
                } catch (e) {
                  setS(() => submitting = false);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: ArrestoColors.amber,
                  foregroundColor: ArrestoColors.ink),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('All Users', style: ArrestoText.h4())),
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 18,
              color: ArrestoColors.textMuted), onPressed: _refresh),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _showAddUserDialog,
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Add User'),
            style: FilledButton.styleFrom(
              backgroundColor: ArrestoColors.amber,
              foregroundColor: ArrestoColors.ink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        FutureBuilder<List<AdminUser>>(
          future: _usersFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: ArrestoColors.orange)));
            }
            if (snap.hasError) {
              return ArrestoCard(child: Center(child: Column(children: [
                const Icon(Icons.wifi_off_rounded, color: ArrestoColors.textMuted2, size: 32),
                const SizedBox(height: 8),
                Text('Could not load users', style: ArrestoText.body()),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ])));
            }
            final users = snap.data ?? [];
            if (users.isEmpty) {
              return ArrestoCard(child: Center(child: Text('No users yet.',
                  style: ArrestoText.body())));
            }
            return Column(
              children: users.map((u) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: u.isActive ? ArrestoColors.surface : ArrestoColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: u.isActive
                      ? ArrestoColors.cardBorder : ArrestoColors.lineStrong),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: u.isAdmin
                        ? ArrestoColors.amberSoft : ArrestoColors.blueSoft,
                    child: Text(u.name[0].toUpperCase(),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: u.isAdmin ? ArrestoColors.amberStrong : ArrestoColors.blue)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.name, style: ArrestoText.bodyBold()),
                    Text(u.email, style: ArrestoText.xs()),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: u.isAdmin ? ArrestoColors.amberSoft : ArrestoColors.blueSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(u.isAdmin ? 'Admin' : 'Learner',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: u.isAdmin ? ArrestoColors.amberStrong : ArrestoColors.blue)),
                  ),
                  const SizedBox(width: 8),
                  if (!u.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ArrestoColors.redSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Inactive', style: ArrestoText.xs(color: ArrestoColors.red)
                          .copyWith(fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 18, color: ArrestoColors.textMuted),
                    onSelected: (action) async {
                      switch (action) {
                        case 'reset':
                          await _showResetPasswordDialog(u);
                        case 'toggle_role':
                          try {
                            await AdminUserService.updateUser(u.id,
                                role: u.isAdmin ? 'learner' : 'admin');
                            _refresh();
                          } catch (_) {}
                        case 'toggle_active':
                          try {
                            await AdminUserService.updateUser(u.id, isActive: !u.isActive);
                            _refresh();
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')));
                          }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'reset',
                          child: Row(children: [
                            Icon(Icons.lock_reset_rounded, size: 16), SizedBox(width: 8),
                            Text('Reset password'),
                          ])),
                      PopupMenuItem(value: 'toggle_role',
                          child: Row(children: [
                            const Icon(Icons.swap_horiz_rounded, size: 16), const SizedBox(width: 8),
                            Text(u.isAdmin ? 'Make Learner' : 'Make Admin'),
                          ])),
                      PopupMenuItem(value: 'toggle_active',
                          child: Row(children: [
                            Icon(u.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                                size: 16, color: u.isActive ? ArrestoColors.red : ArrestoColors.green),
                            const SizedBox(width: 8),
                            Text(u.isActive ? 'Deactivate' : 'Reactivate',
                                style: TextStyle(color: u.isActive
                                    ? ArrestoColors.red : ArrestoColors.green)),
                          ])),
                    ],
                  ),
                ]),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}
