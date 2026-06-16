import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';

class ArrestoAIPanel extends StatefulWidget {
  final String? seedQuestion;
  const ArrestoAIPanel({super.key, this.seedQuestion});

  @override
  State<ArrestoAIPanel> createState() => _ArrestoAIPanelState();
}

class _ArrestoAIPanelState extends State<ArrestoAIPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  bool _typing = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _typing = true;
    });
    _scrollToBottom();

    try {
      final answer = await ChatService.ask(text);
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(_Message(text: answer, isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(_Message(
          text: 'Sorry, I could not reach the AI right now. Please check that the backend is running.',
          isUser: false,
        ));
      });
    }
    _scrollToBottom();
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
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: ArrestoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
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
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              color: ArrestoColors.ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ArrestoColors.amber, ArrestoColors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 19, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arresto AI',
                          style: ArrestoText.h4(color: Colors.white)),
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
                          const SizedBox(width: 5),
                          Text('Safety training assistant',
                              style: ArrestoText.xs(color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(onChip: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                    itemCount: _messages.length + (_typing ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) return const _TypingIndicator();
                      return _MessageBubble(msg: _messages[i]);
                    },
                  ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: const BoxDecoration(
              color: ArrestoColors.surface,
              border: Border(top: BorderSide(color: ArrestoColors.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ask Arresto AI anything...',
                      hintStyle: ArrestoText.small().copyWith(color: ArrestoColors.textMuted),
                      filled: true,
                      fillColor: ArrestoColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ArrestoColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ArrestoColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: ArrestoColors.amber, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [ArrestoColors.amber, ArrestoColors.orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ArrestoColors.amber.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        size: 18, color: Colors.white),
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

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onChip;
  const _EmptyState({required this.onChip});

  static const _suggestions = [
    'What is the minimum anchor strength?',
    'How do I inspect a full-body harness?',
    'Explain the 6-foot free-fall rule.',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [ArrestoColors.amber, ArrestoColors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: ArrestoColors.amber.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 14),
            Text('How can I help you today?',
                style: ArrestoText.h4(color: ArrestoColors.ink)),
            const SizedBox(height: 4),
            Text('Ask anything about safety training',
                style: ArrestoText.small(),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions.map((s) {
                return GestureDetector(
                  onTap: () => onChip(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: ArrestoColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ArrestoColors.cardBorder),
                      boxShadow: ArrestoColors.sh1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            size: 13, color: ArrestoColors.amber),
                        const SizedBox(width: 5),
                        Text(s,
                            style: ArrestoText.small()
                                .copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
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

class _MessageBubble extends StatelessWidget {
  final _Message msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ArrestoColors.amber,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: ArrestoText.body(color: ArrestoColors.ink)
                .copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    // AI message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 12),
        decoration: BoxDecoration(
          color: ArrestoColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: ArrestoColors.cardBorder),
          boxShadow: ArrestoColors.sh1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI label row
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ArrestoColors.line),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [ArrestoColors.amber, ArrestoColors.orange],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text('Arresto AI',
                      style: ArrestoText.xs(color: ArrestoColors.orange)
                          .copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // Markdown content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: MarkdownBody(
                data: msg.text,
                selectable: true,
                styleSheet: _mdStyleSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _mdStyleSheet(BuildContext context) {
    final body = ArrestoText.body(color: ArrestoColors.ink);
    final small = ArrestoText.small(color: ArrestoColors.textSecondary);
    return MarkdownStyleSheet(
      p: body,
      strong: body.copyWith(fontWeight: FontWeight.w700, color: ArrestoColors.ink),
      em: body.copyWith(fontStyle: FontStyle.italic),
      h1: ArrestoText.h3(color: ArrestoColors.ink),
      h2: ArrestoText.h4(color: ArrestoColors.ink),
      h3: ArrestoText.bodyBold(color: ArrestoColors.ink),
      listBullet: body,
      tableBody: small,
      blockquote: body.copyWith(color: ArrestoColors.textMuted, fontStyle: FontStyle.italic),
      code: body.copyWith(
        fontFamily: 'monospace',
        color: ArrestoColors.orange,
        backgroundColor: ArrestoColors.amberSoft,
      ),
      codeblockDecoration: BoxDecoration(
        color: ArrestoColors.amberSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ArrestoColors.amber.withOpacity(0.3)),
      ),
      blockquoteDecoration: BoxDecoration(
        color: ArrestoColors.bg2,
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: ArrestoColors.amber, width: 3),
        ),
      ),
      pPadding: const EdgeInsets.only(bottom: 6),
      listIndent: 18,
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      codeblockPadding: const EdgeInsets.all(12),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true);
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: ArrestoColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: ArrestoColors.cardBorder),
          boxShadow: ArrestoColors.sh1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Arresto AI is thinking',
                style: ArrestoText.xs(color: ArrestoColors.textMuted)),
            const SizedBox(width: 8),
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _controllers[i],
                builder: (_, __) => Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: ArrestoColors.amber
                        .withOpacity(0.4 + 0.6 * _controllers[i].value),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  const _Message({required this.text, required this.isUser});
}
