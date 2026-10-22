import '../../../../core/accessibility/motion.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../providers/gamification_provider.dart';
import '../widgets/challenge_sections.dart';
import '../widgets/badges_grid.dart';
import '../widgets/daily_streak_card.dart';

/// Jardin — Sanctuaire de progression visuelle, rituels et réussites.
///
/// Refonte Apple HIG & Liquid Glass (Septembre 2026) :
/// - Suppression de [SliverAppBar.large] et de son vide supérieur noir.
/// - En-tête spatial fluide avec micro-sur-titre « MON JARDIN », grand titre
///   « Jardin » et pilule de floraison interactive.
/// - Carte Héroïque « Jardin Intérieur » affichant l'éveil botanique, le niveau,
///   l'XP et la série de présence.
/// - Passerelle limpide avec le Coach IA : « Le Coach sème, le Jardin fleurit ».
/// - Deux segments clairs (« Mes Quêtes » / « Mes Succès ») avec retour haptique.
/// - Tirer-relâcher natif Cupertino ([CupertinoSliverRefreshControl]).
class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  String? _startingChallengeId;
  String? _processingProposalId;
  GamificationProvider? _observedGamificationProvider;
  int _lastCompletedCount = -1;

  /// Segment principal : 0 = Mes Quêtes, 1 = Mes Succès.
  int _mainSegment = 0;

  /// Sous-segment Succès : 0 = Badges & Trophées, 1 = Historique.
  int _successesSubSegment = 0;

  List<BadgeItem> get _badges {
    final completed = context
        .watch<GamificationProvider>()
        .completedChallenges
        .length;
    const milestones = [1, 3, 7, 12, 24, 36];
    const titles = [
      'Premier pas',
      'Explorateur',
      'Persévérance',
      'Élan',
      'Épanouissement',
      'Jardin accompli',
    ];
    return List.generate(
      milestones.length,
      (i) => BadgeItem(
        id: '${milestones[i]}',
        title: titles[i],
        icon: Icons.emoji_events_rounded,
        requirement:
            '${milestones[i]} défi${milestones[i] == 1 ? '' : 's'} terminé${milestones[i] == 1 ? '' : 's'}',
        isUnlocked: completed >= milestones[i],
      ),
    );
  }

  static const _botanicalStates = <({String label, String emoji, String desc})>[
    (
      label: 'Éveil',
      emoji: '🌱',
      desc: 'Les premières pousses prennent racine',
    ),
    (
      label: 'Épanouissement',
      emoji: '🌿',
      desc: 'Ton feuillage grandit doucement',
    ),
    (label: 'Sérénité', emoji: '🌸', desc: 'Les fleurs de paix s’ouvrent'),
    (label: 'Harmonie', emoji: '🦋', desc: 'La vie s’aligne en équilibre'),
    (label: 'Lumière intérieure', emoji: '✨', desc: 'Ton sanctuaire rayonne'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GamificationProvider>();
      _observedGamificationProvider = provider;
      provider.addListener(_onGamificationChanged);
      _onGamificationChanged();
      provider.loadAll();
    });
  }

  void _onGamificationChanged() {
    if (!mounted || _observedGamificationProvider == null) return;
    final completedCount =
        _observedGamificationProvider!.completedChallenges.length;
    if (_lastCompletedCount >= 0 && completedCount > _lastCompletedCount) {
      // Le provider réseau peut notifier plusieurs fois pendant un refresh :
      // le delta garantit une seule célébration par nouvelle réussite.
      context.read<MascotProvider>().react(MascotAnimations.celebrate);
      ElyriiHaptics.success();
    }
    _lastCompletedCount = completedCount;
  }

  @override
  void dispose() {
    _observedGamificationProvider?.removeListener(_onGamificationChanged);
    super.dispose();
  }

  Future<void> _handleStart(String challengeId) async {
    setState(() => _startingChallengeId = challengeId);
    final success = await context.read<GamificationProvider>().startChallenge(
      challengeId,
    );
    if (success && mounted) {
      context.read<MascotProvider>().react(MascotAnimations.invite);
    }
    if (mounted) setState(() => _startingChallengeId = null);
  }

  Future<void> _handleAcceptProposal(String proposalId) async {
    setState(() => _processingProposalId = proposalId);
    final success = await context.read<GamificationProvider>().acceptChallenge(
      proposalId,
    );
    if (success && mounted) {
      context.read<MascotProvider>().react(MascotAnimations.invite);
    }
    if (mounted) setState(() => _processingProposalId = null);
  }

  Future<void> _handleRejectProposal(String proposalId) async {
    setState(() => _processingProposalId = proposalId);
    await context.read<GamificationProvider>().rejectChallenge(proposalId);
    if (mounted) setState(() => _processingProposalId = null);
  }

  ({String label, String emoji, String desc}) _getBotanicalState(int level) {
    final index = (level - 1).clamp(0, _botanicalStates.length - 1);
    return _botanicalStates[index];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<GamificationProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();

    final streakDays = dashboardProvider.currentStreak;
    final completedCount = provider.completedChallenges.length;
    final level = 1 + (completedCount ~/ 3);
    final currentXp = (completedCount * 50) % 150;
    const maxXp = 150;
    final stateData = _getBotanicalState(level);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: ElyriiPageFrame.tab(
        title: 'Jardin',
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () => provider.loadAll(force: true),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.pageHorizontalPadding,
              AppDimensions.spacing12,
              AppDimensions.pageHorizontalPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Carte Héroïque du Jardin Intérieur
                  _buildGardenHeroCard(
                    isDark: isDark,
                    stateData: stateData,
                    level: level,
                    currentXp: currentXp,
                    maxXp: maxXp,
                    streakDays: streakDays,
                    completedCount: completedCount,
                  ),
                  const SizedBox(height: AppDimensions.spacing16),

                  // 2. Bannière de synergie Coach IA
                  _buildCoachSynergyBanner(isDark),
                  const SizedBox(height: AppDimensions.spacing20),

                  // 3. Sélecteur segmenté principal iOS
                  _segmentedControl(
                    isDark: isDark,
                    groupValue: _mainSegment,
                    labels: const {0: 'Mes Quêtes', 1: 'Mes Succès'},
                    onValueChanged: (value) =>
                        setState(() => _mainSegment = value),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                ],
              ),
            ),
          ),
          if (provider.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing20),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    provider.error!,
                    style: AppTextStyles.bodyMedium(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pageHorizontalPadding,
            ),
            sliver: _mainSegment == 0
                ? provider.isLoading &&
                          provider.activeChallenges.isEmpty &&
                          provider.availableChallenges.isEmpty
                      ? SliverToBoxAdapter(
                          child: _ChallengesSkeleton(isDark: isDark),
                        )
                      : ChallengeQuestsSliver(
                          provider: provider,
                          startingId: _startingChallengeId,
                          processingId: _processingProposalId,
                          onStart: _handleStart,
                          onAccept: _handleAcceptProposal,
                          onReject: _handleRejectProposal,
                        )
                : SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _segmentedControl(
                          isDark: isDark,
                          groupValue: _successesSubSegment,
                          labels: const {
                            0: 'Badges & Trophées',
                            1: 'Historique des fleurs',
                          },
                          onValueChanged: (value) =>
                              setState(() => _successesSubSegment = value),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppDimensions.spacing12),
                      ),
                      if (_successesSubSegment == 0)
                        SliverToBoxAdapter(
                          child: _buildBadgesView(isDark, streakDays),
                        )
                      else
                        ChallengeHistorySliver(provider: provider),
                    ],
                  ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.dockClearance),
          ),
        ],
      ),
    );
  }

  /// Carte Héroïque du Jardin Intérieur (style Apple Health / Fitness).
  Widget _buildGardenHeroCard({
    required bool isDark,
    required ({String label, String emoji, String desc}) stateData,
    required int level,
    required int currentXp,
    required int maxXp,
    required int streakDays,
    required int completedCount,
  }) {
    final progress = (currentXp / maxXp).clamp(0.0, 1.0);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cercle botanique en halo doux
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.25),
                      AppColors.secondary.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    stateData.emoji,
                    style: AppTextStyles.headlineSmall(),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppDimensions.spacing8,
                      runSpacing: AppDimensions.spacing4,
                      children: [
                        Text(
                          stateData.label,
                          style: AppTextStyles.titleMedium(
                            color: context.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing8,
                            vertical: AppDimensions.spacing2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radius8,
                            ),
                          ),
                          child: Text(
                            'Étape $level',
                            style: AppTextStyles.badge(
                              color: AppColors.readableAccent(
                                AppColors.primary,
                                isDark:
                                    Theme.of(context).brightness ==
                                    Brightness.dark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacing2),
                    Text(
                      stateData.desc,
                      style: AppTextStyles.bodyMedium(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Jauge de floraison / sérénité
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppDimensions.spacing12,
                runSpacing: AppDimensions.spacing4,

                children: [
                  Text(
                    'Floraison du sanctuaire',
                    style: AppTextStyles.labelMedium(
                      color: context.textSecondary,
                    ),
                  ),
                  Text(
                    '$currentXp / $maxXp pts',
                    style: AppTextStyles.titleSmall(
                      color: AppColors.readableAccent(
                        AppColors.primary,
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radius8),
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress == 0 ? 0.04 : progress,
                      child: Container(
                        height: 8,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Bento statistiques douces
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing12,
                    vertical: AppDimensions.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(AppDimensions.radius12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFF9500),
                        size: 18,
                      ),
                      const SizedBox(width: AppDimensions.spacing8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$streakDays ${streakDays > 1 ? "jours" : "jour"}',
                              style: AppTextStyles.titleSmall(
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              'Série active',
                              style: AppTextStyles.bodySmall(
                                color: context.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing12,
                    vertical: AppDimensions.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(AppDimensions.radius12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.spa_rounded,
                        color: Color(0xFF34C759),
                        size: 18,
                      ),
                      const SizedBox(width: AppDimensions.spacing8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completedCount ${completedCount > 1 ? "fleuris" : "fleuri"}',
                              style: AppTextStyles.titleSmall(
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              'Rituels clos',
                              style: AppTextStyles.bodySmall(
                                color: context.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Passerelle poétique vers le Coach IA : « Le Coach sème, le Jardin fleurit ».
  Widget _buildCoachSynergyBanner(bool isDark) {
    return GestureDetector(
      onTap: () {
        ElyriiHaptics.light();
        context.go(AppRoutes.coach);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing16,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radius16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.20),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semer une graine avec le Coach IA',
                    style: AppTextStyles.titleSmall(color: context.textPrimary),
                  ),
                  const SizedBox(height: AppDimensions.spacing2),
                  Text(
                    'Besoin d\'un rituel guidé sur-mesure ? Ton coach t\'écoute.',
                    style: AppTextStyles.labelSmall(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Vue « Mes Quêtes »
  // ============================================================

  Widget _buildBadgesView(bool isDark, int streakDays) {
    final unlockedCount = _badges.where((b) => b.isUnlocked).length;
    final totalCount = _badges.length;

    return Column(
      key: const ValueKey('badges_subview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête des badges avec compteur
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Badges de sérénité',
              style: AppTextStyles.overline(color: context.textSecondary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing8,
                vertical: AppDimensions.spacing2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.15 : 0.08,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radius8),
              ),
              child: Text(
                '$unlockedCount / $totalCount débloqués',
                style: AppTextStyles.badge(
                  color: AppColors.readableAccent(
                    AppColors.primary,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing8),
        BadgesGrid(
          badges: _badges,
          onBadgeTap: (badge) => _showBadgeDetails(context, badge),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        Text(
          'Chaque badge fleuri témoigne d\'un pas vers la sérénité.',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall(color: context.textTertiary)
              .copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: AppDimensions.spacing16),

        // Trophée de constance (volet Trophées du segment)
        Text(
          'Constance & rythme',
          style: AppTextStyles.overline(color: context.textSecondary),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        DailyStreakCard(
          streakDays: streakDays,
          weekHistory: List.generate(7, (i) => i < streakDays),
        ),
      ],
    );
  }

  Widget _segmentedControl({
    required bool isDark,
    required int groupValue,
    required Map<int, String> labels,
    required ValueChanged<int> onValueChanged,
  }) {
    final selectedColor = context.textPrimary;
    final unselectedColor = context.textSecondary;

    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: groupValue,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        thumbColor: isDark ? const Color(0xFF3A3A3C) : Colors.white,
        padding: const EdgeInsets.all(AppDimensions.spacing2),
        children: {
          for (final entry in labels.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacing8,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: Text(
                    entry.value,
                    style: AppTextStyles.labelMedium(
                      color: entry.key == groupValue
                          ? selectedColor
                          : unselectedColor,
                    ),
                  ),
                ),
              ),
            ),
        },
        onValueChanged: (value) {
          if (value == null || value == groupValue) return;
          ElyriiHaptics.selection();
          onValueChanged(value);
        },
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeItem badge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mascot = context.read<MascotProvider>();
    if (badge.isUnlocked) {
      ElyriiHaptics.success();
      mascot.react(MascotAnimations.celebrate);
    } else {
      ElyriiHaptics.light();
      mascot.react(MascotAnimations.curious);
    }

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
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            '${badge.requirement}. ${badge.isUnlocked ? 'Objectif atteint !' : 'À ton rythme.'}',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
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

/// Squelette de chargement discret (shimmer doux).
class _ChallengesSkeleton extends StatelessWidget {
  final bool isDark;

  const _ChallengesSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shimmerBase = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final shimmerHighlight = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
          child:
              Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radius16,
                      ),
                    ),
                  )
                  .animateRespectingMotion(
                    context,
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .shimmer(duration: 1400.ms, color: shimmerHighlight),
        ),
      ),
    );
  }
}
