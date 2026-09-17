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
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../providers/gamification_provider.dart';
import '../widgets/ai_proposal_card.dart';
import '../widgets/badges_grid.dart';
import '../widgets/challenge_card.dart';
import '../widgets/quest_tile.dart';
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

  static const List<Map<String, dynamic>> _botanicalStates = [
    {
      'label': 'Éveil',
      'emoji': '🌱',
      'desc': 'Les premières pousses prennent racine',
    },
    {
      'label': 'Épanouissement',
      'emoji': '🌿',
      'desc': 'Ton feuillage grandit doucement',
    },
    {
      'label': 'Sérénité',
      'emoji': '🌸',
      'desc': 'Les fleurs de paix s\'ouvrent',
    },
    {
      'label': 'Harmonie',
      'emoji': '🦋',
      'desc': 'La vie s\'aligne en équilibre',
    },
    {
      'label': 'Lumière intérieure',
      'emoji': '✨',
      'desc': 'Ton sanctuaire rayonne',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  Map<String, dynamic> _getBotanicalState(int level) {
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

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Tirer-relâcher natif Cupertino (aucun indicateur Material).
          CupertinoSliverRefreshControl(onRefresh: () => provider.loadAll()),

          // En-tête spatial fluide (remplace le SliverAppBar.large rigide).
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.pageHorizontalPadding,
                topPadding + 14,
                AppDimensions.pageHorizontalPadding,
                4,
              ),
              child: _buildHeader(isDark),
            ),
          ),

          // Contenu principal de la page.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.pageHorizontalPadding,
              12,
              AppDimensions.pageHorizontalPadding,
              110, // Marge pour la barre de navigation flottante
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
                  const SizedBox(height: 18),

                  // 2. Bannière de synergie Coach IA
                  _buildCoachSynergyBanner(isDark),
                  const SizedBox(height: 20),

                  // 3. Sélecteur segmenté principal iOS
                  _segmentedControl(
                    isDark: isDark,
                    groupValue: _mainSegment,
                    labels: const {0: 'Mes Quêtes', 1: 'Mes Succès'},
                    onValueChanged: (value) =>
                        setState(() => _mainSegment = value),
                  ),
                  const SizedBox(height: 18),

                  // 4. Vues animées fluides (taille + fondu progressif)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [...previousChildren, ?currentChild],
                        );
                      },
                      transitionBuilder: _smoothFade,
                      child: _mainSegment == 0
                          ? _buildQuestsView(provider, isDark)
                          : _buildSuccessesView(provider, isDark, streakDays),
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

  /// En-tête spatial sans vide noir ni coupure.
  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MON JARDIN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Jardin',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Fais grandir tes habitudes, une graine à la fois.',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  /// Carte Héroïque du Jardin Intérieur (style Apple Health / Fitness).
  Widget _buildGardenHeroCard({
    required bool isDark,
    required Map<String, dynamic> stateData,
    required int level,
    required int currentXp,
    required int maxXp,
    required int streakDays,
    required int completedCount,
  }) {
    final progress = (currentXp / maxXp).clamp(0.0, 1.0);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
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
                    stateData['emoji'] as String,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stateData['label'] as String,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Étape $level',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stateData['desc'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Jauge de floraison / sérénité
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Floraison du sanctuaire',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    '$currentXp / $maxXp pts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 16),

          // Bento statistiques douces
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFF9500),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$streakDays ${streakDays > 1 ? "jours" : "jour"}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              'Série active',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.spa_rounded,
                        color: Color(0xFF34C759),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completedCount ${completedCount > 1 ? "fleuris" : "fleuri"}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              'Rituels clos',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.20),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semer une graine avec le Coach IA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Besoin d\'un rituel guidé sur-mesure ? Ton coach t\'écoute.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

  Widget _buildQuestsView(GamificationProvider provider, bool isDark) {
    if (provider.isLoading &&
        provider.activeChallenges.isEmpty &&
        provider.availableChallenges.isEmpty) {
      return _ChallengesSkeleton(isDark: isDark);
    }

    final hasActive = provider.activeChallenges.isNotEmpty;
    final hasProposals = provider.proposals.isNotEmpty;
    final hasAvailable = provider.availableChallenges.isNotEmpty;

    return Column(
      key: const ValueKey('quests_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rituels en cours
        _sectionHeader('Rituels en cours', isDark),
        if (!hasActive)
          _emptyCard(
            key: const ValueKey('quests_empty_subview'),
            isDark: isDark,
            icon: Icons.spa_rounded,
            title: 'Aucun rituel actif aujourd\'hui',
            subtitle:
                'Choisis une graine ci-dessous pour faire grandir ton jardin, ou avance à ton propre rythme.',
          )
        else
          ...provider.activeChallenges.map(
            (uc) => QuestTile(
              title: uc.displayTitle,
              subtitle: _shortDescription(uc.displayDescription),
              icon: uc.displayIcon,
              xpReward: uc.template?.rewardPoints ?? 50,
              isCompleted: false,
              progressFraction: uc.progressFraction,
              progressText: uc.progressText,
            ),
          ),
        const SizedBox(height: 24),

        // Graines & Suggestions proposées par Elyrii
        if (hasProposals) ...[
          _sectionHeader('Graines proposées par ton Coach IA', isDark),
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

        // Rituels universels à découvrir
        if (hasAvailable) ...[
          _sectionHeader('À découvrir dans le sanctuaire', isDark),
          ...provider.availableChallenges.map(
            (challenge) => ChallengeAvailableCard(
              challenge: challenge,
              isStarting: _startingChallengeId == challenge.id,
              onStart: () => _handleStart(challenge.id),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // Vue « Mes Succès »
  // ============================================================

  Widget _buildSuccessesView(
    GamificationProvider provider,
    bool isDark,
    int streakDays,
  ) {
    return Column(
      key: const ValueKey('successes_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sous-segmenté Succès : Badges fleuris / Rituels accomplis
        _segmentedControl(
          isDark: isDark,
          groupValue: _successesSubSegment,
          labels: const {0: 'Badges & Trophées', 1: 'Historique des fleurs'},
          onValueChanged: (value) =>
              setState(() => _successesSubSegment = value),
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [...previousChildren, ?currentChild],
              );
            },
            transitionBuilder: _smoothFade,
            child: _successesSubSegment == 0
                ? _buildBadgesView(isDark, streakDays)
                : _buildHistoryView(provider, isDark),
          ),
        ),
      ],
    );
  }

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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.15 : 0.08,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unlockedCount / $totalCount débloqués',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        BadgesGrid(
          badges: _badges,
          onBadgeTap: (badge) => _showBadgeDetails(context, badge),
        ),
        const SizedBox(height: 10),
        Text(
          'Chaque badge fleuri témoigne d\'un pas vers la sérénité.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
        const SizedBox(height: 18),

        // Trophée de constance (volet Trophées du segment)
        Text(
          'Constance & rythme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 10),
        DailyStreakCard(
          streakDays: streakDays,
          weekHistory: List.generate(7, (i) => i < streakDays),
        ),
      ],
    );
  }

  Widget _buildHistoryView(GamificationProvider provider, bool isDark) {
    if (provider.completedChallenges.isEmpty) {
      return _emptyCard(
        key: const ValueKey('history_empty_subview'),
        isDark: isDark,
        icon: Icons.auto_stories_rounded,
        title: 'Ton herbier est encore vierge',
        subtitle:
            'Chaque rituel mené à son terme laissera ici une trace douce de ton chemin.',
      );
    }

    return Column(
      key: const ValueKey('history_list_subview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...provider.completedChallenges.map(
          (uc) => QuestTile(
            title: uc.displayTitle,
            subtitle: _shortDescription(uc.displayDescription),
            icon: uc.displayIcon,
            xpReward: uc.template?.rewardPoints ?? 50,
            isCompleted: true,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Éléments d'UI communs & Helpers
  // ============================================================

  Widget _emptyCard({
    Key? key,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return LiquidGlassCard(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentedControl({
    required bool isDark,
    required int groupValue,
    required Map<int, String> labels,
    required ValueChanged<int> onValueChanged,
  }) {
    final selectedColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final unselectedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: groupValue,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        thumbColor: isDark ? const Color(0xFF3A3A3C) : Colors.white,
        padding: const EdgeInsets.all(3),
        children: {
          for (final entry in labels.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: entry.key == groupValue
                      ? selectedColor
                      : unselectedColor,
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

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  String _shortDescription(String description) {
    const maxLength = 48;
    if (description.characters.length <= maxLength) return description;
    return '${description.characters.take(maxLength)}…';
  }

  Widget _smoothFade(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
      child: child,
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
          const SizedBox(height: 16),
          Text(
            badge.isUnlocked
                ? 'Tu as développé cette belle compétence.\nElle fait maintenant partie de ton sanctuaire.'
                : 'Cette qualité prend racine en toi,\npetit à petit, à ton rythme.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
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
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .shimmer(duration: 1400.ms, color: shimmerHighlight),
        ),
      ),
    );
  }
}
