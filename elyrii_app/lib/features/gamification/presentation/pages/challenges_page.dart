import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
  String? _startingChallengeId;
  String? _processingProposalId;

  static const List<BadgeItem> _badges = [
    BadgeItem(
      id: '1',
      title: 'Premier pas',
      icon: Icons.directions_walk_rounded,
      isUnlocked: true,
    ),
    BadgeItem(
      id: '2',
      title: 'Explorateur',
      icon: Icons.explore_rounded,
      isUnlocked: true,
    ),
    BadgeItem(
      id: '3',
      title: 'Pleine conscience',
      icon: Icons.spa_rounded,
      isUnlocked: false,
    ),
    BadgeItem(
      id: '4',
      title: 'Écoute active',
      icon: Icons.hearing_rounded,
      isUnlocked: false,
    ),
    BadgeItem(
      id: '5',
      title: 'Étoile du soir',
      icon: Icons.nights_stay_rounded,
      isUnlocked: false,
    ),
    BadgeItem(
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

    final streakDays = dashboardProvider.currentStreak;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
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
                      _buildGardenHeader(isDark),
                      const SizedBox(height: 20),
                      LevelProgressHeader(
                        level: 1 + provider.completedChallenges.length ~/ 3,
                        currentXp: provider.completedChallenges.length * 50,
                        maxXp: 150,
                        title: 'Explorateur de l\'esprit',
                      ),
                      const SizedBox(height: 16),
                      DailyStreakCard(
                        streakDays: streakDays,
                        weekHistory: List.generate(
                          7,
                          (i) => i < streakDays,
                        ),
                      ),
                      const SizedBox(height: 32),
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
                            subtitle: _shortDescription(uc.displayDescription),
                            icon: uc.displayIcon,
                            xpReward: 0,
                            isCompleted: false,
                            progressFraction: uc.progressFraction,
                            progressText: uc.progressText,
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (provider.completedChallenges.isNotEmpty) ...[
                        _sectionTitle(context, 'Terminés', isDark),
                        const SizedBox(height: 12),
                        ...provider.completedChallenges.map(
                          (uc) => QuestTile(
                            title: uc.displayTitle,
                            subtitle: _shortDescription(uc.displayDescription),
                            icon: uc.displayIcon,
                            xpReward: 50,
                            isCompleted: true,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
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

  String _shortDescription(String description) {
    const maxLength = 40;
    if (description.characters.length <= maxLength) return description;
    return '${description.characters.take(maxLength)}…';
  }

  Widget _buildGardenHeader(bool isDark) {
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final bodyColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: isDark ? 0.28 : 0.34),
            ),
          ),
          child: Text(
            'Atelier de présence',
            style: AppTextStyles.labelSmall(
              color: isDark ? AppColors.accentDark : AppColors.successDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ton jardin intérieur',
          style: AppTextStyles.headlineSmall(
            color: titleColor,
            fontWeight: FontWeight.w800,
          ).copyWith(height: 1.08),
        ),
        const SizedBox(height: 8),
        Text(
          'Cultive tes rituels, tes progrès doux et tes défis personnels.',
          style: AppTextStyles.bodySmall(color: bodyColor).copyWith(
            height: 1.45,
          ),
        ),
      ],
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
