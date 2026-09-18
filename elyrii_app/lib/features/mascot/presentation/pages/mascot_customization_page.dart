import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../widgets/accessory_card.dart';
import '../widgets/unlock_celebration_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../../../../core/widgets/mascot_bounce.dart';
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

  MascotAnimation _previewAnimation = MascotAnimations.idle;
  int _previewTrigger = 0;
  String? _selectedCategory;

  List<String> get _accessoryCategories =>
      _accessories.map((a) => a.category).toSet().toList();

  void _react(MascotAnimation animation) {
    setState(() {
      _previewAnimation = animation;
      _previewTrigger++;
    });
  }

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

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: SafeArea(
        bottom: false,
        child: Consumer2<MascotProvider, GamificationProvider>(
          builder: (context, provider, gamification, _) {
            final completedCount = gamification.completedChallenges.length;
            return Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Dégagement de l'en-tête épinglé (flèche + titre + reset).
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppDimensions.spacingSm + 72),
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
                          final isSelected =
                              provider.mascot.themeId == theme.id;
                          return _ThemeCard(
                            theme: theme,
                            isSelected: isSelected,
                            isDark: isDark,
                            onTap: () {
                              ElyriiHaptics.selection();
                              if (provider.mascot.themeId != theme.id) {
                                provider.setTheme(theme.id);
                                _react(MascotAnimations.proud);
                              }
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
                ),
                // En-tête épinglé sur fond opaque : ne suit pas le scroll.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: isDark
                        ? AppColors.scaffoldDark
                        : AppColors.scaffoldLight,
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.pageHorizontalPadding,
                      AppDimensions.spacingSm,
                      AppDimensions.pageHorizontalPadding,
                      8,
                    ),
                    child: _buildHeader(context, isDark, provider),
                  ),
                ),
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
        ElyriiBackButton(color: textColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Text(
                'Personnalisation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.1,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Thèmes et accessoires d\'Elyrii.',
                textAlign: TextAlign.center,
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
  /// couleurs du thème courant, gestes natifs.
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
            // Les gestes sont dans le GLB ; le viewer reste ancré au sol.
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.accentColor.withValues(
                                alpha: isDark ? .12 : .08,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    MascotBounce(
                      trigger: _previewTrigger,
                      child: MascotWithAccessories(
                        config: const Mascot3DConfig(),
                        animation: _previewAnimation,
                        animationTrigger: _previewTrigger,
                        width: 260,
                        height: 280,
                      ),
                    ),
                  ],
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
            const SizedBox(height: 8),
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

  /// Atelier d'accessoires : pilules de catégories (dès que plusieurs
  /// familles existent) puis cartes filtrées sur la catégorie active.
  Widget _buildAccessoriesGrid(
    bool isDark,
    MascotProvider provider,
    int completedCount,
  ) {
    final categories = _accessoryCategories;
    final selected =
        _selectedCategory != null && categories.contains(_selectedCategory)
        ? _selectedCategory!
        : categories.first;
    final accent = provider.currentTheme.accentColor;
    final visible = _accessories.where((a) => a.category == selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.length > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                GestureDetector(
                  onTap: () {
                    ElyriiHaptics.selection();
                    setState(() => _selectedCategory = category);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: category == selected
                          ? accent.withValues(alpha: isDark ? 0.22 : 0.14)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: category == selected
                            ? accent.withValues(alpha: 0.5)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                      ),
                    ),
                    child: Text(
                      category,
                      style: AppTextStyles.labelMedium(
                        color: category == selected
                            ? accent
                            : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        for (final acc in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildAccessoryCard(acc, isDark, provider, completedCount),
          ),
      ],
    );
  }

  Widget _buildAccessoryCard(
    AccessoryDef acc,
    bool isDark,
    MascotProvider provider,
    int completedCount,
  ) {
    final isEquipped = provider.mascot.equippedCosmetics.contains(acc.id);
    final isLocked = completedCount < acc.requiredChallenges;
    return AccessoryCard(
      name: acc.name,
      emoji: acc.emoji,
      isEquipped: isEquipped,
      isLocked: isLocked,
      requiredChallenges: acc.requiredChallenges,
      completedChallenges: completedCount,
      isDark: isDark,
      accentColor: provider.currentTheme.accentColor,
      onTap: () {
        ElyriiHaptics.selection();
        provider.equipCosmetic(acc.id);
        _react(isEquipped ? MascotAnimations.settle : MascotAnimations.proud);
      },
      onLockedTap: () => _showLockedDialog(isDark, acc),
    );
  }

  Future<void> _showUnlockCelebration(bool isDark, AccessoryDef acc) async {
    ElyriiHaptics.success();
    _react(MascotAnimations.celebrate);
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
          _react(MascotAnimations.proud);
        },
      ),
    );
  }

  void _showLockedDialog(bool isDark, AccessoryDef acc) {
    _react(MascotAnimations.curious);
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
