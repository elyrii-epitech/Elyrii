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
  final int _currentLevel = 3;
  final int _currentXp = 340;
  final int _maxXp = 500;
  final int _streakDays = 5;
  final List<bool> _weekHistory = [true, true, true, true, true, false, false];

  final List<Map<String, dynamic>> _quests = [
    {
      'title': 'Mediter 10 minutes',
      'subtitle': 'Un moment rien que pour toi',
      'icon': Icons.self_improvement_rounded,
      'xp': 50,
      'isCompleted': true,
    },
    {
      'title': 'Discuter avec Elyrii',
      'subtitle': 'Elyrii est la pour t\'ecouter',
      'icon': Icons.chat_bubble_outline_rounded,
      'xp': 30,
      'isCompleted': false,
    },
    {
      'title': 'Noter ton humeur',
      'subtitle': 'Pose-tou quelques instants',
      'icon': Icons.mood_rounded,
      'xp': 20,
      'isCompleted': false,
    },
  ];

  final List<BadgeItem> _badges = [
    const BadgeItem(
      id: '1',
      title: 'Premier pas',
      icon: Icons.directions_walk_rounded,
      isUnlocked: true,
    ),
    const BadgeItem(
      id: '2',
      title: 'Explorateur',
      icon: Icons.explore_rounded,
      isUnlocked: true,
    ),
    const BadgeItem(
      id: '3',
      title: 'Pleine conscience',
      icon: Icons.spa_rounded,
      isUnlocked: false,
    ),
    const BadgeItem(
      id: '4',
      title: 'Ecoute active',
      icon: Icons.hearing_rounded,
      isUnlocked: false,
    ),
    const BadgeItem(
      id: '5',
      title: 'Etoile du soir',
      icon: Icons.nights_stay_rounded,
      isUnlocked: false,
    ),
    const BadgeItem(
      id: '6',
      title: 'Lumiere du matin',
      icon: Icons.wb_sunny_rounded,
      isUnlocked: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 16,
            16,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mascot greeting
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      Text(
                        '💜',
                        style: const TextStyle(fontSize: 36),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ton espace bien-etre',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ici, il n\'y a rien a accomplir.\nJuste etre, a ton rythme.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Emotional state card
              LevelProgressHeader(
                level: _currentLevel,
                currentXp: _currentXp,
                maxXp: _maxXp,
                title: '',
              ),

              const SizedBox(height: 16),

              // Week mood
              DailyStreakCard(
                streakDays: _streakDays,
                weekHistory: _weekHistory,
              ),

              const SizedBox(height: 32),

              // Gentle invitations
              _buildSectionTitle('Souffles du jour', isDark),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Des petites idees pour prendre soin de toi, si tu en as envie',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
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
                    onTap: () {},
                  );
                },
              ),

              const SizedBox(height: 32),

              // Emotional skills
              _buildSectionTitle('Tes competences emotionnelles', isDark),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Des qualites qui se developpent avec le temps',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
              BadgesGrid(
                badges: _badges,
                onBadgeTap: (badge) => _showBadgeDetails(context, badge),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeItem badge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showLiquidGlassDialog(
      context: context,
      title: badge.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.isUnlocked
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03)),
            ),
            child: Icon(
              badge.isUnlocked ? badge.icon : Icons.hourglass_empty_rounded,
              size: 28,
              color: badge.isUnlocked
                  ? AppColors.primary
                  : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            badge.isUnlocked
                ? 'Tu as developpe cette belle competence.\nElle fait maintenant partie de toi.'
                : 'Cette qualite grandit en toi,\npetit a petit, a ton rythme.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
      actions: [
        LiquidGlassDialogAction(
          label: 'Merci',
          isDefault: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
