import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../routes/app_routes.dart';
import '../../../gamification/presentation/providers/gamification_provider.dart';
import '../providers/mascot_provider.dart';

class MascotCustomizationPage extends StatefulWidget {
  const MascotCustomizationPage({super.key});

  @override
  State<MascotCustomizationPage> createState() =>
      _MascotCustomizationPageState();
}

class _MascotCustomizationPageState extends State<MascotCustomizationPage> {
  static const String _seenUnlocksKey = 'elyrii_seen_cosmetic_unlocks';

  static const List<_AccessoryDef> _accessories = [
    _AccessoryDef(
      id: 'custom1',
      name: 'Chapeau de diplômé',
      emoji: '🎓',
      requiredChallenges: 1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final mascotProvider = context.read<MascotProvider>();
      final gamification = context.read<GamificationProvider>();
      await mascotProvider.loadMascot();
      await gamification.loadAll();
      if (mounted) _checkForNewUnlocks(gamification.completedChallenges.length);
    });
  }

  /// Detecte les cosmétiques nouvellement debloques et affiche une popup.
  Future<void> _checkForNewUnlocks(int completedCount) async {
    final newlyUnlocked = _accessories.where((acc) {
      final isUnlocked = completedCount >= acc.requiredChallenges;
      return isUnlocked;
    }).toList();
    if (newlyUnlocked.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenUnlocksKey) ?? const <String>[];
    final toCelebrate = newlyUnlocked
        .where((acc) => !seen.contains(acc.id))
        .toList();

    if (toCelebrate.isEmpty) return;

    // Marquer comme vu immediatement
    await prefs.setStringList(
      _seenUnlocksKey,
      {...seen, ...toCelebrate.map((a) => a.id)}.toList(),
    );

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    for (final acc in toCelebrate) {
      await _showUnlockCelebration(isDark, acc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: SafeArea(
        bottom: false,
        child: Consumer2<MascotProvider, GamificationProvider>(
          builder: (context, provider, gamification, _) {
            final completedCount = gamification.completedChallenges.length;
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimensions.pageHorizontalPadding,
                      topPadding > 0 ? AppDimensions.spacingSm : 0,
                      AppDimensions.pageHorizontalPadding,
                      AppDimensions.spacingMd,
                    ),
                    child: _buildHeader(context, isDark, provider),
                  ),
                ),
                SliverToBoxAdapter(child: _buildPreview(isDark, provider)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: _buildSectionTitle(isDark),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final theme = MascotThemes.all[index];
                      final isSelected = provider.mascot.themeId == theme.id;
                      return _ThemeCard(
                        theme: theme,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          provider.setTheme(theme.id);
                        },
                      );
                    }, childCount: MascotThemes.all.length),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                    child: _buildAccessoriesTitle(isDark),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _buildAccessoriesGrid(
                      isDark,
                      provider,
                      completedCount,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    MascotProvider provider,
  ) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Row(
      children: [
        LiquidGlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          size: 44,
          color: textColor,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elyrii',
                style: AppTextStyles.headlineSmall(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Choisis son thème visuel',
                style: AppTextStyles.bodySmall(color: subtitleColor),
              ),
            ],
          ),
        ),
        LiquidGlassIconButton(
          icon: Icons.restart_alt_rounded,
          size: 44,
          color: subtitleColor,
          onPressed: provider.resetToDefault,
        ),
      ],
    );
  }

  Widget _buildPreview(bool isDark, MascotProvider provider) {
    final theme = provider.currentTheme;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LiquidGlassCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        color: isDark
            ? AppColors.liquidGlassBackgroundDark
            : AppColors.liquidGlassBackgroundLight,
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.accentColor.withValues(
                        alpha: isDark ? 0.10 : 0.08,
                      ),
                    ),
                  ),
                  const MascotWithAccessories(
                    config: Mascot3DConfig(
                      autoRotate: false,
                      interactionEnabled: false,
                      showLoadingIndicator: true,
                    ),
                    width: 210,
                    height: 220,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(theme.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  theme.name,
                  style: AppTextStyles.titleMedium(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              theme.description,
              style: AppTextStyles.bodySmall(color: subtitleColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thèmes',
          style: AppTextStyles.titleMedium(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Recolore Elyrii selon ton humeur ou la saison.',
          style: AppTextStyles.bodySmall(color: subtitleColor),
        ),
      ],
    );
  }

  Widget _buildAccessoriesTitle(bool isDark) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accessoires',
          style: AppTextStyles.titleMedium(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Débloque des récompenses en relevant tes défis.',
          style: AppTextStyles.bodySmall(color: subtitleColor),
        ),
      ],
    );
  }

  Widget _buildAccessoriesGrid(
    bool isDark,
    MascotProvider provider,
    int completedCount,
  ) {
    return Column(
      children: _accessories.map((acc) {
        final isEquipped = provider.mascot.equippedCosmetics.contains(acc.id);
        final isLocked = completedCount < acc.requiredChallenges;
        final theme = provider.currentTheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _AccessoryCard(
            name: acc.name,
            emoji: acc.emoji,
            isEquipped: isEquipped,
            isLocked: isLocked,
            requiredChallenges: acc.requiredChallenges,
            completedChallenges: completedCount,
            isDark: isDark,
            accentColor: theme.accentColor,
            onTap: () {
              HapticFeedback.selectionClick();
              provider.equipCosmetic(acc.id);
            },
            onLockedTap: () => _showLockedDialog(isDark, acc),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showUnlockCelebration(bool isDark, _AccessoryDef acc) async {
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => _UnlockCelebrationDialog(
        accessory: acc,
        isDark: isDark,
        onEquip: () {
          Navigator.pop(context);
          HapticFeedback.selectionClick();
          context.read<MascotProvider>().equipCosmetic(acc.id);
        },
      ),
    );
  }

  void _showLockedDialog(bool isDark, _AccessoryDef acc) {
    final bodyColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    showLiquidGlassDialog(
      context: context,
      title: 'Encore un petit effort…',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.12),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Termine au moins ${acc.requiredChallenges} défi dans ton atelier '
            'de présence pour débloquer le « ${acc.name} » et le porter '
            'fièrement.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(
              color: bodyColor,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
      actions: [
        LiquidGlassDialogAction(
          label: 'Plus tard',
          onPressed: () => Navigator.pop(context),
        ),
        LiquidGlassDialogAction(
          label: 'Voir mes défis',
          isDefault: true,
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.challenges);
          },
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final MascotTheme theme;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        color: isSelected
            ? theme.accentColor.withValues(alpha: isDark ? 0.16 : 0.12)
            : null,
        borderColor: isSelected
            ? theme.accentColor.withValues(alpha: 0.45)
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.accentColor.withValues(alpha: 0.35),
                    theme.accentColor.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
                border: Border.all(
                  color: isSelected
                      ? theme.accentColor.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(theme.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              theme.name,
              style: AppTextStyles.labelMedium(
                color: isSelected ? theme.accentColor : textColor,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isSelected
                  ? Container(
                      key: const ValueKey('selected'),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.accentColor,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pop-up celebrative affichee lors du deblocage d'un cosmétique.
class _UnlockCelebrationDialog extends StatefulWidget {
  final _AccessoryDef accessory;
  final bool isDark;
  final VoidCallback onEquip;

  const _UnlockCelebrationDialog({
    required this.accessory,
    required this.isDark,
    required this.onEquip,
  });

  @override
  State<_UnlockCelebrationDialog> createState() =>
      _UnlockCelebrationDialogState();
}

class _UnlockCelebrationDialogState extends State<_UnlockCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final acc = widget.accessory;
    final titleColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final bodyColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    // Couleurs des particules "confettis"
    const confettiColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.xpBar,
      AppColors.success,
    ];

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 340),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppDimensions.blurSigmaLiquidGlass,
                    sigmaY: AppDimensions.blurSigmaLiquidGlass,
                  ),
                  child: AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (context, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Carte principale
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [
                                        AppColors.liquidGlassBackgroundDark,
                                        AppColors.liquidGlassBackgroundDarkEnd,
                                      ]
                                    : [
                                        AppColors.liquidGlassBackgroundLight,
                                        AppColors.liquidGlassBackgroundLightEnd,
                                      ],
                              ),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: isDark ? 0.18 : 0.12,
                                  ),
                                  blurRadius: 40,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Badge "Nouveau"
                                Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: isDark ? 0.18 : 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: AppColors.success.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.workspace_premium_rounded,
                                            size: 14,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'RÉCOMPENSE DÉBLOQUÉE',
                                            style: AppTextStyles.labelSmall(
                                              color: isDark
                                                  ? AppColors.successDark
                                                  : AppColors.successDark,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 200.ms)
                                    .slideY(begin: -0.3),
                                const SizedBox(height: 24),

                                // Halo + emoji de l'accessoire
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Halo pulsant
                                    AnimatedBuilder(
                                      animation: _shimmerCtrl,
                                      builder: (context, _) {
                                        return Container(
                                          width: 110,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                AppColors.primary.withValues(
                                                  alpha:
                                                      0.25 +
                                                      0.15 *
                                                          (0.5 +
                                                              0.5 *
                                                                  _shimmerCtrl
                                                                      .value),
                                                ),
                                                AppColors.accent.withValues(
                                                  alpha: 0.08,
                                                ),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.6, 1.0],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Text(
                                          acc.emoji,
                                          style: const TextStyle(fontSize: 56),
                                        )
                                        .animate()
                                        .fadeIn(duration: 500.ms)
                                        .scale(
                                          begin: const Offset(0.3, 0.3),
                                          end: const Offset(1, 1),
                                          curve: Curves.elasticOut,
                                          delay: 100.ms,
                                        ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                Text(
                                      acc.name,
                                      style: AppTextStyles.headlineSmall(
                                        color: titleColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                    .animate()
                                    .fadeIn(delay: 300.ms)
                                    .slideY(begin: 0.15),
                                const SizedBox(height: 10),
                                Text(
                                      'Bravo ! Tu as relevé un défi avec courage. '
                                      'Cette récompense est maintenant tienne, '
                                      'équipe-la fièrement !',
                                      style: AppTextStyles.bodyMedium(
                                        color: bodyColor,
                                      ).copyWith(height: 1.55),
                                      textAlign: TextAlign.center,
                                    )
                                    .animate()
                                    .fadeIn(delay: 450.ms)
                                    .slideY(begin: 0.15),
                                const SizedBox(height: 28),

                                // Bouton equiper
                                LiquidGlassButton(
                                      label: 'L\'équiper maintenant',
                                      icon: Icons.check_rounded,
                                      isExpanded: true,
                                      onPressed: widget.onEquip,
                                    )
                                    .animate()
                                    .fadeIn(delay: 600.ms)
                                    .slideY(begin: 0.2),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Plus tard',
                                    style: AppTextStyles.bodyMedium(
                                      color: bodyColor,
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 700.ms),
                              ],
                            ),
                          ),

                          // Particules "confettis"
                          ...List.generate(16, (i) {
                            final angle =
                                (i / 16) * math.pi * 2 +
                                _shimmerCtrl.value * 0.8;
                            final radius =
                                80.0 +
                                30.0 *
                                    (0.5 +
                                        0.5 *
                                            math.sin(
                                              _shimmerCtrl.value * 2 * math.pi +
                                                  i,
                                            ));
                            final dx = radius * math.cos(angle);
                            final dy = radius * math.sin(angle);
                            return Positioned(
                              left: 150 + dx,
                              top: 80 + dy,
                              child:
                                  Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color:
                                              confettiColors[i %
                                                  confettiColors.length],
                                          shape: i % 2 == 0
                                              ? BoxShape.circle
                                              : BoxShape.rectangle,
                                          borderRadius: i % 2 == 0
                                              ? null
                                              : BorderRadius.circular(1),
                                        ),
                                      )
                                      .animate(onPlay: (c) => c.repeat())
                                      .fadeIn(delay: (i * 60).ms)
                                      .scale(
                                        begin: const Offset(0.5, 0.5),
                                        end: const Offset(1, 1),
                                      ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessoryDef {
  final String id;
  final String name;
  final String emoji;

  /// Nombre de défis à compléter pour débloquer cet accessoire.
  final int requiredChallenges;

  const _AccessoryDef({
    required this.id,
    required this.name,
    required this.emoji,
    this.requiredChallenges = 0,
  });
}

class _AccessoryCard extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isEquipped;
  final bool isLocked;
  final int requiredChallenges;
  final int completedChallenges;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onLockedTap;

  const _AccessoryCard({
    required this.name,
    required this.emoji,
    required this.isEquipped,
    required this.isLocked,
    required this.requiredChallenges,
    required this.completedChallenges,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final tertiaryColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;

    final progress = requiredChallenges > 0
        ? (completedChallenges / requiredChallenges).clamp(0.0, 1.0)
        : 1.0;

    return GestureDetector(
      onTap: isLocked ? onLockedTap : onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: isEquipped
            ? accentColor.withValues(alpha: isDark ? 0.16 : 0.12)
            : null,
        borderColor: isEquipped ? accentColor.withValues(alpha: 0.45) : null,
        child: Row(
          children: [
            _buildEmojiCircle(tertiaryColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.titleSmall(
                            color: isLocked
                                ? textColor
                                : (isEquipped ? accentColor : textColor),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusPill(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isLocked) ...[
                    Text(
                      'Termine $requiredChallenges défi pour débloquer',
                      style: AppTextStyles.labelSmall(color: tertiaryColor),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary.withValues(
                            alpha: isDark ? 0.9 : 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$completedChallenges / $requiredChallenges défi',
                      style: AppTextStyles.labelSmall(
                        color: tertiaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else
                    Text(
                      isEquipped
                          ? 'Touche pour retirer'
                          : 'Touche pour équiper',
                      style: AppTextStyles.labelSmall(color: subtitleColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiCircle(Color tertiaryColor) {
    if (isLocked) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.25,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    width: 0.5,
                  ),
                ),
                child: Icon(Icons.lock_rounded, size: 12, color: tertiaryColor),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accentColor.withValues(alpha: 0.30),
            accentColor.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        border: Border.all(
          color: isEquipped
              ? accentColor.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
    );
  }

  Widget _buildStatusPill() {
    if (isLocked) {
      return _pill(
        label: 'Verrouillé',
        icon: Icons.lock_rounded,
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
        filled: false,
      );
    }
    if (isEquipped) {
      return _pill(
        label: 'Équipé',
        icon: Icons.check_circle_rounded,
        color: accentColor,
        filled: true,
      );
    }
    return _pill(
      label: 'Débloqué',
      icon: Icons.workspace_premium_rounded,
      color: isDark ? AppColors.accentDark : AppColors.successDark,
      filled: true,
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: isDark ? 0.18 : 0.14)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0.4 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
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
}
