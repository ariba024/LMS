import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/course_thumb.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../data/providers/api_providers.dart';

String _formattedToday() {
  final now = DateTime.now();
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
}

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(libraryProvider).valueOrNull ?? [];
    final isWide = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header (title + date only) ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin Dashboard', style: ArrestoText.h1()),
                    const SizedBox(height: 2),
                    Text(_formattedToday(),
                        style: ArrestoText.small(color: ArrestoColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Compact KPI row ──
                const _KpiGrid(),
                const SizedBox(height: 16),

                // ── Quick actions ──
                const _QuickActions(),
                const SizedBox(height: 20),

                // ── Two-column dashboard ──
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 62,
                            child: Column(
                              children: [
                                _RecentCourses(courses: courses),
                                const SizedBox(height: 16),
                                const _GenerationPanel(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 38,
                            child: Column(
                              children: const [
                                _QuickStatsPanel(),
                                SizedBox(height: 16),
                                _AiUsagePanel(),
                                SizedBox(height: 16),
                                _ActivityPanel(),
                                SizedBox(height: 16),
                                _SystemStatusPanel(),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _RecentCourses(courses: courses),
                          const SizedBox(height: 16),
                          const _GenerationPanel(),
                          const SizedBox(height: 16),
                          const _QuickStatsPanel(),
                          const SizedBox(height: 16),
                          const _AiUsagePanel(),
                          const SizedBox(height: 16),
                          const _ActivityPanel(),
                          const SizedBox(height: 16),
                          const _SystemStatusPanel(),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── KPI grid ────────────────────────────────────────────────────────────────

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseCount = ref.watch(libraryProvider).maybeWhen(
          data: (courses) => courses.length.toString(),
          orElse: () => '—',
        );

    final kpis = <_Kpi>[
      const _Kpi('Total Learners', '1,284', Icons.people_alt_rounded,
          ArrestoColors.blue, '+6.2%', _Trend.up, 'vs last month'),
      _Kpi('Total Courses', courseCount, Icons.library_books_rounded,
          ArrestoColors.amber, '+3', _Trend.up, 'in library'),
      const _Kpi('Active Learners', '1,042', Icons.bolt_rounded,
          ArrestoColors.green, '81%', _Trend.up, 'of total'),
      const _Kpi('Courses Generated', '47', Icons.auto_awesome_rounded,
          ArrestoColors.orange, '+12', _Trend.up, 'this month'),
      const _Kpi('Learning Hours', '18.2k', Icons.schedule_rounded,
          ArrestoColors.blue, '+8.4%', _Trend.up, 'all learners'),
      const _Kpi('AI Conversations', '3,420', Icons.forum_rounded,
          ArrestoColors.amber, '+21%', _Trend.up, 'this week'),
      const _Kpi('Generating Now', '2', Icons.sync_rounded,
          ArrestoColors.red, 'live', _Trend.neutral, 'in progress'),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final cols = w > 1120 ? 5 : w > 860 ? 4 : w > 560 ? 3 : 2;
      const gap = 12.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final k in kpis)
            SizedBox(width: cardW, child: _KpiCard(kpi: k)),
        ],
      );
    });
  }
}

enum _Trend { up, down, neutral }

class _Kpi {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final String trend;
  final _Trend dir;
  final String sub;
  const _Kpi(this.title, this.value, this.icon, this.accent, this.trend,
      this.dir, this.sub);
}

class _KpiCard extends StatefulWidget {
  final _Kpi kpi;
  const _KpiCard({required this.kpi});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final k = widget.kpi;
    final trendColor = switch (k.dir) {
      _Trend.up => ArrestoColors.green,
      _Trend.down => ArrestoColors.red,
      _Trend.neutral => ArrestoColors.amber,
    };
    final trendBg = switch (k.dir) {
      _Trend.up => ArrestoColors.greenSoft,
      _Trend.down => ArrestoColors.redSoft,
      _Trend.neutral => ArrestoColors.amberSoft,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        transform:
            _hover ? (Matrix4.identity()..translate(0.0, -3.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: ArrestoColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hover
                ? k.accent.withValues(alpha: 0.5)
                : ArrestoColors.cardBorder,
          ),
          boxShadow: [
            ...ArrestoColors.sh2,
            if (_hover)
              BoxShadow(
                color: k.accent.withValues(alpha: 0.16),
                blurRadius: 24,
                spreadRadius: 1,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Thin glowing accent edge (left)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: k.accent.withValues(alpha: 0.9)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: k.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(k.icon, color: k.accent, size: 16),
                        ),
                        const Spacer(),
                        _TrendChip(
                            label: k.trend, color: trendColor, bg: trendBg, dir: k.dir),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Text(k.value,
                        style: ArrestoText.stat().copyWith(fontSize: 25)),
                    const SizedBox(height: 3),
                    Text(k.title,
                        style: ArrestoText.small(color: ArrestoColors.textSecondary)
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(k.sub, style: ArrestoText.xs(color: ArrestoColors.textMuted2)),
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

class _TrendChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final _Trend dir;
  const _TrendChip(
      {required this.label, required this.color, required this.bg, required this.dir});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            dir == _Trend.up
                ? Icons.trending_up_rounded
                : dir == _Trend.down
                    ? Icons.trending_down_rounded
                    : Icons.circle,
            size: dir == _Trend.neutral ? 7 : 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionButton(
          label: 'Generate Course',
          icon: Icons.auto_awesome_rounded,
          primary: true,
          onTap: () => context.go('/admin/generator'),
        ),
        _ActionButton(
          label: 'Invite Learner',
          icon: Icons.person_add_alt_rounded,
          onTap: () => context.go('/admin/learners'),
        ),
        _ActionButton(
          label: 'Upload Content',
          icon: Icons.upload_file_rounded,
          onTap: () => context.go('/admin/video'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final fg = primary ? const Color(0xFF1B1B1D) : ArrestoColors.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform:
            _hover ? (Matrix4.identity()..translate(0.0, -2.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [ArrestoColors.amber, ArrestoColors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: primary ? null : ArrestoColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: primary
              ? null
              : Border.all(
                  color: _hover
                      ? ArrestoColors.amber.withValues(alpha: 0.4)
                      : ArrestoColors.cardBorder),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: ArrestoColors.amber
                        .withValues(alpha: _hover ? 0.4 : 0.24),
                    blurRadius: _hover ? 22 : 14,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: fg),
                  const SizedBox(width: 8),
                  Text(widget.label,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Left: Recent Courses ────────────────────────────────────────────────────

class _RecentCourses extends StatelessWidget {
  final List courses;
  const _RecentCourses({required this.courses});

  @override
  Widget build(BuildContext context) {
    final recent = courses.take(5).toList();
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  icon: Icons.library_books_rounded,
                  title: 'Recent Courses',
                ),
              ),
              ArrestoButton(
                label: 'View All',
                variant: ArrestoButtonVariant.ghost,
                size: ArrestoButtonSize.sm,
                onPressed: () => context.go('/admin/courses'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Course', style: ArrestoText.smallBold())),
                Expanded(child: Text('Style', style: ArrestoText.smallBold())),
                Expanded(child: Text('Status', style: ArrestoText.smallBold())),
                Expanded(child: Text('Learners', style: ArrestoText.smallBold())),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const Divider(color: ArrestoColors.line, height: 1),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text('No courses yet — generate your first one.',
                    style: ArrestoText.small(color: ArrestoColors.textMuted)),
              ),
            )
          else
            ...recent.map((course) => _CourseRow(course: course)),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final dynamic course;
  const _CourseRow({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ArrestoColors.line, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CourseThumb(style: course.style, code: null, height: 34),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      style: ArrestoText.bodyBold(), overflow: TextOverflow.ellipsis),
                  Text(course.code, style: ArrestoText.xs()),
                ],
              ),
            ),
            Expanded(
              child: Text(
                switch (course.style as CourseStyle) {
                  CourseStyle.animated => 'Animated',
                  CourseStyle.whiteboard => 'Whiteboard',
                  CourseStyle.claude => 'AI Style',
                  CourseStyle.hybrid => 'Hybrid',
                },
                style: ArrestoText.small(),
              ),
            ),
            Expanded(child: StatusBadge(status: course.status)),
            Expanded(
              child: Text('${course.learners}',
                  style: ArrestoText.bodySm(color: ArrestoColors.ink)),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded,
                  size: 16, color: ArrestoColors.textMuted),
              onPressed: () => context.go('/admin/courses'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Left: Current Course Generation ─────────────────────────────────────────

class _GenerationPanel extends StatelessWidget {
  const _GenerationPanel();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Rope Access Safety', 0.7),
      ('PPE Selection Guide', 0.3),
    ];
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.sync_rounded,
            title: 'Current Course Generation',
          ),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(item.$1,
                              style: ArrestoText.bodySm(color: ArrestoColors.ink))),
                      Text('${(item.$2 * 100).round()}%',
                          style: ArrestoText.smallBold(color: ArrestoColors.amber)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedArrestoProgressBar(
                    value: item.$2.toDouble(),
                    tone: ProgressTone.orange,
                    height: 6,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Right: Quick Stats ──────────────────────────────────────────────────────

class _QuickStatsPanel extends StatelessWidget {
  const _QuickStatsPanel();

  @override
  Widget build(BuildContext context) {
    const stats = [
      ('Completion rate', '78%', ArrestoColors.green),
      ('Avg. assessment score', '84%', ArrestoColors.blue),
      ('Certificates issued', '612', ArrestoColors.amber),
      ('Avg. time / course', '1h 12m', ArrestoColors.orange),
    ];
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(icon: Icons.insights_rounded, title: 'Quick Stats'),
          const SizedBox(height: 12),
          for (int i = 0; i < stats.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: stats[i].$3, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(stats[i].$1,
                        style: ArrestoText.small(color: ArrestoColors.textSecondary))),
                Text(stats[i].$2, style: ArrestoText.bodyBold()),
              ],
            ),
            if (i != stats.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Divider(color: ArrestoColors.line, height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Right: AI Usage ─────────────────────────────────────────────────────────

class _AiUsagePanel extends StatelessWidget {
  const _AiUsagePanel();

  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [ArrestoColors.amber, ArrestoColors.orange]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 17, color: Color(0xFF1B1B1D)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('AI Usage', style: ArrestoText.h4())),
              Text('this month', style: ArrestoText.xs()),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('3,420', style: ArrestoText.stat().copyWith(fontSize: 26)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('conversations',
                    style: ArrestoText.xs(color: ArrestoColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Monthly quota', style: ArrestoText.xs())),
              Text('68% used',
                  style: ArrestoText.xs(color: ArrestoColors.amber)),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedArrestoProgressBar(
            value: 0.68,
            tone: ProgressTone.orange,
            height: 6,
          ),
        ],
      ),
    );
  }
}

// ── Right: Recent Learner Activity ──────────────────────────────────────────

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('🎓', 'James Harrington completed WAH-181', '2h ago'),
      ('🤖', 'Scaffolding Safety course generated', '4h ago'),
      ('📋', 'New ticket TK-1042 opened', '5h ago'),
      ('✅', 'Priya Nair passed Assessment 3', '1d ago'),
    ];
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              icon: Icons.notifications_active_rounded,
              title: 'Recent Learner Activity'),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 9),
                  Expanded(
                      child: Text(item.$2,
                          style: ArrestoText.bodySm(color: ArrestoColors.ink))),
                  const SizedBox(width: 6),
                  Text(item.$3, style: ArrestoText.xs()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Right: System Status ────────────────────────────────────────────────────

class _SystemStatusPanel extends StatelessWidget {
  const _SystemStatusPanel();

  @override
  Widget build(BuildContext context) {
    const services = [
      ('Course API', 'Operational'),
      ('Video Pipeline', 'Operational'),
      ('Text-to-Speech', 'Operational'),
      ('Arresto AI', 'Operational'),
    ];
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: SectionHeader(
                      icon: Icons.dns_rounded, title: 'System Status')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ArrestoColors.greenSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('All systems go',
                    style: ArrestoText.xs(color: ArrestoColors.green)
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in services)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: ArrestoColors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                      child: Text(s.$1,
                          style: ArrestoText.small(
                              color: ArrestoColors.textSecondary))),
                  Text(s.$2, style: ArrestoText.xs(color: ArrestoColors.green)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
