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

/// Définition d'une intention de respiration bienveillante.
class _BreathingIntent {
  final BreathingType type;
  final String title;
  final String subtitle;
  final String emoji;
  final String benefit;

  const _BreathingIntent({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.benefit,
  });
}

/// Vue catalogue réinventée : Sanctuaire immersif du souffle (Apple HIG 2026).
///
/// Refonte complète UI/UX :
/// - Zéro aller-retour vertical : la mascotte respirante, le choix d'intention,
///   la durée et le bouton de lancement forment une composition unifiée.
/// - Intentions émotionnelles claires (Équilibre, Sommeil, Focus, Détente, Énergie)
///   au lieu d'un mur de fiches médicales austères.
/// - Mascotte 3D mise en valeur au centre d'un halo respiratoire ambiant doux.
/// - Sélecteur d'intentions horizontal tactile avec retour haptique à chaque tap.
/// - Bouton principal héroïque « Commencer » accessible sans scroller.
/// - Tirer-relâcher natif Cupertino ([CupertinoSliverRefreshControl]).
class MeditationCatalogView extends StatelessWidget {
  final MeditationController controller;

  const MeditationCatalogView({super.key, required this.controller});

  static const List<int> _durations = [5, 10, 15];

  static const List<_BreathingIntent> _intents = [
    _BreathingIntent(
      type: BreathingType.coherence,
      title: 'Équilibre',
      subtitle: 'Cohérence 5-5',
      emoji: '⚖️',
      benefit: 'Régule le rythme cardiaque et apaise le système nerveux',
    ),
    _BreathingIntent(
      type: BreathingType.relaxation478,
      title: 'Sommeil',
      subtitle: 'Méthode 4-7-8',
      emoji: '🌙',
      benefit: 'Apaisement profond du corps, idéal avant de dormir',
    ),
    _BreathingIntent(
      type: BreathingType.carree,
      title: 'Focus',
      subtitle: 'Respiration 4-4',
      emoji: '🎯',
      benefit: 'Clarté mentale immédiate et concentration accrue',
    ),
    _BreathingIntent(
      type: BreathingType.diaphragmatique,
      title: 'Détente',
      subtitle: 'Ventrale 4-2-6',
      emoji: '🌿',
      benefit: 'Relâche les tensions abdominales et le diaphragme',
    ),
    _BreathingIntent(
      type: BreathingType.ujjayi,
      title: 'Énergie',
      subtitle: 'Ujjayi 6-6',
      emoji: '🌊',
      benefit: 'Ancrage doux du yoga et réchauffement intérieur',
    ),
  ];

  _BreathingIntent get _currentIntent {
    return _intents.firstWhere(
      (i) => i.type == controller.selectedBreathingType,
      orElse: () => _intents.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final intent = _currentIntent;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // Tirer-relâcher natif Cupertino
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 250));
          },
        ),

        // 1. En-tête spatial épuré
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

        // 2. Composition principale unifiée
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.pageHorizontalPadding,
            8,
            AppDimensions.pageHorizontalPadding,
            120, // Dégagement pour le dock flottant
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A. Le Cœur du Sanctuaire (Mascotte respirante + intention active)
                _buildSanctuaryCard(intent, isDark),
                const SizedBox(height: 18),

                // B. Sélecteur d'intentions émotionnelles (Carrousel horizontal)
                _buildSectionHeader('Choisir une intention', isDark),
                const SizedBox(height: 10),
                _buildIntentCarousel(isDark),
                const SizedBox(height: 18),

                // C. Durée de la séance
                _buildSectionHeader('Durée de la pause', isDark),
                const SizedBox(height: 10),
                _buildDurationSelector(isDark),
                const SizedBox(height: 22),

                // D. Grand Bouton Héroïque de Lancement
                LiquidGlassButton(
                  label:
                      'Commencer la séance (${controller.selectedDurationMinutes} min)',
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
          ),
        ),
      ],
    );
  }

  /// En-tête épuré et aligné sans fioriture ni badge superflu.
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
        const SizedBox(height: 4),
        Text(
          'Un instant pour ralentir et te déposer.',
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

  /// Carte Maîtresse : Sanctuaire avec la Mascotte velours qui respire calmement.
  Widget _buildSanctuaryCard(_BreathingIntent intent, bool isDark) {
    final type = intent.type;

    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        children: [
          // Mascotte au centre avec halo respiratoire diffus
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  type.color.withValues(alpha: isDark ? 0.28 : 0.18),
                  type.color.withValues(alpha: isDark ? 0.10 : 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
            child: const Center(
              child: MascotWithAccessories(
                config: Mascot3DConfig(
                  interactionEnabled: false,
                  autoRotate: false,
                ),
                animation: MascotAnimations.breathe,
                width: 114,
                height: 114,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Titre de l'intention et promesse bienveillante
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(intent.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                intent.title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${type.cycleDuration}s',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: type.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                intent.benefit,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Décomposition du cycle en pilule unifiée à hauteur fixe
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < type.phases.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        '·',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: type.color.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  Text(
                    '${type.phases[i].label} ${type.phases[i].seconds}s',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carrousel horizontal des intentions de respiration.
  Widget _buildIntentCarousel(bool isDark) {
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _intents.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final intent = _intents[index];
          final isSelected = controller.selectedBreathingType == intent.type;
          final color = intent.type.color;

          return GestureDetector(
            onTap: () {
              ElyriiHaptics.selection();
              controller.setBreathingType(intent.type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 116,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: isDark ? 0.18 : 0.12)
                    : (isDark
                          ? AppColors.cardDark.withValues(alpha: 0.4)
                          : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05)),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(
                      alpha: isSelected ? (isDark ? 0.22 : 0.12) : 0.0,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        intent.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    intent.title,
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
                    intent.subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Sélecteur de durée sous forme de segment glissant iOS.
  Widget _buildDurationSelector(bool isDark) {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const SizedBox(width: 4),
                  Text(
                    d == 5
                        ? '• Rapide'
                        : d == 10
                        ? '• Idéal'
                        : '• Profond',
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

  Widget _buildSectionHeader(String title, bool isDark) {
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
}
