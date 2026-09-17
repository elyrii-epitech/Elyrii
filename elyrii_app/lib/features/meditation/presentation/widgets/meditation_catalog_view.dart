import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../domain/models/breath_phase.dart';
import '../controllers/meditation_controller.dart';

/// Vue catalogue épurée pour choisir la technique et la durée de respiration.
///
/// Refonte Apple HIG & Liquid Glass (Septembre 2026) :
/// - En-tête spatial fluide avec micro-sur-titre « MON SOUFFLE », grand titre
///   « Méditation » et pilule de sérénité interactive.
/// - Carte Héroïque « Sanctuaire du Souffle » avec mascotte velours respirant
///   en boucle calme (autoRotate désactivé).
/// - Passerelle poétique avec le Jardin : « Respirer arrose ton jardin intérieur ».
/// - Sélecteur de durée sous forme de contrôle segmenté glissant iOS avec haptique.
/// - Cartes de techniques respiratoires en verre liquide réactives au tap.
/// - Tirer-relâcher natif Cupertino ([CupertinoSliverRefreshControl]).
class MeditationCatalogView extends StatelessWidget {
  final MeditationController controller;

  const MeditationCatalogView({super.key, required this.controller});

  static const List<int> _durations = [5, 10, 15];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // 1. Tirer-relâcher natif Cupertino
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            // Rechargement doux d'état
            await Future.delayed(const Duration(milliseconds: 300));
          },
        ),

        // 2. En-tête spatial fluide sans coupure
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.pageHorizontalPadding,
              topPadding + 14,
              AppDimensions.pageHorizontalPadding,
              8,
            ),
            child: _buildHeader(isDark),
          ),
        ),

        // 3. Contenu principal
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.pageHorizontalPadding,
            12,
            AppDimensions.pageHorizontalPadding,
            140, // Dégagement pour le dock flottant du shell
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A. Carte Héroïque du Sanctuaire du Souffle avec Mascotte
                _buildMeditationHeroCard(isDark),
                const SizedBox(height: 20),

                // C. Notice de synchronisation en cas d'erreur réseau
                if (controller.backendError != null) ...[
                  _buildSyncNotice(isDark),
                  const SizedBox(height: 20),
                ],

                // D. Sélecteur de durée iOS
                _sectionHeader('Durée de la séance', isDark),
                const SizedBox(height: 10),
                _buildDurationSegmented(isDark),
                const SizedBox(height: 24),

                // E. Cartes des techniques respiratoires
                _sectionHeader('Techniques respiratoires', isDark),
                const SizedBox(height: 10),
                _buildBreathingTypeCards(isDark),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// En-tête spatial épuré Apple HIG.
  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MON SOUFFLE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Méditation',
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
        const SizedBox(height: 6),
        Text(
          'Respire, ralentis et reconnecte-toi à ton calme intérieur.',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.05, end: 0);
  }

  /// Carte Héroïque avec mascotte velours respirant en boucle calme.
  Widget _buildMeditationHeroCard(bool isDark) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Mascotte velours 3D en posture calme de respiration
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.25),
                      AppColors.secondary.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Center(
                  child: MascotWithAccessories(
                    config: Mascot3DConfig(
                      interactionEnabled: false,
                      autoRotate: false,
                    ),
                    animation: MascotAnimations.breathe,
                    width: 72,
                    height: 72,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            controller.selectedBreathingType.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            '${controller.selectedBreathingType.cycleDuration}s',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      controller.selectedBreathingType.description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
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
                        Icons.air_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '6 cycles / min',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              'Rythme idéal',
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
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Système apaisé',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              'Vagus stimulé',
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
          const SizedBox(height: 16),

          // Bouton d'action principal immédiatement accessible en haut
          LiquidGlassButton(
            label: 'Commencer (${controller.selectedDurationMinutes} min)',
            icon: Icons.play_arrow_rounded,
            style: LiquidGlassButtonStyle.filled,
            isExpanded: true,
            isLoading: controller.isStartingSession,
            onPressed: () {
              ElyriiHaptics.light();
              controller.startSession();
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }

  /// Sélecteur de durée sous forme de segment glissant iOS.
  Widget _buildDurationSegmented(bool isDark) {
    final selectedColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final unselectedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: controller.selectedDurationMinutes,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        thumbColor: isDark ? const Color(0xFF3A3A3C) : Colors.white,
        padding: const EdgeInsets.all(3),
        children: {
          for (final d in _durations)
            d: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$d min',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: d == controller.selectedDurationMinutes
                          ? selectedColor
                          : unselectedColor,
                    ),
                  ),
                  Text(
                    d == 5
                        ? 'Rapide'
                        : d == 10
                        ? 'Idéal'
                        : 'Profond',
                    style: TextStyle(
                      fontSize: 10,
                      color: d == controller.selectedDurationMinutes
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight),
                    ),
                  ),
                ],
              ),
            ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          ElyriiHaptics.selection();
          controller.setDuration(value);
        },
      ),
    );
  }

  /// Liste des techniques respiratoires disponibles.
  Widget _buildBreathingTypeCards(bool isDark) {
    return Column(
      children: BreathingType.values.map((type) {
        final isSelected = controller.selectedBreathingType == type;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              if (isSelected) {
                ElyriiHaptics.light();
                controller.startSession();
              } else {
                ElyriiHaptics.selection();
                controller.setBreathingType(type);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? type.color.withValues(alpha: isDark ? 0.16 : 0.10)
                    : (isDark
                          ? AppColors.cardDark.withValues(alpha: 0.5)
                          : Colors.white),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: isSelected
                      ? type.color.withValues(alpha: 0.6)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05)),
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: type.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(type.icon, color: type.color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    type.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: type.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${type.cycleDuration}s',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: type.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              type.description,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? type.color
                            : (isDark ? Colors.white24 : Colors.black26),
                        size: 22,
                      ),
                    ],
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 14),
                    LiquidGlassButton(
                      label:
                          'Démarrer (${controller.selectedDurationMinutes} min)',
                      icon: Icons.play_arrow_rounded,
                      style: LiquidGlassButtonStyle.filled,
                      isExpanded: true,
                      isLoading: controller.isStartingSession,
                      onPressed: () {
                        ElyriiHaptics.light();
                        controller.startSession();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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

  Widget _buildSyncNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode hors ligne : tes minutes seront synchronisées dès le retour de la connexion.',
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
    );
  }
}
