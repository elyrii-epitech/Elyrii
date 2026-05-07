import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:characters/characters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../../data/models/gamification_models.dart';
import '../providers/gamification_provider.dart';
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
  // Suivi du défi en cours de démarrage (pour spinner local)
  String? _startingChallengeId;
  String? _processingProposalId;

  // Badges mockés (pas encore de backend pour ça)
  final List<BadgeItem> _badges = [
    const BadgeItem(
      id: '1',
      title: 'Premiers Pas',
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
      title: 'Zen Master',
      icon: Icons.spa_rounded,
      isUnlocked: false,
    ),
    const BadgeItem(
      id: '4',
      title: 'Bavard',
      icon: Icons.record_voice_over_rounded,
      isUnlocked: false,
    ),
    const BadgeItem(
      id: '5',
      title: 'Night Owl',
      icon: Icons.nights_stay_rounded,
      isUnlocked: false,
    ),
    const BadgeItem(
      id: '6',
      title: 'Early Bird',
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

    // Streak dérivé du nombre de défis actifs (placeholder jusqu'à /user/stats branché)
    final streakDays = provider.activeChallenges.length;

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
                            subtitle: uc.displayDescription.characters.length > 40
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
                            subtitle: uc.displayDescription.characters.length > 40
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
        fontSize: 20,
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
