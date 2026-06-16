import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/chip_group.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/section_header.dart';

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
            if (_tab == 'Learners') _LearnersTab(),
            if (_tab == 'Content') _ContentTab(),
            if (_tab == 'AI Tutor') _AITutorTab(),
          ],
        ),
      ),
    );
  }
}

class _GenerationTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            children: const [
              StatCard(
                title: 'Courses Generated',
                value: '142',
                icon: Icons.auto_awesome_rounded,
                barColor: ArrestoColors.orange,
                iconColor: ArrestoColors.orange,
              ),
              StatCard(
                title: 'Videos Created',
                value: '968',
                icon: Icons.videocam_rounded,
                barColor: ArrestoColors.blue,
                iconColor: ArrestoColors.blue,
              ),
              StatCard(
                title: 'Learning Hours',
                value: '312h',
                icon: Icons.schedule_rounded,
                barColor: ArrestoColors.green,
                iconColor: ArrestoColors.green,
              ),
              StatCard(
                title: 'AI Credits Used',
                value: '48.2k',
                icon: Icons.token_rounded,
                barColor: ArrestoColors.amber,
                iconColor: ArrestoColors.amber,
              ),
              StatCard(
                title: 'Avg Gen Time',
                value: '3m 40s',
                icon: Icons.timer_rounded,
                barColor: ArrestoColors.blue,
                iconColor: ArrestoColors.blue,
              ),
              StatCard(
                title: 'Regenerated',
                value: '64',
                icon: Icons.refresh_rounded,
                barColor: ArrestoColors.textMuted,
                iconColor: ArrestoColors.textMuted,
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
                    Expanded(child: _StyleBarChart()),
                    const SizedBox(width: 16),
                    Expanded(child: _GenerationLineChart()),
                  ],
                )
              : Column(children: [
                  _StyleBarChart(),
                  const SizedBox(height: 16),
                  _GenerationLineChart(),
                ]);
        }),
      ],
    );
  }
}

class _StyleBarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                maxY: 60,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 20,
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
                        const labels = [
                          'Animated',
                          'Whiteboard',
                          'AI Style',
                          'Hybrid',
                        ];
                        if (v.toInt() < labels.length) {
                          return Text(labels[v.toInt()],
                              style: ArrestoText.xs());
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
                barGroups: [
                  _bar(0, 52, ArrestoColors.amber),
                  _bar(1, 38, ArrestoColors.blue),
                  _bar(2, 30, ArrestoColors.orange),
                  _bar(3, 22, ArrestoColors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 24,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        )
      ],
    );
  }
}

class _GenerationLineChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 5,
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
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                        if (v.toInt() < months.length) {
                          return Text(months[v.toInt()],
                              style: ArrestoText.xs());
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
                    spots: const [
                      FlSpot(0, 8),
                      FlSpot(1, 12),
                      FlSpot(2, 10),
                      FlSpot(3, 18),
                      FlSpot(4, 22),
                      FlSpot(5, 24),
                    ],
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

class _LearnersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learner Activity', style: ArrestoText.h4()),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
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
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                        if (v.toInt() < months.length) {
                          return Text(months[v.toInt()], style: ArrestoText.xs());
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
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 900), FlSpot(1, 950), FlSpot(2, 1020),
                      FlSpot(3, 1100), FlSpot(4, 1150), FlSpot(5, 1284),
                    ],
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
    );
  }
}

class _ContentTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Text('Content analytics coming soon', style: ArrestoText.body()),
    );
  }
}

class _AITutorTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ArrestoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Tutor Usage', style: ArrestoText.h4()),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('3,420', 'Total Conversations'),
              const SizedBox(width: 12),
              _kpi('4.8', 'Avg Rating'),
              const SizedBox(width: 12),
              _kpi('92%', 'Resolution Rate'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ArrestoColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArrestoColors.line),
        ),
        child: Column(
          children: [
            Text(value, style: ArrestoText.h2()),
            Text(label, style: ArrestoText.xs(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
