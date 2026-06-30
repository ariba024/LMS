import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/gamification_service.dart';
import '../../../data/models/gamification.dart';

class LeaderboardScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String learnerId;

  const LeaderboardScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.learnerId,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry> _entries = [];
  GamificationProfile? _myProfile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        gamificationService.getLeaderboard(widget.courseId),
        gamificationService.getProfile(widget.learnerId, widget.courseId),
      ]);
      setState(() {
        _entries = results[0] as List<LeaderboardEntry>;
        _myProfile = results[1] as GamificationProfile;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrestoColors.background,
      appBar: AppBar(
        backgroundColor: ArrestoColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leaderboard',
                style: ArrestoText.base(color: ArrestoColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700)),
            Text(widget.courseTitle,
                style: ArrestoText.xs(color: ArrestoColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: ArrestoColors.red),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: ArrestoText.small(
                              color: ArrestoColors.textMuted)),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(
                              backgroundColor: ArrestoColors.amber,
                              foregroundColor: ArrestoColors.ink),
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : _entries.isEmpty
                  ? _EmptyLeaderboard(onRefresh: _load)
                  : _LeaderboardList(
                      entries: _entries,
                      myProfile: _myProfile,
                      learnerId: widget.learnerId,
                    ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final GamificationProfile? myProfile;
  final String learnerId;

  const _LeaderboardList({
    required this.entries,
    required this.myProfile,
    required this.learnerId,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // My stats card
        if (myProfile != null)
          SliverToBoxAdapter(
            child: _MyStatsCard(profile: myProfile!),
          ),

        // Top 3 podium
        if (entries.length >= 3)
          SliverToBoxAdapter(
            child: _Podium(entries: entries.take(3).toList()),
          ),

        // Full list
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final e = entries[i];
                final isMe = e.learnerId == learnerId;
                return _LeaderRow(entry: e, isMe: isMe);
              },
              childCount: entries.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _MyStatsCard extends StatelessWidget {
  final GamificationProfile profile;
  const _MyStatsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1B1D), Color(0xFF2D2D30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: ArrestoColors.sh3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Your Progress',
                  style: ArrestoText.small(color: Colors.white70)
                      .copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (profile.rank != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _rankColor(profile.rank!).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _rankColor(profile.rank!)),
                  ),
                  child: Text(
                    'Rank #${profile.rank}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _rankColor(profile.rank!),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniStat(
                  label: 'Total XP',
                  value: profile.totalXp.toString(),
                  color: ArrestoColors.amber),
              _MiniStat(
                  label: 'Daily Q',
                  value: '${profile.dailyQXp} XP',
                  color: ArrestoColors.blue),
              _MiniStat(
                  label: 'Hazards',
                  value: '${profile.hazardXp} XP',
                  color: ArrestoColors.green),
              _MiniStat(
                  label: 'Streak',
                  value: '🔥 ${profile.dailyQStreak}d',
                  color: ArrestoColors.amberStrong),
            ],
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.white60;
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: ArrestoText.xs(color: Colors.white54)),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (entries.length > 1)
            Expanded(child: _PodiumBlock(entry: entries[1], height: 80)),
          Expanded(child: _PodiumBlock(entry: entries[0], height: 110)),
          if (entries.length > 2)
            Expanded(child: _PodiumBlock(entry: entries[2], height: 60)),
        ],
      ),
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height;
  const _PodiumBlock({required this.entry, required this.height});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final rankColor = entry.rank <= 3 ? colors[entry.rank - 1] : Colors.grey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.displayName.split(' ').first,
          style: ArrestoText.xs(color: ArrestoColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text('${entry.totalXp} XP',
            style: ArrestoText.xs(color: ArrestoColors.textMuted)),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: rankColor.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              entry.rank == 1 ? '🥇' : entry.rank == 2 ? '🥈' : '🥉',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  const _LeaderRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rankColor = entry.rank == 1
        ? const Color(0xFFFFD700)
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : entry.rank == 3
                ? const Color(0xFFCD7F32)
                : ArrestoColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? ArrestoColors.amberSoft : ArrestoColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe ? ArrestoColors.amberStrong : ArrestoColors.cardBorder,
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: isMe ? ArrestoColors.sh1 : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isMe ? ArrestoColors.amberStrong : ArrestoColors.bg2,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.displayName.isNotEmpty
                    ? entry.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isMe ? Colors.white : ArrestoColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${entry.displayName} (You)' : entry.displayName,
                  style: ArrestoText.base(color: ArrestoColors.textPrimary)
                      .copyWith(fontWeight: isMe ? FontWeight.w700 : FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.dailyQStreak > 1)
                  Text('🔥 ${entry.dailyQStreak} day streak',
                      style: ArrestoText.xs(color: ArrestoColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry.totalXp} XP',
                  style: ArrestoText.base(color: ArrestoColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700)),
              Text(
                '${entry.dailyQXp}Q + ${entry.hazardXp}H',
                style: ArrestoText.xs(color: ArrestoColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyLeaderboard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.leaderboard_rounded,
                size: 56, color: ArrestoColors.lineStrong),
            const SizedBox(height: 16),
            Text('No rankings yet',
                style: ArrestoText.xl(color: ArrestoColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Complete daily questions and spot the hazard challenges to appear on the leaderboard.',
              style: ArrestoText.base(color: ArrestoColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRefresh,
              style: FilledButton.styleFrom(
                  backgroundColor: ArrestoColors.amber,
                  foregroundColor: ArrestoColors.ink),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
