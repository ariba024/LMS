import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class SceneVideoDialog extends StatefulWidget {
  final String renderId;
  final String streamUrl;
  final String downloadUrl;
  final String lessonTitle;
  final String ttsEngine;
  final String voice;
  final int wordCount;
  final int sceneIndex;
  final int totalScenes;

  const SceneVideoDialog({
    super.key,
    required this.renderId,
    required this.streamUrl,
    required this.downloadUrl,
    required this.lessonTitle,
    required this.ttsEngine,
    required this.voice,
    required this.wordCount,
    required this.sceneIndex,
    required this.totalScenes,
  });

  @override
  State<SceneVideoDialog> createState() => _SceneVideoDialogState();
}

class _SceneVideoDialogState extends State<SceneVideoDialog> {
  late final String _viewType;
  static final _registered = <String>{};

  @override
  void initState() {
    super.initState();
    _viewType = 'arresto-video-${widget.renderId}';
    if (!_registered.contains(_viewType)) {
      _registered.add(_viewType);
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
        return html.VideoElement()
          ..src = widget.streamUrl
          ..controls = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.background = '#000000';
      });
    }
  }

  void _download() {
    html.window.open(widget.downloadUrl, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final approxMin = (widget.wordCount / 140).ceil();
    final sceneLabel = widget.totalScenes == 1
        ? 'Full lesson'
        : 'Scene ${widget.sceneIndex + 1} of ${widget.totalScenes}';
    final engineLabel =
        widget.ttsEngine.isNotEmpty ? widget.ttsEngine : 'TTS';
    final voiceLabel = widget.voice.isNotEmpty ? widget.voice : '—';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          decoration: BoxDecoration(
            color: ArrestoColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ArrestoColors.cardBorder),
            boxShadow: ArrestoColors.sh4,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline_rounded,
                        color: ArrestoColors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lessonTitle,
                            style: ArrestoText.bodyBold(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(sceneLabel, style: ArrestoText.xs()),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: ArrestoColors.textMuted, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: ArrestoColors.cardBorder),

              // ── Video player ─────────────────────────────────────────────────
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: Colors.black,
                  child: HtmlElementView(viewType: _viewType),
                ),
              ),
              const Divider(height: 1, color: ArrestoColors.cardBorder),

              // ── Metadata + actions ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    _MetaChip(label: '~${widget.wordCount} words'),
                    const SizedBox(width: 6),
                    _MetaChip(label: '~$approxMin min'),
                    const SizedBox(width: 6),
                    _MetaChip(label: '$engineLabel · $voiceLabel'),
                    const Spacer(),
                    // Download
                    GestureDetector(
                      onTap: _download,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: ArrestoColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: ArrestoColors.lineStrong),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.download_rounded,
                                size: 14,
                                color: ArrestoColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              'Download',
                              style: ArrestoText.small(
                                      color: ArrestoColors.textSecondary)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: ArrestoColors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Close',
                          style: ArrestoText.small(color: ArrestoColors.ink)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ArrestoColors.surfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ArrestoColors.line),
      ),
      child: Text(label,
          style: ArrestoText.xs(color: ArrestoColors.textSecondary)),
    );
  }
}
