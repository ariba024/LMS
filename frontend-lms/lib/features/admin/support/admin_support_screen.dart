import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/chip_group.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/providers/app_state.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() =>
      _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(ticketsProvider);
    final filtered = _filter == 'All'
        ? tickets
        : tickets.where((t) => t.status == _filter).toList();

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.support_agent_rounded,
              title: 'Support Tickets',
              subtitle: '${tickets.length} total tickets',
            ),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (ctx, c) {
              final cols = c.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  StatCard(
                    title: 'Total',
                    value: '${tickets.length}',
                    icon: Icons.confirmation_number_rounded,
                    barColor: ArrestoColors.blue,
                    iconColor: ArrestoColors.blue,
                  ),
                  StatCard(
                    title: 'Open',
                    value: '${tickets.where((t) => t.status == 'Open').length}',
                    icon: Icons.radio_button_unchecked_rounded,
                    barColor: ArrestoColors.orange,
                    iconColor: ArrestoColors.orange,
                  ),
                  StatCard(
                    title: 'In Progress',
                    value: '${tickets.where((t) => t.status == 'In Progress').length}',
                    icon: Icons.pending_rounded,
                    barColor: ArrestoColors.blue,
                    iconColor: ArrestoColors.blue,
                  ),
                  StatCard(
                    title: 'Resolved',
                    value: '${tickets.where((t) => t.status == 'Resolved').length}',
                    icon: Icons.check_circle_rounded,
                    barColor: ArrestoColors.green,
                    iconColor: ArrestoColors.green,
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ChipGroup(
                options: const [
                  'All',
                  'Open',
                  'In Progress',
                  'Resolved',
                  'Closed',
                ],
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            const SizedBox(height: 16),
            ArrestoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _TableHeader(),
                  ...filtered.map((t) => _TicketRow(ticket: t)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ArrestoColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text('ID', style: ArrestoText.smallBold())),
          Expanded(flex: 3, child: Text('Subject / Learner', style: ArrestoText.smallBold())),
          Expanded(child: Text('Category', style: ArrestoText.smallBold())),
          Expanded(child: Text('Priority', style: ArrestoText.smallBold())),
          Expanded(child: Text('Date', style: ArrestoText.smallBold())),
          Expanded(child: Text('Status', style: ArrestoText.smallBold())),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  final dynamic ticket;
  const _TicketRow({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ArrestoColors.line, width: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/admin/support/${ticket.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                    child: Text(ticket.id,
                        style: ArrestoText.mono()
                            .copyWith(fontWeight: FontWeight.w700))),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticket.subject,
                          style: ArrestoText.bodyBold(),
                          overflow: TextOverflow.ellipsis),
                      Text(ticket.learnerName, style: ArrestoText.xs()),
                    ],
                  ),
                ),
                Expanded(child: Text(ticket.category, style: ArrestoText.small())),
                Expanded(child: _PriorityBadge(priority: ticket.priority)),
                Expanded(child: Text(ticket.date, style: ArrestoText.small())),
                Expanded(child: StatusBadge(status: ticket.status)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final variant = switch (priority) {
      'Low' => BadgeVariant.gray,
      'Medium' => BadgeVariant.blue,
      'High' => BadgeVariant.orange,
      'Urgent' => BadgeVariant.red,
      _ => BadgeVariant.gray,
    };
    return ArrestoBadge(label: priority, variant: variant);
  }
}
