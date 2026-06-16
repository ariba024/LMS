import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/section_header.dart';

class ArrestoAiScreen extends ConsumerStatefulWidget {
  const ArrestoAiScreen({super.key});
  @override
  ConsumerState<ArrestoAiScreen> createState() => _ArrestoAiScreenState();
}

class _ArrestoAiScreenState extends ConsumerState<ArrestoAiScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _typing = false;

  final _messages = <_Msg>[
    _Msg(false, 'Hi! I\'m Arresto AI — your personal safety learning companion. Ask me anything about fall protection, harness inspection, anchor systems, or any course topic.'),
  ];

  static const _suggestions = [
    '🪝 What\'s the minimum anchor point rating?',
    '🦺 How do I inspect a full-body harness?',
    '📏 What is the max free-fall distance allowed?',
    '🏗️ When is fall protection required?',
  ];

  void _send([String? text]) async {
    final msg = (text ?? _ctrl.text).trim();
    if (msg.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_Msg(true, msg));
      _typing = true;
    });
    _scrollDown();
    try {
      final answer = await ChatService.ask(msg);
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(_Msg(false, answer));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(_Msg(false,
            'Sorry, I could not reach the AI right now. '
            'Please check that the backend is running and try again.',
            isError: true));
      });
    }
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: SectionHeader(
            icon: Icons.smart_toy_rounded,
            title: 'Arresto AI',
            subtitle: 'Your personal safety learning companion',
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            itemCount: _messages.length + (_typing ? 1 : 0) + (_messages.length == 1 ? 1 : 0),
            itemBuilder: (ctx, i) {
              // suggestions row after initial message
              if (_messages.length == 1 && i == 1) return _SuggestionsRow(onTap: _send);
              final idx = (_messages.length == 1 && i > 1) ? i - 1 : i;
              if (_typing && idx == _messages.length) return const _TypingIndicator();
              return _ChatBubble(msg: _messages[idx]);
            },
          ),
        ),
        _InputBar(ctrl: _ctrl, onSend: _send),
      ]);
  }
}

class _Msg {
  final bool isUser;
  final String text;
  final bool isError;
  _Msg(this.isUser, this.text, {this.isError = false});
}

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(color: ArrestoColors.amberSoft, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded, size: 16, color: ArrestoColors.orange),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? ArrestoColors.amber
                    : msg.isError
                        ? ArrestoColors.redSoft
                        : ArrestoColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(msg.isUser ? 14 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 14),
                ),
                border: msg.isUser ? null : Border.all(color: ArrestoColors.cardBorder),
              ),
              child: Text(msg.text,
                  style: ArrestoText.body(
                      color: msg.isUser
                          ? ArrestoColors.ink
                          : msg.isError
                              ? ArrestoColors.red
                              : ArrestoColors.textPrimary)),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: const BoxDecoration(color: ArrestoColors.amberSoft, shape: BoxShape.circle),
          child: const Icon(Icons.smart_toy_rounded, size: 16, color: ArrestoColors.orange),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ArrestoColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ArrestoColors.cardBorder),
          ),
          child: AnimatedBuilder(
            animation: _ac,
            builder: (ctx, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: ArrestoColors.orange.withValues(
                      alpha: (0.3 + 0.7 * ((_ac.value + i * 0.33) % 1.0).clamp(0.0, 1.0)).toDouble(),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SuggestionsRow extends StatelessWidget {
  final Function(String) onTap;
  const _SuggestionsRow({required this.onTap});

  static const _suggestions = [
    '🪝 What\'s the minimum anchor point rating?',
    '🦺 How do I inspect a full-body harness?',
    '📏 What is the max free-fall distance allowed?',
    '🏗️ When is fall protection required?',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestions.map((s) => GestureDetector(
          onTap: () => onTap(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ArrestoColors.amberSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ArrestoColors.amber),
            ),
            child: Text(s, style: ArrestoText.small()),
          ),
        )).toList(),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final Function([String?]) onSend;
  const _InputBar({required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: ArrestoColors.surface,
        border: const Border(top: BorderSide(color: ArrestoColors.line)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(
              hintText: 'Ask about fall protection, harnesses, anchor systems…',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(999))),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => onSend(),
          child: Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(color: ArrestoColors.amber, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, size: 18, color: ArrestoColors.ink),
          ),
        ),
      ]),
    );
  }
}
