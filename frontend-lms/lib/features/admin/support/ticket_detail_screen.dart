import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../data/providers/app_state.dart';
import '../../../data/models/ticket.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const TicketDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  void _sendReply(String ticketId) {
    if (_replyCtrl.text.trim().isEmpty) return;
    ref.read(ticketsProvider.notifier).addReply(
          ticketId,
          Reply(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            author: 'Admin User',
            body: _replyCtrl.text.trim(),
            time: 'Just now',
            isAdmin: true,
          ),
        );
    _replyCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(ticketsProvider);
    final ticket = tickets.firstWhere((t) => t.id == widget.id,
        orElse: () => tickets.first);

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      appBar: AppBar(
        backgroundColor: ArrestoColors.surface,
        foregroundColor: ArrestoColors.ink,
        title: Text(ticket.id, style: ArrestoText.h4()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          DropdownButton<String>(
            value: ticket.status,
            underline: const SizedBox(),
            items: const ['Open', 'In Progress', 'Resolved', 'Closed']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (s) {
              if (s != null) {
                ref
                    .read(ticketsProvider.notifier)
                    .updateStatus(ticket.id, s);
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Learner info
                  ArrestoCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: ArrestoColors.amberSoft,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ticket.learnerName
                                .split(' ')
                                .map((n) => n[0])
                                .take(2)
                                .join(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ticket.learnerName,
                                  style: ArrestoText.bodyBold()),
                              Text(ticket.email, style: ArrestoText.xs()),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(status: ticket.status),
                            const SizedBox(height: 4),
                            Text(ticket.date, style: ArrestoText.xs()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Issue details
                  ArrestoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(ticket.subject, style: ArrestoText.h4()),
                            const Spacer(),
                            ArrestoBadge(
                              label: ticket.category,
                              variant: BadgeVariant.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(ticket.desc, style: ArrestoText.body()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Replies
                  if (ticket.replies.isNotEmpty) ...[
                    Text('Replies', style: ArrestoText.h4()),
                    const SizedBox(height: 10),
                    ...ticket.replies.map((r) => _ReplyBubble(reply: r)),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Reply input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: ArrestoColors.surface,
              border:
                  Border(top: BorderSide(color: ArrestoColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Type your reply...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ArrestoButton(
                  label: 'Send',
                  icon: const Icon(Icons.send_rounded),
                  onPressed: () => _sendReply(ticket.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyBubble extends StatelessWidget {
  final Reply reply;
  const _ReplyBubble({required this.reply});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: reply.isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: reply.isAdmin
              ? ArrestoColors.amberSoft
              : ArrestoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: reply.isAdmin
                  ? ArrestoColors.amber
                  : ArrestoColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(reply.author,
                    style: ArrestoText.label()),
                const Spacer(),
                Text(reply.time, style: ArrestoText.xs()),
              ],
            ),
            const SizedBox(height: 6),
            Text(reply.body, style: ArrestoText.body()),
          ],
        ),
      ),
    );
  }
}
