import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../widgets/level_progress_header.dart';
import '../widgets/daily_streak_card.dart';
import '../widgets/quest_tile.dart';
import '../widgets/badges_grid.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  // Mock Data
  final int _currentLevel = 3;
  final int _currentXp = 340;
  final int _maxXp = 500;
  final int _streakDays = 5;
  final List<bool> _weekHistory = [true, true, true, true, true, false, false];

  // Mock Quests
  final List<Map<String, dynamic>> _quests = [
    {
      'title': 'Méditer 10 minutes',
      'subtitle': 'Prends un moment pour toi',
      'icon': Icons.self_improvement_rounded,
      'xp': 50,
      'isCompleted': true,
    },
    {
      'title': 'Discuter avec Elyrii',
      'subtitle': 'Partage une pensée',
      'icon': Icons.chat_bubble_outline_rounded,
      'xp': 30,
      'isCompleted': false,
    },
    {
      'title': 'Noter mon humeur',
      'subtitle': 'Comment te sens-tu ?',
      'icon': Icons.mood_rounded,
      'xp': 20,
      'isCompleted': false,
    },
  ];

  // Mock Badges
  final List<BadgeItem> _badges = [
    BadgeItem(
        id: '1',
        title: 'Premiers Pas',
        icon: Icons.directions_walk_rounded,
        isUnlocked: true),
    BadgeItem(
        id: '2',
        title: 'Explorateur',
        icon: Icons.explore_rounded,
        isUnlocked: true),
    BadgeItem(
        id: '3',
        title: 'Zen Master',
        icon: Icons.spa_rounded,
        isUnlocked: false),
    BadgeItem(
        id: '4',
        title: 'Bavard',
        icon: Icons.record_voice_over_rounded,
        isUnlocked: false),
    BadgeItem(
        id: '5',
        title: 'Night Owl',
        icon: Icons.nights_stay_rounded,
        isUnlocked: false),
    BadgeItem(
        id: '6',
        title: 'Early Bird',
        icon: Icons.wb_sunny_rounded,
        isUnlocked: false),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              LevelProgressHeader(
                level: _currentLevel,
                currentXp: _currentXp,
                maxXp: _maxXp,
                title: 'Explorateur de l\'esprit',
              ),

              const SizedBox(height: 16),

              // Streak
              DailyStreakCard(
                streakDays: _streakDays,
                weekHistory: _weekHistory,
              ),

              const SizedBox(height: 32),

              // Quests Section
              _buildSectionTitle(context, 'Quêtes du Jour', isDark),
              const SizedBox(height: 16),
              ListView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _quests.length,
                itemBuilder: (context, index) {
                  final quest = _quests[index];
                  return QuestTile(
                    title: quest['title'],
                    subtitle: quest['subtitle'],
                    icon: quest['icon'],
                    xpReward: quest['xp'],
                    isCompleted: quest['isCompleted'],
                    onTap: () {
                      // Handle tap
                    },
                  );
                },
              ),

              const SizedBox(height: 32),

              // Badges Section
              _buildSectionTitle(context, 'Trophées & Badges', isDark),
              const SizedBox(height: 16),
              BadgesGrid(
                badges: _badges,
                onBadgeTap: (badge) => _showBadgeDetails(context, badge),
              ),

              const SizedBox(height: 80), // Bottom padding for nav bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeItem badge) {
    showLiquidGlassDialog(
      context: context,
      title: badge.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badge.isUnlocked ? badge.icon : Icons.lock_outline_rounded,
            size: 48,
            color: badge.isUnlocked
                ? AppColors.primary
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(height: 16),
          Text(
            badge.isUnlocked
                ? 'Félicitations ! Vous avez débloqué ce badge.'
                : 'Continuez vos efforts pour débloquer ce badge mystère !',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        LiquidGlassDialogAction(
          label: 'Fermer',
          isDefault: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
