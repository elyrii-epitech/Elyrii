import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../providers/gamification_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../widgets/level_progress_header.dart';
import '../widgets/daily_streak_card.dart';
import '../widgets/quest_tile.dart';
import '../widgets/challenge_card.dart';
import '../widgets/ai_proposal_card.dart';
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
      'title': 'Méditer 10 minutes',
      'subtitle': 'Un moment rien que pour toi',
      'icon': Icons.self_improvement_rounded,
      'xp': 50,
      'isCompleted': true,
    },
    {
      'title': 'Discuter avec Elyrii',
      'subtitle': 'Elyrii est là pour t\'écouter',
      'icon': Icons.chat_bubble_outline_rounded,
      'xp': 30,
      'isCompleted': false,
    },
    {
      'title': 'Noter ton humeur',
      'subtitle': 'Pose-toi quelques instants',
      'icon': Icons.mood_rounded,
      'xp': 20,
      'isCompleted': false,
    },
  ];

  // Suivi du défi en cours de démarrage (pour spinner local)
  String? _startingChallengeId;
  String? _processingProposalId;

  // Badges mockés (pas encore de backend pour ça)
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
      title: 'Écoute active',
      icon: Icons.hearing_rounded,
      isUnlocked: false,
    ),
    const BadgeItem(
      id: '5',
      title: 'Étoile du soir',
      icon: Icons.nights_stay_rounded,
      isUnlocked: false,
    ),
    const BadgeItem(
      id: '6',
      title: 'Lumière du matin',
      icon: Icons.wb_sunny_rounded,
      isUnlocked: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamificationProvider>().loadAll();
    });
  }

  Future<void> _handleStart(String challengeId) async {
    setState(() => _startingChallengeId = challengeId);
    await context.read<GamificationProvider>().startChallenge(challengeId);
    if (mounted) setState(() => _startingChallengeId = null);
  }

  Future<void> _handleAcceptProposal(String proposalId) async {
    setState(() => _processingProposalId = proposalId);
    await context.read<GamificationProvider>().acceptChallenge(proposalId);
    if (mounted) setState(() => _processingProposalId = null);
  }

  Future<void> _handleRejectProposal(String proposalId) async {
    setState(() => _processingProposalId = proposalId);
    await context.read<GamificationProvider>().rejectChallenge(proposalId);
    if (mounted) setState(() => _processingProposalId = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<GamificationProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();

    // Use real streak from dashboard provider
    final streakDays = dashboardProvider.currentStreak;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: Stack(
        children: [
          // Aurora Background Glow 1 (Top Left)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary
                        .withValues(alpha: isDark ? 0.08 : 0.04),
                    blurRadius: 130,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          // Aurora Background Glow 2 (Mid Right)
          Positioned(
            top: 350,
            right: -120,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent
                        .withValues(alpha: isDark ? 0.06 : 0.03),
                    blurRadius: 140,
                    spreadRadius: 70,
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
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
                          const Icon(Icons.yard_rounded,
                              color: AppColors.primary, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Ton jardin intérieur',
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
                            'Ici, il n\'y a rien à accomplir.\nJuste être, à ton rythme.',
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
                  _buildSectionTitle('Douces invitations', isDark),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Des inspirations douces pour prendre soin de toi, sans aucune obligation',
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
                  _buildSectionTitle('Tes compétences émotionnelles', isDark),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Des qualités qui se développent avec le temps',
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
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
      body: RefreshIndicator(
        onRefresh: () => provider.loadAll(),
        color: AppColors.primary,
        child: provider.isLoading && provider.activeChallenges.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
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
                      // Header niveau (mock — sera connecté quand /user/stats est branché)
                      LevelProgressHeader(
                        level: 1 + provider.completedChallenges.length ~/ 3,
                        currentXp: provider.completedChallenges.length * 50,
                        maxXp: 150,
                        title: 'Explorateur de l\'esprit',
                      ),

                      const SizedBox(height: 16),

                      // Streak
                      DailyStreakCard(
                        streakDays: streakDays,
                        weekHistory: List.generate(
                          7,
                          (i) => i < streakDays,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Propositions IA ────────────────────────────
                      if (provider.proposals.isNotEmpty) ...[
                        _sectionTitle(context, 'Propositions IA', isDark),
                        const SizedBox(height: 12),
                        ...provider.proposals.map(
                          (proposal) => AiProposalCard(
                            proposal: proposal,
                            isProcessing: _processingProposalId == proposal.id,
                            onAccept: () => _handleAcceptProposal(proposal.id),
                            onReject: () => _handleRejectProposal(proposal.id),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Défis disponibles ──────────────────────────
                      if (provider.availableChallenges.isNotEmpty) ...[
                        _sectionTitle(context, 'Défis disponibles', isDark),
                        const SizedBox(height: 12),
                        ...provider.availableChallenges.map(
                          (challenge) => ChallengeAvailableCard(
                            challenge: challenge,
                            isStarting: _startingChallengeId == challenge.id,
                            onStart: () => _handleStart(challenge.id),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── En cours ──────────────────────────────────
                      _sectionTitle(context, 'En cours', isDark),
                      const SizedBox(height: 12),
                      if (provider.activeChallenges.isEmpty)
                        _emptyState(
                          context,
                          isDark,
                          'Aucun défi en cours\nCommence un défi ci-dessus !',
                          Icons.flag_outlined,
                        )
                      else
                        ...provider.activeChallenges.map(
                          (uc) => QuestTile(
                            title: uc.displayTitle,
                            subtitle: uc.displayDescription.characters.length >
                                    40
                                ? '${uc.displayDescription.characters.take(40).toString()}…'
                                : uc.displayDescription,
                            icon: uc.displayIcon,
                            xpReward: 0,
                            isCompleted: false,
                            progressFraction: uc.progressFraction,
                            progressText: uc.progressText,
                          ),
                        ),

                      const SizedBox(height: 32),

                      // ── Terminés ──────────────────────────────────
                      if (provider.completedChallenges.isNotEmpty) ...[
                        _sectionTitle(context, 'Terminés', isDark),
                        const SizedBox(height: 12),
                        ...provider.completedChallenges.map(
                          (uc) => QuestTile(
                            title: uc.displayTitle,
                            subtitle: uc.displayDescription.characters.length >
                                    40
                                ? '${uc.displayDescription.characters.take(40).toString()}…'
                                : uc.displayDescription,
                            icon: uc.displayIcon,
                            xpReward: 50,
                            isCompleted: true,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ── Trophées & Badges ─────────────────────────
                      _sectionTitle(context, 'Trophées & Badges', isDark),
                      const SizedBox(height: 16),
                      BadgesGrid(
                        badges: _badges,
                        onBadgeTap: (badge) =>
                            _showBadgeDetails(context, badge),
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }

  Widget _emptyState(
    BuildContext context,
    bool isDark,
    String message,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
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
                ? 'Tu as développé cette belle compétence.\nElle fait maintenant partie de toi.'
                : 'Cette qualité grandit en toi,\npetit à petit, à ton rythme.',
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
