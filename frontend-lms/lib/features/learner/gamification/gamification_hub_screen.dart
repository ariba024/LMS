import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/gamification_service.dart';
import '../../../data/models/gamification.dart';
import 'daily_question_screen.dart';
import 'spot_the_hazard_screen.dart';
import 'leaderboard_screen.dart';

class GamificationHubScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String learnerId;

  const GamificationHubScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.learnerId,
  });

  @override
  State<GamificationHubScreen> createState() => _GamificationHubScreenState();
}

class _GamificationHubScreenState extends State<GamificationHubScreen> {
  GamificationProfile? _profile;
  DailyQuestion? _dailyQ;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        gamificationService
            .getProfile(widget.learnerId, widget.courseId)
            .catchError((_) => GamificationProfile(
                  learnerId: widget.learnerId,
                  courseId: widget.courseId,
                  displayName: widget.learnerId,
                  totalXp: 0,
                  dailyQXp: 0,
                  hazardXp: 0,
                  dailyQStreak: 0,
                )),
        gamificationService
            .getDailyQuestion(widget.courseId, widget.learnerId)
            .then<DailyQuestion?>((q) => q)
            .catchError((_) => null as DailyQuestion?),
      ]);
      setState(() {
        _profile = results[0] as GamificationProfile;
        _dailyQ = results[1] as DailyQuestion?;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
            Text('Gamification',
                style: ArrestoText.base(color: ArrestoColors.ink)
                    .copyWith(fontWeight: FontWeight.w700)),
            Text(widget.courseTitle,
                style: ArrestoText.xs(color: ArrestoColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // XP card
                  if (_profile != null) _XpCard(profile: _profile!),
                  const SizedBox(height: 24),

                  Text('ACTIVITIES',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ArrestoColors.textMuted2,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 12),

                  // Daily Question card
                  _ActivityCard(
                    icon: Icons.lightbulb_rounded,
                    iconColor: ArrestoColors.amberStrong,
                    iconBg: ArrestoColors.amberSoft,
                    title: 'Question of the Day',
                    subtitle: _dailyQ?.alreadyAttempted == true
                        ? 'Completed today · come back tomorrow'
                        : 'Answer today\'s safety question · +20 XP',
                    badge: _dailyQ?.alreadyAttempted == true
                        ? null
                        : 'NEW',
                    badgeColor: ArrestoColors.green,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DailyQuestionScreen(
                          courseId: widget.courseId,
                          learnerId: widget.learnerId,
                          courseTitle: widget.courseTitle,
                        ),
                      )).then((_) => _load());
                    },
                  ),
                  const SizedBox(height: 10),

                  // Spot the Hazard card
                  _ActivityCard(
                    icon: Icons.search_rounded,
                    iconColor: ArrestoColors.orange,
                    iconBg: ArrestoColors.orangeTint,
                    title: 'Spot the Hazard',
                    subtitle: 'Find safety hazards in AI-generated scenes · up to 100 XP',
                    badge: 'AI',
                    badgeColor: ArrestoColors.blue,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SpotTheHazardScreen(
                          courseId: widget.courseId,
                          learnerId: widget.learnerId,
                          courseTitle: widget.courseTitle,
                        ),
                      )).then((_) => _load());
                    },
                  ),
                  const SizedBox(height: 10),

                  // Leaderboard card
                  _ActivityCard(
                    icon: Icons.leaderboard_rounded,
                    iconColor: ArrestoColors.blue,
                    iconBg: ArrestoColors.blueSoft,
                    title: 'Leaderboard',
                    subtitle: 'See how you rank against other learners',
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LeaderboardScreen(
                          courseId: widget.courseId,
                          courseTitle: widget.courseTitle,
                          learnerId: widget.learnerId,
                        ),
                      )).then((_) => _load());
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _XpCard extends StatelessWidget {
  final GamificationProfile profile;
  const _XpCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Text('Your XP',
                  style: ArrestoText.small(color: Colors.white70)
                      .copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (profile.rank != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.6)),
                  ),
                  child: Text('Rank #${profile.rank}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${profile.totalXp} XP',
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _XpPill(
                  label: 'Daily Q',
                  value: '${profile.dailyQXp}',
                  color: Colors.amber),
              const SizedBox(width: 8),
              _XpPill(
                  label: 'Hazards',
                  value: '${profile.hazardXp}',
                  color: Colors.greenAccent),
              const SizedBox(width: 8),
              if (profile.dailyQStreak > 0)
                _XpPill(
                    label: 'Streak',
                    value: '🔥 ${profile.dailyQStreak}d',
                    color: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _XpPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _XpPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('$label: $value',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ArrestoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArrestoColors.cardBorder),
          boxShadow: ArrestoColors.sh1,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: ArrestoText.base(color: ArrestoColors.ink)
                              .copyWith(fontWeight: FontWeight.w700)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor!.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: badgeColor!.withOpacity(0.5)),
                          ),
                          child: Text(badge!,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: ArrestoText.xs(color: ArrestoColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: ArrestoColors.textMuted2),
          ],
        ),
      ),
    );
  }
}
