import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/gamification_provider.dart';
import '../widgets/ai_proposal_card.dart';
import '../widgets/badges_grid.dart';
import '../widgets/challenge_card.dart';
import '../widgets/daily_streak_card.dart';
import '../widgets/level_progress_header.dart';
import '../widgets/quest_tile.dart';

/// Jardin — page quêtes & réussites, refonte iOS.
///
/// - Tirer-relâcher natif Cupertino ([CupertinoSliverRefreshControl]),
///   plus aucun `RefreshIndicator` Material.
/// - Grand titre rétractable « Jardin » façon iOS.
/// - Hiérarchie aérée : sélecteur segmenté glissant « Mes Quêtes » /
///   « Mes Succès », chacun avec ses sous-vues.
/// - Chargements en skeletons shimmer discrets (aucun indicateur
///   circulaire Material).
/// - Ton bienveillant façon Apple Fitness : jamais culpabilisant.
class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  String? _startingChallengeId;
  String? _processingProposalId;

  /// Segment principal : 0 = Mes Quêtes, 1 = Mes Succès.
  int _mainSegment = 0;

  /// Sous-vue Quêtes : 0 = En cours, 1 = Suggestions.
  int _questsSubSegment = 0;

  /// Sous-vues Succès : 0 = Trophées, 1 = Badges, 2 = Historique.
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
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: CustomScrollView(
        // Toujours déroulable pour permettre le tirer-relâcher iOS.
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Tirer-relâcher natif Cupertino (remplace le RefreshIndicator
          // Material).
          CupertinoSliverRefreshControl(onRefresh: () => provider.loadAll()),
          // Grand titre rétractable iOS : « Jardin » en grand format qui se
          // replie en titre centré compact au défilement.
          const SliverAppBar.large(
            pinned: true,
            centerTitle: true,
            title: Text('Jardin'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          SliverPadding(
            // Marge basse généreuse pour le dock flottant du shell.
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cultive tes rituels, tes progrès doux et tes défis personnels.',
                    style: AppTextStyles.bodySmall(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  _segmentedControl(
                    isDark: isDark,
                    groupValue: _mainSegment,
                    labels: const {0: 'Mes Quêtes', 1: 'Mes Succès'},
                    onValueChanged: (value) =>
                        setState(() => _mainSegment = value),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: _fadeSlide,
                    child: _mainSegment == 0
                        ? _buildQuestsView(provider, isDark)
                        : _buildSuccessesView(provider, isDark, streakDays),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Transition douce (fondu + micro-glissement) entre sous-vues.
  Widget _fadeSlide(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  // ============================================================
  // Sélecteurs segmentés iOS
  // ============================================================

  /// Segmented glissant iOS plein cadre, avec retour haptique doux.
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
        padding: const EdgeInsets.all(2),
        children: {
          for (final entry in labels.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                entry.value,
                style: AppTextStyles.labelMedium(
                  color: entry.key == groupValue
                      ? selectedColor
                      : unselectedColor,
                  fontWeight: FontWeight.w600,
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

  // ============================================================
  // Vue « Mes Quêtes »
  // ============================================================

  Widget _buildQuestsView(GamificationProvider provider, bool isDark) {
    return Column(
      key: const ValueKey('quests'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _segmentedControl(
          isDark: isDark,
          groupValue: _questsSubSegment,
          labels: const {0: 'En cours', 1: 'Suggestions'},
          onValueChanged: (value) => setState(() => _questsSubSegment = value),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: _fadeSlide,
          child: _questsSubSegment == 0
              ? _buildActiveQuests(provider, isDark)
              : _buildSuggestions(provider, isDark),
        ),
      ],
    );
  }

  /// Sous-vue « En cours » : quêtes actives, ou état vide bienveillant.
  Widget _buildActiveQuests(GamificationProvider provider, bool isDark) {
    if (provider.isLoading && provider.activeChallenges.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('active-loading'),
        child: _ChallengesSkeleton(isDark: isDark),
      );
    }

    if (provider.activeChallenges.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('active-empty'),
        child: _emptyState(
          isDark,
          'Rien en cours pour le moment.\nChaque jour compte, à ton rythme.',
          Icons.spa_rounded,
        ),
      );
    }

    return Column(
      key: const ValueKey('active-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  /// Sous-vue « Suggestions » : propositions d'Elyrii puis défis à découvrir.
  Widget _buildSuggestions(GamificationProvider provider, bool isDark) {
    final hasContent =
        provider.proposals.isNotEmpty ||
        provider.availableChallenges.isNotEmpty;

    if (provider.isLoading && !hasContent) {
      return KeyedSubtree(
        key: const ValueKey('suggestions-loading'),
        child: _ChallengesSkeleton(isDark: isDark, tileHeight: 96),
      );
    }

    if (!hasContent) {
      return KeyedSubtree(
        key: const ValueKey('suggestions-empty'),
        child: _emptyState(
          isDark,
          'Aucune suggestion pour l\'instant.\nElyrii prépare quelque chose de doux pour toi.',
          Icons.auto_awesome_rounded,
        ),
      );
    }

    return Column(
      key: const ValueKey('suggestions-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.proposals.isNotEmpty) ...[
          _sectionHeader('Proposées par Elyrii', isDark),
          ...provider.proposals.map(
            (proposal) => AiProposalCard(
              proposal: proposal,
              isProcessing: _processingProposalId == proposal.id,
              onAccept: () => _handleAcceptProposal(proposal.id),
              onReject: () => _handleRejectProposal(proposal.id),
            ),
          ),
          if (provider.availableChallenges.isNotEmpty)
            const SizedBox(height: 20),
        ],
        if (provider.availableChallenges.isNotEmpty) ...[
          _sectionHeader('À découvrir', isDark),
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
      key: const ValueKey('successes'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _segmentedControl(
          isDark: isDark,
          groupValue: _successesSubSegment,
          labels: const {0: 'Trophées', 1: 'Badges', 2: 'Historique'},
          onValueChanged: (value) =>
              setState(() => _successesSubSegment = value),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: _fadeSlide,
          child: switch (_successesSubSegment) {
            0 => _buildTrophies(provider, isDark, streakDays),
            1 => _buildBadges(isDark),
            _ => _buildHistory(provider, isDark),
          },
        ),
      ],
    );
  }

  /// Sous-vue « Trophées » : niveau et rythme de la semaine.
  Widget _buildTrophies(
    GamificationProvider provider,
    bool isDark,
    int streakDays,
  ) {
    if (provider.isLoading && provider.completedChallenges.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('trophies-loading'),
        child: _ChallengesSkeleton(isDark: isDark, tileHeight: 120),
      );
    }

    return Column(
      key: const ValueKey('trophies'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LevelProgressHeader(
          level: 1 + provider.completedChallenges.length ~/ 3,
          currentXp: provider.completedChallenges.length * 50,
          maxXp: 150,
          title: 'Explorateur de l\'esprit',
        ),
        const SizedBox(height: 12),
        DailyStreakCard(
          streakDays: streakDays,
          weekHistory: List.generate(7, (i) => i < streakDays),
        ),
      ],
    );
  }

  /// Sous-vue « Badges » : qualités qui grandissent, sans pression.
  Widget _buildBadges(bool isDark) {
    return Column(
      key: const ValueKey('badges'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BadgesGrid(
          badges: _badges,
          onBadgeTap: (badge) => _showBadgeDetails(context, badge),
        ),
        const SizedBox(height: 8),
        Text(
          'Chaque badge grandit en toi, à ton rythme.',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }

  /// Sous-vue « Historique » : les moments déjà vécus.
  Widget _buildHistory(GamificationProvider provider, bool isDark) {
    if (provider.isLoading && provider.completedChallenges.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('history-loading'),
        child: _ChallengesSkeleton(isDark: isDark),
      );
    }

    if (provider.completedChallenges.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('history-empty'),
        child: _emptyState(
          isDark,
          'Chaque vécu compte.\nTon histoire s\'écrira ici, moment après moment.',
          Icons.auto_stories_rounded,
        ),
      );
    }

    return Column(
      key: const ValueKey('history-list'),
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
  // Éléments communs
  // ============================================================

  String _shortDescription(String description) {
    const maxLength = 40;
    if (description.characters.length <= maxLength) return description;
    return '${description.characters.take(maxLength)}…';
  }

  /// En-tête de section discret façon listes groupées iOS.
  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.labelMedium(
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          fontWeight: FontWeight.w600,
        ).copyWith(letterSpacing: 0.2),
      ),
    );
  }

  Widget _emptyState(bool isDark, String message, IconData icon) {
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
              style: AppTextStyles.bodySmall(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ).copyWith(height: 1.5),
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

/// Squelette de chargement discret : shimmer doux aux couleurs de surface,
/// en remplacement de tout indicateur circulaire Material.
class _ChallengesSkeleton extends StatelessWidget {
  final bool isDark;

  /// Hauteur de chaque tuile fantôme.
  final double tileHeight;

  const _ChallengesSkeleton({required this.isDark, this.tileHeight = 76});

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    Widget block(double height) =>
        Container(
              height: height,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 1400.ms,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.5),
            );

    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          block(tileHeight),
        ],
      ],
    );
  }
}
