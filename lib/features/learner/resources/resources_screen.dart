// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/chip_group.dart';
import '../../../core/services/document_service.dart';
import '../../../data/providers/api_providers.dart';

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  String _filter = 'All';

  static const _cats = ['All', 'PDF', 'DOCX', 'PPTX', 'Other'];

  List<DocumentInfo> _applyFilter(List<DocumentInfo> docs) {
    if (_filter == 'All') return docs;
    return docs.where((d) => d.ext == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsApiProvider);

    return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    icon: Icons.download_rounded,
                    title: 'Resources',
                    subtitle:
                        'Course materials, guides and reference documents',
                  ),
                  const SizedBox(height: 16),
                  ChipGroup(
                    options: _cats,
                    selected: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          docsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: ArrestoColors.orange),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: ArrestoColors.textMuted2, size: 40),
                      const SizedBox(height: 12),
                      Text('Could not load documents',
                          style: ArrestoText.bodyMd()),
                      const SizedBox(height: 4),
                      Text('$e',
                          style: ArrestoText.small(),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(documentsApiProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (docs) {
              final filtered = _applyFilter(docs);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_open_rounded,
                            color: ArrestoColors.textMuted2, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          docs.isEmpty
                              ? 'No documents in the knowledge base yet.\nUpload files via Admin → Settings.'
                              : 'No documents match the selected filter.',
                          style: ArrestoText.body(),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('${filtered.length} files',
                              style: ArrestoText.small()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ResourceRow(doc: filtered[i - 1]),
                      );
                    },
                    childCount: filtered.length + 1,
                  ),
                ),
              );
            },
          ),
        ],
      );
  }
}

// ── Row widget ────────────────────────────────────────────────────────────────

class _ResourceRow extends StatelessWidget {
  final DocumentInfo doc;
  const _ResourceRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final ext = doc.ext;
    final Color iconColor;
    final Color iconBg;

    switch (ext) {
      case 'PDF':
        iconColor = ArrestoColors.red;
        iconBg = ArrestoColors.redSoft;
      case 'XLSX':
      case 'XLS':
        iconColor = ArrestoColors.green;
        iconBg = ArrestoColors.greenSoft;
      case 'PPTX':
      case 'PPT':
        iconColor = ArrestoColors.orange;
        iconBg = const Color(0xFFFFF1EC);
      default:
        iconColor = ArrestoColors.blue;
        iconBg = ArrestoColors.blueSoft;
    }

    return ArrestoCard(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.description_rounded,
              size: 22, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(doc.displayName, style: ArrestoText.bodyBold(),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(ext,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: iconColor)),
              ),
              const SizedBox(width: 6),
              Text('${doc.chunkCount} chunks',
                  style: ArrestoText.xs()),
            ]),
          ]),
        ),
        IconButton(
          tooltip: 'Download',
          icon: Icon(Icons.download_rounded,
              color: iconColor, size: 20),
          onPressed: () {
            final url = DocumentService.downloadUrl(doc.sourceFile);
            html.window.open(url, '_blank');
          },
        ),
      ]),
    );
  }
}
