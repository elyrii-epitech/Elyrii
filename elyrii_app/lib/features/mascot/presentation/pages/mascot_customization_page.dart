import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../widgets/accessory_card.dart';
import '../widgets/unlock_celebration_dialog.dart';
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
import '../../../../core/widgets/mascot_contact_shadow.dart';
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

class _MascotCustomizationPageState extends State<MascotCustomizationPage>
    with TickerProviderStateMixin {
  static const String _seenUnlocksKey = 'elyrii_seen_cosmetic_unlocks';

  /// Respiration lente de l'aperçu : anime le flottement de la mascotte et
  /// la taille/opacité de son ombre de contact au sol.
  late final AnimationController _breathController;

  static const List<AccessoryDef> _accessories = [
    AccessoryDef(
      id: 'custom1',
      name: 'Chapeau de diplômé',
      emoji: '🎓',
      requiredChallenges: 1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final mascotProvider = context.read<MascotProvider>();
      final gamification = context.read<GamificationProvider>();
      await mascotProvider.loadMascot();
      await gamification.loadAll();
      if (mounted) _checkForNewUnlocks(gamification.completedChallenges.length);
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
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
                          ElyriiHaptics.selection();
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

  /// Aperçu plein cadre de la mascotte : éclairage d'ambiance dégradé aux
  /// couleurs du thème courant, flottement respirant et ombre de contact
  /// dynamique au sol.
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          children: [
            // Aperçu plein cadre : mascotte flottante sur un éclairage
            // d'ambiance doux, ancrée par une ombre de contact au sol
            // (aucun disque plat ni anneau décoratif sous le modèle).
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 320,
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _breathController,
                  child: const MascotWithAccessories(
                    config: Mascot3DConfig(
                      autoRotate: false,
                      interactionEnabled: false,
                      showLoadingIndicator: true,
                    ),
                    width: 250,
                    height: 270,
                  ),
                  builder: (context, mascot) {
                    final t = Curves.easeInOut.transform(
                      _breathController.value,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Éclairage d'ambiance : léger dégradé vertical aux
                        // couleurs du thème, en fondu lors d'un changement.
                        Positioned.fill(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  theme.accentColor.withValues(
                                    alpha: isDark ? 0.12 : 0.08,
                                  ),
                                  theme.accentColor.withValues(alpha: 0.02),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Mascotte flottant doucement au-dessus du sol.
                        Transform.translate(
                          offset: Offset(0, -5.0 * t),
                          child: mascot,
                        ),
                        // Ombre de contact : s'élargit et s'atténue quand la
                        // mascotte s'élève, se resserre à la descente.
                        Positioned(
                          bottom: 18,
                          child: MascotContactShadow(
                            width: 150,
                            elevation: 0.12 + t * 0.38,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
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
          child: AccessoryCard(
            name: acc.name,
            emoji: acc.emoji,
            isEquipped: isEquipped,
            isLocked: isLocked,
            requiredChallenges: acc.requiredChallenges,
            completedChallenges: completedCount,
            isDark: isDark,
            accentColor: theme.accentColor,
            onTap: () {
              ElyriiHaptics.selection();
              provider.equipCosmetic(acc.id);
            },
            onLockedTap: () => _showLockedDialog(isDark, acc),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showUnlockCelebration(bool isDark, AccessoryDef acc) async {
    ElyriiHaptics.success();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => UnlockCelebrationDialog(
        accessory: acc,
        isDark: isDark,
        onEquip: () {
          Navigator.pop(context);
          ElyriiHaptics.selection();
          context.read<MascotProvider>().equipCosmetic(acc.id);
        },
      ),
    );
  }

  void _showLockedDialog(bool isDark, AccessoryDef acc) {
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
            context.go(AppRoutes.challenges);
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
