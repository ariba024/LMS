import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/chip_group.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/providers/api_providers.dart';

class LearnersScreen extends ConsumerStatefulWidget {
  const LearnersScreen({super.key});

  @override
  ConsumerState<LearnersScreen> createState() => _LearnersScreenState();
}

class _LearnersScreenState extends ConsumerState<LearnersScreen> {
  // _backendQuery drives the actual API call; updated after 400 ms debounce.
  // _filter is client-side (Active/Inactive) applied to the returned list.
  String _backendQuery = '';
  String _filter = 'All';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _backendQuery = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final learnersAsync = ref.watch(learnersApiProvider(_backendQuery));
    final learners = learnersAsync.valueOrNull ?? [];
    final filtered = _filter == 'All'
        ? learners
        : learners.where((l) => l.status == _filter).toList();

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.people_rounded,
              title: 'Learner Management',
              subtitle: _backendQuery.isEmpty
                  ? '${learners.length} total learners'
                  : '${learners.length} matching "${_backendQuery}"',
            ),
            const SizedBox(height: 20),

            // Stats strip
            LayoutBuilder(builder: (ctx, c) {
              final cols   = c.maxWidth > 800 ? 4 : 2;
              final total  = learners.length;
              final active = learners.where((l) => l.status == 'Active').length;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    title: 'Total Learners',
                    value: '$total',
                    icon: Icons.people_rounded,
                    barColor: ArrestoColors.blue,
                    iconColor: ArrestoColors.blue,
                  ),
                  StatCard(
                    title: 'Active',
                    value: '$active',
                    icon: Icons.check_circle_rounded,
                    barColor: ArrestoColors.green,
                    iconColor: ArrestoColors.green,
                  ),
                  StatCard(
                    title: 'Inactive',
                    value: '${total - active}',
                    icon: Icons.pause_circle_rounded,
                    barColor: ArrestoColors.textMuted,
                    iconColor: ArrestoColors.textMuted,
                  ),
                  const StatCard(
                    title: 'New This Month',
                    value: '—',
                    icon: Icons.person_add_rounded,
                    barColor: ArrestoColors.amber,
                    iconColor: ArrestoColors.amber,
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),

            // Search + status filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _onSearch,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded,
                          color: ArrestoColors.textMuted),
                      hintText: 'Search by name or email...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ChipGroup(
                  options: const ['All', 'Active', 'Inactive'],
                  selected: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table
            ArrestoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text('Learner',
                                style: ArrestoText.smallBold())),
                        Expanded(
                            child: Text('Enrolled',
                                style: ArrestoText.smallBold())),
                        Expanded(
                            flex: 2,
                            child: Text('Progress',
                                style: ArrestoText.smallBold())),
                        Expanded(
                            child: Text('Last Active',
                                style: ArrestoText.smallBold())),
                        Expanded(
                            child: Text('Status',
                                style: ArrestoText.smallBold())),
                        const SizedBox(width: 60),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: ArrestoColors.line),

                  if (learnersAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          _backendQuery.isNotEmpty
                              ? 'No learners match "$_backendQuery".'
                              : 'No learners found.',
                          style: ArrestoText.body(
                              color: ArrestoColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((l) => _LearnerRow(learner: l)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnerRow extends StatelessWidget {
  final dynamic learner;
  const _LearnerRow({required this.learner});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: ArrestoColors.line, width: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/admin/learners/${learner.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      ArrestoAvatar(name: learner.name, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(learner.name,
                                style: ArrestoText.bodyBold(),
                                overflow: TextOverflow.ellipsis),
                            Text(learner.email,
                                style: ArrestoText.xs(),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                    child: Text('${learner.enrolled}',
                        style: ArrestoText.body(
                            color: ArrestoColors.textPrimary))),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedArrestoProgressBar(
                          value: learner.progress / 100,
                          height: 6,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${learner.progress}%',
                          style: ArrestoText.small()),
                    ],
                  ),
                ),
                Expanded(
                    child: Text(learner.lastActive,
                        style: ArrestoText.small())),
                Expanded(child: StatusBadge(status: learner.status)),
                TextButton(
                  onPressed: () =>
                      context.go('/admin/learners/${learner.id}'),
                  child: Text('View',
                      style: ArrestoText.small(
                              color: ArrestoColors.orange)
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
