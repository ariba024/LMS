import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/chip_group.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/providers/api_providers.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _tab = 'Course Generation';

  static const _tabs = [
    'Course Generation',
    'Content',
    'Learners',
    'AI Tutor',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrestoColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.bar_chart_rounded,
              title: 'Analytics',
              subtitle: 'Platform performance overview',
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ChipGroup(
                options: _tabs,
                selected: _tab,
                onChanged: (v) => setState(() => _tab = v),
              ),
            ),
            const SizedBox(height: 20),
            if (_tab == 'Course Generation') _GenerationTab(),
            if (_tab == 'Learners')          _LearnersTab(),
            if (_tab == 'Content')           _ContentTab(),
            if (_tab == 'AI Tutor')          _AITutorTab(),
          ],
        ),
      ),
    );
  }
}

// ── Course Generation tab ─────────────────────────────────────────────────────

class _GenerationTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(analyticsOverviewProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (ctx, c) {
          final cols = c.maxWidth > 800 ? 3 : 2;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              StatCard(
                title: 'Courses Generated',
                value: overview != null ? '${overview.totalCourses}' : '—',
                icon: Icons.auto_awesome_rounded,
                barColor: ArrestoColors.orange,
                iconColor: ArrestoColors.orange,
              ),
              StatCard(
                title: 'Videos Created',
                value: overview != null ? '${overview.totalVideos}' : '—',
                icon: Icons.videocam_rounded,
                barColor: ArrestoColors.blue,
                iconColor: ArrestoColors.blue,
              ),
              StatCard(
                title: 'Total Learners',
                value: overview != null ? '${overview.totalLearners}' : '—',
                icon: Icons.people_rounded,
                barColor: ArrestoColors.green,
                iconColor: ArrestoColors.green,
              ),
              StatCard(
                title: 'Active Learners',
                value: overview != null ? '${overview.activeLearners}' : '—',
                icon: Icons.person_rounded,
                barColor: ArrestoColors.amber,
                iconColor: ArrestoColors.amber,
              ),
              const StatCard(
                title: 'Avg Gen Time',
                value: '—',
                icon: Icons.timer_rounded,
                barColor: ArrestoColors.blue,
                iconColor: ArrestoColors.blue,
              ),
              StatCard(
                title: 'AI Sessions',
                value: overview != null ? '${overview.totalAiSessions}' : '—',
                icon: Icons.chat_bubble_outline_rounded,
                barColor: ArrestoColors.amber,
                iconColor: ArrestoColors.amber,
              ),
            ],
          );
        }),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (ctx, c) {
          return c.maxWidth > 700
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _StyleBarChart(overview: overview)),
                    const SizedBox(width: 16),
                    Expanded(child: _GenerationLineChart()),
                  ],
                )
              : Column(children: [
                  _StyleBarChart(overview: overview),
                  const SizedBox(height: 16),
                  _GenerationLineChart(),
                ]);
        }),
      ],
    );
  }
}

// ── Style distribution bar chart ──────────────────────────────────────────────

class _StyleBarChart extends StatelessWidget {
  final AnalyticsOverview? overview;
  const _StyleBarChart({this.overview});

  static const _styleKeys = [
    ('modern',           'Free',       ArrestoColors.orange),
    ('animated_scene',   'Animated',   ArrestoColors.amber),
    ('whiteboard_doodle','Whiteboard', ArrestoColors.blue),
    ('hybrid',           'Hybrid',     ArrestoColors.green),
  ];

  @override
  Widget build(BuildContext context) {
    final dist = overview?.styleDistribution ?? {};
    final maxY = dist.values.isEmpty
        ? 10.0
        : (dist.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2)
            .clamp(10.0, double.infinity);

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < _styleKeys.length; i++) {
      final key   = _styleKeys[i].$1;
      final color = _styleKeys[i].$3;
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (dist[key] ?? 0).toDouble(),
            color: color,
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      ));
    }

    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Style Distribution', style: ArrestoText.h4()),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: ArrestoColors.line, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < _styleKeys.length) {
                          return Text(_styleKeys[i].$2, style: ArrestoText.xs());
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) =>
                          Text('${v.toInt()}', style: ArrestoText.xs()),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generation line chart ─────────────────────────────────────────────────────

class _GenerationLineChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(analyticsOverviewProvider).valueOrNull;
    final genData = overview?.generationByMonth ?? [];

    final spots = genData.isEmpty
        ? [const FlSpot(0, 0)]
        : genData
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
            .toList();

    final maxY = genData.isEmpty
        ? 10.0
        : (genData.reduce((a, b) => a > b ? a : b).toDouble() * 1.3)
            .clamp(2.0, double.infinity);

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];

    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generation Over Time', style: ArrestoText.h4()),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: ArrestoColors.line, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < months.length) {
                          return Text(months[i], style: ArrestoText.xs());
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) =>
                          Text('${v.toInt()}', style: ArrestoText.xs()),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: ArrestoColors.amber,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: ArrestoColors.amber.withOpacity(0.1),
                    ),
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

// ── Learners tab ──────────────────────────────────────────────────────────────

class _LearnersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview  = ref.watch(analyticsOverviewProvider).valueOrNull;
    final funnelAsync = ref.watch(funnelProvider);
    final activity  = overview?.learnerActivity ?? [];
    final months    = activity.map((a) => a.month).toList();

    final spots = activity
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.count.toDouble()))
        .toList();

    final maxY = activity.isEmpty
        ? 10.0
        : (activity.map((a) => a.count).reduce((a, b) => a > b ? a : b).toDouble() * 1.3)
            .clamp(2.0, double.infinity);

    return Column(
      children: [
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Learner Activity (last 6 months)', style: ArrestoText.h4()),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (v) =>
                          FlLine(color: ArrestoColors.line, strokeWidth: 1),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < months.length) {
                              return Text(months[i], style: ArrestoText.xs());
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (v, _) =>
                              Text('${v.toInt()}', style: ArrestoText.xs()),
                        ),
                      ),
                      topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                        isCurved: true,
                        color: ArrestoColors.blue,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: ArrestoColors.blue.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Engagement funnel
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.filter_list_rounded,
                    size: 16, color: ArrestoColors.orange),
                const SizedBox(width: 8),
                Text('Engagement Funnel', style: ArrestoText.h4()),
              ]),
              const SizedBox(height: 4),
              Text('Learners progressing through each stage',
                  style: ArrestoText.small(color: ArrestoColors.textMuted)),
              const SizedBox(height: 16),
              funnelAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: ArrestoColors.orange),
                  ),
                ),
                error: (e, _) => Text('Could not load funnel: $e',
                    style: ArrestoText.body(color: ArrestoColors.red)),
                data: (steps) => _FunnelWidget(steps: steps),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FunnelWidget extends StatelessWidget {
  final List<FunnelStep> steps;
  const _FunnelWidget({required this.steps});

  static const _colors = [
    ArrestoColors.orange,
    ArrestoColors.amber,
    ArrestoColors.blue,
    ArrestoColors.green,
  ];

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Text('No data yet — learners appear once they start a lesson.',
          style: ArrestoText.body(color: ArrestoColors.textMuted));
    }

    final maxCount = steps.first.count.toDouble().clamp(1.0, double.infinity);

    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final frac = step.count / maxCount;
        final color = _colors[i % _colors.length];
        final prevCount = i > 0 ? steps[i - 1].count : step.count;
        final dropPct = (prevCount > 0 && i > 0)
            ? ((step.count / prevCount) * 100).round()
            : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(step.label,
                      style: ArrestoText.bodyBold()),
                ),
                Text('${step.count}',
                    style: ArrestoText.h4(color: color)),
                if (dropPct != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: dropPct >= 70
                          ? ArrestoColors.greenSoft
                          : dropPct >= 40
                              ? ArrestoColors.amberSoft
                              : ArrestoColors.redSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$dropPct%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: dropPct >= 70
                            ? ArrestoColors.green
                            : dropPct >= 40
                                ? ArrestoColors.amber
                                : ArrestoColors.red,
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              LayoutBuilder(builder: (_, c) {
                return Stack(children: [
                  Container(
                    width: c.maxWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ArrestoColors.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    width: c.maxWidth * frac,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ]);
              }),
            ],
          ),
        );
      }),
    );
  }
}

// ── Content tab ───────────────────────────────────────────────────────────────

class _ContentTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(courseStatsProvider);

    return statsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: ArrestoColors.orange),
        ),
      ),
      error: (e, _) => ArrestoCard(
        child: Text('Could not load course stats: $e',
            style: ArrestoText.body(color: ArrestoColors.red)),
      ),
      data: (courses) => courses.isEmpty
          ? ArrestoCard(
              child: Text(
                'No course activity yet. Stats appear once learners start lessons.',
                style: ArrestoText.body(color: ArrestoColors.textMuted),
              ),
            )
          : ArrestoCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Row(children: [
                      const Icon(Icons.menu_book_rounded,
                          size: 16, color: ArrestoColors.orange),
                      const SizedBox(width: 8),
                      Text('Per-Course Analytics', style: ArrestoText.h4()),
                      const Spacer(),
                      Text('${courses.length} courses',
                          style: ArrestoText.small(
                              color: ArrestoColors.textMuted)),
                    ]),
                  ),
                  const Divider(height: 1, color: ArrestoColors.line),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Text('Course',
                              style: ArrestoText.smallBold())),
                      Expanded(
                          child: Text('Enrolled',
                              style: ArrestoText.smallBold(),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('Completion',
                              style: ArrestoText.smallBold(),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('Pass Rate',
                              style: ArrestoText.smallBold(),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('Avg Score',
                              style: ArrestoText.smallBold(),
                              textAlign: TextAlign.center)),
                    ]),
                  ),
                  const Divider(height: 1, color: ArrestoColors.line),
                  ...courses.map((c) => _CourseStatRow(item: c)),
                ],
              ),
            ),
    );
  }
}

class _CourseStatRow extends StatelessWidget {
  final CourseStatItem item;
  const _CourseStatRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final passColor = item.passRate >= 0.7
        ? ArrestoColors.green
        : item.passRate >= 0.4
            ? ArrestoColors.amber
            : item.totalAttempts > 0
                ? ArrestoColors.red
                : ArrestoColors.textMuted;

    final compColor = item.completionRate >= 0.7
        ? ArrestoColors.green
        : item.completionRate >= 0.4
            ? ArrestoColors.amber
            : ArrestoColors.textMuted;

    return Container(
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: ArrestoColors.line, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Text(
              item.title,
              style: ArrestoText.bodySm(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              '${item.enrolledLearners}',
              style: ArrestoText.bodyBold(),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              item.enrolledLearners > 0
                  ? '${(item.completionRate * 100).round()}%'
                  : '—',
              style: ArrestoText.bodyBold(color: compColor),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              item.totalAttempts > 0
                  ? '${(item.passRate * 100).round()}%'
                  : '—',
              style: ArrestoText.bodyBold(color: passColor),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              item.totalAttempts > 0 ? '${item.avgScore}%' : '—',
              style: ArrestoText.bodySm(),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── AI Tutor tab ──────────────────────────────────────────────────────────────

class _AITutorTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(tutorStatsProvider);

    return statsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: ArrestoColors.orange),
        ),
      ),
      error: (e, _) => ArrestoCard(
        child: Text('Could not load AI tutor stats: $e',
            style: ArrestoText.body(color: ArrestoColors.red)),
      ),
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI row
          LayoutBuilder(builder: (_, c) {
            return Row(children: [
              Expanded(
                child: _KpiCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  value: '${stats.totalSessions}',
                  label: 'Total Conversations',
                  color: ArrestoColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  icon: Icons.person_rounded,
                  value: '${stats.activeLearners}',
                  label: 'Active Learners (30d)',
                  color: ArrestoColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  icon: Icons.auto_graph_rounded,
                  value: stats.sessionsByMonth.isNotEmpty
                      ? '${stats.sessionsByMonth.last.count}'
                      : '—',
                  label: 'Sessions This Month',
                  color: ArrestoColors.green,
                ),
              ),
            ]);
          }),
          const SizedBox(height: 16),

          // Monthly trend
          ArrestoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sessions per Month', style: ArrestoText.h4()),
                const SizedBox(height: 16),
                _TutorLineChart(data: stats.sessionsByMonth),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Top courses
          if (stats.topCourses.isNotEmpty)
            ArrestoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top Courses by AI Sessions', style: ArrestoText.h4()),
                  const SizedBox(height: 12),
                  ...stats.topCourses.asMap().entries.map((e) {
                    final course = e.value;
                    final max = (stats.topCourses.first['sessions'] as num)
                        .toDouble()
                        .clamp(1.0, double.infinity);
                    final sessions = (course['sessions'] as num).toDouble();
                    final title = course['title'] as String? ?? course['course_id'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                title,
                                style: ArrestoText.bodySm(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${course['sessions']}',
                              style: ArrestoText.smallBold(
                                  color: ArrestoColors.orange),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          LayoutBuilder(builder: (_, c) {
                            return Stack(children: [
                              Container(
                                width: c.maxWidth,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: ArrestoColors.line,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Container(
                                width: c.maxWidth * (sessions / max),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: ArrestoColors.orange,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ]);
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value, style: ArrestoText.h2(color: color)),
          const SizedBox(height: 2),
          Text(label, style: ArrestoText.xs()),
        ],
      ),
    );
  }
}

class _TutorLineChart extends StatelessWidget {
  final List<MonthlyActivity> data;
  const _TutorLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final months = data.map((a) => a.month).toList();
    final spots = data.isEmpty
        ? [const FlSpot(0, 0)]
        : data
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.count.toDouble()))
            .toList();
    final maxY = data.isEmpty
        ? 10.0
        : (data.map((a) => a.count).reduce((a, b) => a > b ? a : b).toDouble() * 1.3)
            .clamp(2.0, double.infinity);

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: ArrestoColors.line, strokeWidth: 1),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < months.length) {
                    return Text(months[i], style: ArrestoText.xs());
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) =>
                    Text('${v.toInt()}', style: ArrestoText.xs()),
              ),
            ),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: ArrestoColors.orange,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: ArrestoColors.orange.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
