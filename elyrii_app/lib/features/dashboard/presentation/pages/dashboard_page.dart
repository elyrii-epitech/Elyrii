import '../widgets/dashboard_cards.dart';
import '../widgets/dashboard_skeleton.dart';
import '../widgets/mood_chip.dart';
import '../widgets/mascot_customize_charm.dart';
import '../../../../core/widgets/accessible_action.dart';

import 'package:flutter/material.dart';

import '../../../../core/widgets/elyrii_page_header.dart';

import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';

import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/glass_settings_button.dart';
import '../../../journal/presentation/providers/journal_provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/providers/settings_provider.dart';

import '../widgets/mascot_peek.dart';
import '../widgets/mascot_speech_bubble.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      context.read<DashboardProvider>().loadDashboardData();
      context.read<JournalProvider>().loadEntries();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final provider = context.read<DashboardProvider>();
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: ElyriiPageFrame(
        header: _buildPinnedHeaderControls(
          context.watch<AuthProvider>(),
          context.watch<UserProvider>(),
          isDark,
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 44),
                  Selector<DashboardProvider, MoodType?>(
                    selector: (_, p) => p.selectedMood,
                    builder: (_, mood, _) => MascotPeek(
                      selectedMood: mood,
                      isDark: isDark,
                      onTap: provider.nextMascotMessage,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MascotCustomizeCharm(isDark: isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.pageHorizontalPadding,
                ),
                child: Column(
                  children: [
                    Selector<DashboardProvider, String>(
                      selector: (_, p) => p.mascotMessage,
                      builder: (_, message, _) => MascotSpeechBubble(
                        message: message,
                        isDark: isDark,
                        onTap: provider.nextMascotMessage,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Selector<
                      DashboardProvider,
                      (MoodType?, bool, String?, DateTime?)
                    >(
                      selector: (_, p) =>
                          (p.selectedMood, p.isSavingMood, p.error, p.cachedAt),
                      builder: (_, state, _) => Column(
                        children: [
                          _buildMoodSection(isDark, provider),
                          if (state.$2)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Enregistrement de ton humeur…'),
                            ),
                          if (state.$4 != null)
                            const Text(
                              'Données conservées hors ligne, datant de moins de 24 h.',
                            ),
                          if (state.$3 != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                state.$3!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          if (state.$3 != null)
                            TextButton(
                              onPressed: provider.refresh,
                              child: const Text('Actualiser'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Selector2<
                      DashboardProvider,
                      JournalProvider,
                      (bool, int, JournalEntry?)
                    >(
                      selector: (_, dashboard, journal) => (
                        dashboard.isLoading,
                        dashboard.currentStreak,
                        journal.entries.firstOrNull,
                      ),
                      builder: (context, value, _) => value.$1
                          ? DashboardSkeleton(isDark: isDark)
                          : _buildBentoGrid(
                              provider,
                              context.read<JournalProvider>(),
                              isDark,
                            ),
                    ),
                    const SizedBox(height: 130),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Date du jour formatée en français pour le bandeau d'en-tête (ex: VENDREDI 12 SEPTEMBRE).
  String _formatHeaderDate() {
    final now = DateTime.now();
    const days = [
      'LUNDI',
      'MARDI',
      'MERCREDI',
      'JEUDI',
      'VENDREDI',
      'SAMEDI',
      'DIMANCHE',
    ];
    const months = [
      'JANVIER',
      'FÉVRIER',
      'MARS',
      'AVRIL',
      'MAI',
      'JUIN',
      'JUILLET',
      'AOÛT',
      'SEPTEMBRE',
      'OCTOBRE',
      'NOVEMBRE',
      'DÉCEMBRE',
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName ${now.day} $monthName';
  }

  /// Date et salutation, épinglées entre les boutons de l’en-tête.
  Widget _buildScrollingGreeting(
    AuthProvider authProvider,
    UserProvider userProvider,
    DashboardProvider dashboardProvider,
    bool isDark,
  ) {
    final rawName =
        authProvider.user?.firstName?.trim() ??
        userProvider.profile?.firstName?.trim() ??
        '';
    final greeting = rawName.isNotEmpty
        ? '${dashboardProvider.getGreeting()}, $rawName'
        : dashboardProvider.getGreeting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatHeaderDate(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDark ? AppColors.primaryDark : AppColors.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          greeting,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            height: 1.1,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Contrôles épinglés : avatar et réglages restent fixés en haut.
  Widget _buildPinnedHeaderControls(
    AuthProvider authProvider,
    UserProvider userProvider,
    bool isDark,
  ) {
    return Row(
      children: [
        // Avatar utilisateur circulaire en Liquid Glass (44x44)
        Semantics(
          button: true,
          label: 'Profil utilisateur',
          child: AccessibleAction(
            label: null,
            onPressed: () {
              ElyriiHaptics.light();
              context.push(AppRoutes.editProfile);
            },
            child: ElyriiGlassSurface(
              role: GlassRole.floatingControl,
              borderRadius: BorderRadius.circular(22),
              width: 44,
              height: 44,
              child: Center(
                child: ClipOval(
                  child: UserAvatar(
                    pfp: userProvider.profile?.pfp,
                    size: 38,
                    showBorder: false,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildScrollingGreeting(
            authProvider,
            userProvider,
            context.read<DashboardProvider>(),
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        // Bouton Réglages circulaire en Liquid Glass (44x44)
        GlassSettingsButton(
          isDark: isDark,
          onTap: () => context.push(AppRoutes.settings),
        ),
      ],
    );
  }

  /// Section État d'Esprit inspirée d'Apple Health State of Mind :
  /// 5 puces émotionnelles expressives, résonance textuelle et action immédiate.
  Widget _buildMoodSection(bool isDark, DashboardProvider provider) {
    final selectedMood = provider.selectedMood;
    final moodColor = selectedMood?.color ?? AppColors.primary;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo d'ambiance doux (effet Apple Health State of Mind)
        if (selectedMood != null)
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: moodColor.withValues(alpha: isDark ? 0.22 : 0.14),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        LiquidGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête de la section
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: moodColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      selectedMood?.icon ?? Icons.mood_rounded,
                      color: moodColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'État d\'esprit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          selectedMood != null
                              ? 'Enregistré aujourd\'hui'
                              : 'Comment te sens-tu ce soir ?',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedMood != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: moodColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 12, color: moodColor),
                          const SizedBox(width: 4),
                          Text(
                            selectedMood.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: moodColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              // Sélecteur des 5 humeurs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: MoodType.values.map((mood) {
                  final isSelected = selectedMood == mood;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DashboardMoodChip(
                        mood: mood,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: provider.isSavingMood
                            ? null
                            : () => provider.selectMood(mood),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Résonance émotionnelle & Action concrète (Valeur ajoutée bienveillante)
              if (selectedMood != null) ...[
                const SizedBox(height: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: moodColor.withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            selectedMood.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: moodColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedMood.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Bouton d'action contextuel
                      AccessibleAction(
                        label: selectedMood.suggestedActionLabel,
                        onPressed: () {
                          ElyriiHaptics.light();
                          context.read<MascotProvider>().react(
                            MascotAnimations.invite,
                          );
                          context.push(selectedMood.suggestedActionRoute);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: moodColor.withValues(
                              alpha: isDark ? 0.18 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedMood.suggestedActionIcon,
                                size: 16,
                                color: moodColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedMood.suggestedActionLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: moodColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Bento Grid organisée et hiérarchisée selon les standards Apple Health & Fitness.
  Widget _buildBentoGrid(
    DashboardProvider provider,
    JournalProvider journalProvider,
    bool isDark,
  ) {
    return Column(
      children: [
        // Ligne 1 : Deux cartes symétriques Bento (Série & Respiration)
        Row(
          children: [
            // Carte Série (Gauche)
            Expanded(
              child: DashboardStreakCard(
                streak: provider.currentStreak,
                isDark: isDark,
                onTap: () {
                  ElyriiHaptics.light();
                  final mascotProvider = context.read<MascotProvider>();
                  if (provider.currentStreak > 1) {
                    mascotProvider.react(MascotAnimations.celebrate);
                  } else if (provider.currentStreak == 1) {
                    mascotProvider.react(MascotAnimations.delight);
                  } else {
                    mascotProvider.react(MascotAnimations.invite);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Carte Respiration (Droite)
            Expanded(
              child: DashboardBreatheCard(
                isDark: isDark,
                onTap: () {
                  ElyriiHaptics.light();
                  context.read<MascotProvider>().react(MascotAnimations.invite);
                  context.go(AppRoutes.meditation);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Ligne 2 : Carte pleine largeur Journal Récent
        DashboardJournalCard(
          lastEntry: journalProvider.entries.isNotEmpty
              ? journalProvider.entries.first
              : null,
          isDark: isDark,
          onTap: () {
            ElyriiHaptics.light();
            context.read<MascotProvider>().react(
              journalProvider.entries.isNotEmpty
                  ? MascotAnimations.cozy
                  : MascotAnimations.invite,
            );
            context.go(AppRoutes.journal);
          },
        ),
        const SizedBox(height: 12),
        // Ligne 3 : Barre Bilan & Progrès
        DashboardReviewBar(
          isDark: isDark,
          onTap: () {
            ElyriiHaptics.light();
            context.push(AppRoutes.reviews);
          },
        ),
      ],
    );
  }
}
