import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';
import '../../../journal/data/models/journal_entry_model.dart';
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Consumer4<
      DashboardProvider,
      JournalProvider,
      AuthProvider,
      UserProvider
    >(
      builder: (context, provider, journalProvider, authProvider, userProvider, child) {
        return Scaffold(
          backgroundColor: isDark
              ? AppColors.scaffoldDark
              : AppColors.scaffoldLight,
          body: Stack(
            children: [
              // Contenu principal défilant sous les boutons d'en-tête
              SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Date et salutation : collées au contenu, elles glissent
                    // avec lui (les boutons restent épinglés en overlay).
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20 + 44 + 12,
                        topPadding + 10,
                        20 + 44 + 12,
                        8,
                      ),
                      child: _buildScrollingGreeting(
                        authProvider,
                        userProvider,
                        provider,
                        isDark,
                      ),
                    ),

                    // ---- 1. Zone héroïque : mascotte 3D & charm de personnalisation ----
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Espace symétrique invisible à gauche (44px) pour centrer parfaitement la mascotte
                        const SizedBox(width: 44),
                        MascotPeek(
                          selectedMood: provider.selectedMood,
                          isDark: isDark,
                          onTap: provider.nextMascotMessage,
                        ),
                        // Charm de personnalisation discret en verre liquide
                        SizedBox(
                          width: 44,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _MascotCustomizeCharm(isDark: isDark),
                          ),
                        ),
                      ],
                    ),

                    // Rapprochement du texte directement sous les pattes de la mascotte
                    const SizedBox(height: 2),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pageHorizontalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Bulle de parole en verre doux
                          MascotSpeechBubble(
                            message: provider.mascotMessage,
                            isDark: isDark,
                            onTap: provider.nextMascotMessage,
                          ),
                          const SizedBox(height: 22),

                          // ---- 2. État d'esprit (Style Apple Health State of Mind) ----
                          _buildMoodSection(isDark, provider),

                          const SizedBox(height: 22),

                          // ---- 3. Bento Grid du Bien-être ----
                          if (provider.isLoading)
                            _DashboardSkeleton(isDark: isDark)
                          else
                            _buildBentoGrid(provider, journalProvider, isDark),

                          // Espace pour la barre de navigation flottante
                          const SizedBox(height: 130),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Boutons épinglés : avatar et réglages restent en haut pendant
              // que le contenu (date, salutation, cartes) glisse dessous.
              Positioned(
                top: topPadding + 8,
                left: 20,
                right: 20,
                child: _buildPinnedHeaderControls(
                  authProvider,
                  userProvider,
                  isDark,
                ),
              ),
            ],
          ),
        );
      },
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

  /// Date du jour et salutation, dans le scroll : glissent avec le contenu.
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          greeting,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          maxLines: 1,
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
          child: GestureDetector(
            onTap: () {
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
        const Spacer(),
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
                  return _MoodChip(
                    mood: mood,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => provider.selectMood(mood),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Bouton d'action contextuel
                      GestureDetector(
                        onTap: () {
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
              child: _BentoStreakCard(
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
              child: _BentoBreatheCard(
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
        _BentoJournalCard(
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
        _BentoReviewBar(
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

/// Puce de mood interactive avec micro-rebond élastique Apple, haptique et halo.
class _MoodChip extends StatefulWidget {
  final MoodType mood;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoodChip({
    required this.mood,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MoodChip> createState() => _MoodChipState();
}

class _MoodChipState extends State<_MoodChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final moodColor = widget.mood.color;

    return Semantics(
      button: true,
      label: widget.mood.label,
      selected: widget.isSelected,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          ElyriiHaptics.selection();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : (widget.isSelected ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? moodColor.withValues(alpha: widget.isDark ? 0.25 : 0.18)
                  : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? moodColor.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.8,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: moodColor.withValues(
                          alpha: widget.isDark ? 0.35 : 0.20,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.mood.icon,
              size: widget.isSelected ? 26 : 22,
              color: widget.isSelected
                  ? moodColor
                  : (widget.isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte Bento Série & Régularité (esprit Apple Fitness).
class _BentoStreakCard extends StatelessWidget {
  final int streak;
  final bool isDark;
  final VoidCallback? onTap;

  const _BentoStreakCard({
    required this.streak,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFFF6B6B);

    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: coral.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: coral,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Text(
                  'SÉRIE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$streak ${streak > 1 ? 'jours' : 'jour'}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              streak > 0 ? 'Tu tiens le rythme !' : 'Commence aujourd\'hui',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte Bento Pause Respiration avec bouton d'accès rapide.
class _BentoBreatheCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _BentoBreatheCard({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const lavender = AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lavender.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.air_rounded,
                    color: lavender,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lavender.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Démarrer',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: lavender,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.play_arrow_rounded, size: 12, color: lavender),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '2 min',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cohérence cardiaque',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte Bento Pleine Largeur : Dernière entrée de journal.
class _BentoJournalCard extends StatelessWidget {
  final JournalEntryModel? lastEntry;
  final bool isDark;
  final VoidCallback onTap;

  const _BentoJournalCard({
    required this.lastEntry,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Dernière réflexion',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lastEntry != null) ...[
              Text(
                lastEntry!.title.isNotEmpty ? lastEntry!.title : 'Sans titre',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                lastEntry!.content ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                'Prends un instant pour poser tes pensées...',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barre Bento Bilan & Progrès.
class _BentoReviewBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _BentoReviewBar({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Consulter mon bilan & progression',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

/// Squelette de chargement discret : shimmer doux aux couleurs de surface,
/// en remplacement de toute barre de progression brute.
class _DashboardSkeleton extends StatelessWidget {
  final bool isDark;

  const _DashboardSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );

    Widget block(double height) {
      final box = Container(
        height: height,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
        ),
      );
      if (isTest) return box;
      return box
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: 1400.ms,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.5),
          );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: block(92)),
            const SizedBox(width: 12),
            Expanded(child: block(92)),
          ],
        ),
        const SizedBox(height: 12),
        block(72),
      ],
    );
  }
}

/// Charm de personnalisation discret et épuré en Liquid Glass pur.
///
/// Suppression de la surbrillance criarde et de l'oscillation : surface de verre
/// dépoli subtile, parfaitement intégrée à la ligne visuelle Apple de l'écran.
class _MascotCustomizeCharm extends StatefulWidget {
  final bool isDark;

  const _MascotCustomizeCharm({required this.isDark});

  @override
  State<_MascotCustomizeCharm> createState() => _MascotCustomizeCharmState();
}

class _MascotCustomizeCharmState extends State<_MascotCustomizeCharm> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Personnaliser la mascotte',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          ElyriiHaptics.selection();
          context.push(AppRoutes.mascotCustomization);
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          child: ElyriiGlassSurface(
            role: GlassRole.floatingControl,
            borderRadius: BorderRadius.circular(20),
            width: 40,
            height: 40,
            child: Center(
              child: Icon(
                Icons.palette_outlined,
                size: 19,
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
