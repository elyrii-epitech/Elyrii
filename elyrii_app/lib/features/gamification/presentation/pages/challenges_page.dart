import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../../../../core/widgets/mascot_3d_viewer.dart';
import '../../../../routes/app_routes.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
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
                      // Mascot greeting premium header
                      _buildGardenHero(isDark),
                      const SizedBox(height: 20),

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

  Widget _buildGardenHero(bool isDark) {
    return Consumer<MascotProvider>(
      builder: (context, provider, _) {
        final equippedCount = provider.mascot.equippedCosmetics.length;
        final selectedColor =
            equippedCount > 0 ? AppColors.accent : AppColors.primary;

        return LiquidGlassCard(
          onTap: () => _openMascotCustomization(context),
          padding: EdgeInsets.zero,
          borderRadius: 28,
          color: isDark
              ? AppColors.liquidGlassBackgroundDark
              : AppColors.liquidGlassBackgroundLight,
          borderColor: selectedColor.withValues(alpha: isDark ? 0.28 : 0.38),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned(
                  top: -72,
                  right: -34,
                  child: _buildHeroGlow(
                    selectedColor.withValues(alpha: isDark ? 0.22 : 0.18),
                    180,
                  ),
                ),
                Positioned(
                  bottom: -72,
                  left: -42,
                  child: _buildHeroGlow(
                    AppColors.secondary.withValues(
                      alpha: isDark ? 0.16 : 0.13,
                    ),
                    160,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 340;
                      final textBlock = _buildHeroText(
                        context,
                        isDark,
                        equippedCount,
                      );
                      final mascotPreview = _buildHeroMascotPreview(
                        selectedColor,
                        isDark,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: mascotPreview,
                            ),
                            const SizedBox(height: 12),
                            textBlock,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: textBlock),
                          const SizedBox(width: 12),
                          mascotPreview,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroText(
    BuildContext context,
    bool isDark,
    int equippedCount,
  ) {
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
          'Ajuste la présence d’Elyrii ici, au même endroit que tes rituels et tes progrès doux.',
          style: AppTextStyles.bodySmall(color: bodyColor).copyWith(
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildStatusPill(
              icon: Icons.auto_awesome_rounded,
              label: _equippedDetailsLabel(equippedCount),
              isDark: isDark,
            ),
            _buildCustomizeButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final color =
        isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.74),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizeButton(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openMascotCustomization(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          gradient: AppColors.chatbotGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Personnaliser Elyrii',
              style: AppTextStyles.labelSmall(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMascotPreview(Color selectedColor, bool isDark) {
    return SizedBox(
      width: 118,
      height: 136,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selectedColor.withValues(alpha: isDark ? 0.14 : 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.72),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: selectedColor.withValues(alpha: isDark ? 0.22 : 0.18),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const Positioned(
            bottom: 0,
            child: Mascot3DViewer(
              config: Mascot3DConfig(
                autoRotateSpeed: 8,
                interactionEnabled: false,
                showLoadingIndicator: false,
              ),
              width: 112,
              height: 126,
            ),
          ),
          Positioned(
            top: 14,
            right: 10,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.84),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.78),
                ),
              ),
              child: Icon(
                Icons.brush_rounded,
                size: 14,
                color: selectedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size * 0.32,
            spreadRadius: size * 0.12,
          ),
        ],
      ),
    );
  }

  String _equippedDetailsLabel(int count) {
    if (count == 0) return 'Présence naturelle';
    if (count == 1) return '1 détail équipé';
    return '$count détails équipés';
  }

  void _openMascotCustomization(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, AppRoutes.mascotCustomization);
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
