import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/mascot_3d_viewer.dart';
import '../providers/mascot_provider.dart';

enum _MascotTab { appearance, accessories, ambience }

class MascotCustomizationPage extends StatefulWidget {
  const MascotCustomizationPage({super.key});

  @override
  State<MascotCustomizationPage> createState() =>
      _MascotCustomizationPageState();
}

class _MascotCustomizationPageState extends State<MascotCustomizationPage> {
  _MascotTab _selectedTab = _MascotTab.appearance;

  static const List<_CosmeticOption> _appearanceOptions = [
    _CosmeticOption(
      id: 'aura_lavender',
      title: 'Aura lavande',
      subtitle: 'Une présence douce et rassurante',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.primary,
    ),
    _CosmeticOption(
      id: 'aura_mint',
      title: 'Aura menthe',
      subtitle: 'Fraiche, calme, très légère',
      icon: Icons.spa_rounded,
      color: AppColors.accent,
    ),
    _CosmeticOption(
      id: 'aura_peach',
      title: 'Aura pêche',
      subtitle: 'Chaleureuse pour le soir',
      icon: Icons.wb_twilight_rounded,
      color: AppColors.secondary,
    ),
  ];

  static const List<_CosmeticOption> _accessoryOptions = [
    _CosmeticOption(
      id: 'scarf_soft',
      title: 'Écharpe douce',
      subtitle: 'Petit repère de confort',
      icon: Icons.checkroom_rounded,
      color: AppColors.secondary,
    ),
    _CosmeticOption(
      id: 'journal_leaf',
      title: 'Feuille-journal',
      subtitle: 'Pour accompagner tes notes',
      icon: Icons.eco_rounded,
      color: AppColors.accent,
    ),
    _CosmeticOption(
      id: 'tiny_star',
      title: 'Étoile discrète',
      subtitle: 'Un rappel de progression douce',
      icon: Icons.star_rounded,
      color: AppColors.xpBar,
    ),
  ];

  static const List<_CosmeticOption> _ambienceOptions = [
    _CosmeticOption(
      id: 'ambience_morning',
      title: 'Matin clair',
      subtitle: 'Lumière simple pour commencer',
      icon: Icons.light_mode_rounded,
      color: AppColors.warning,
    ),
    _CosmeticOption(
      id: 'ambience_garden',
      title: 'Jardin calme',
      subtitle: 'Idéal pour le journal',
      icon: Icons.yard_rounded,
      color: AppColors.accent,
    ),
    _CosmeticOption(
      id: 'ambience_night',
      title: 'Soir paisible',
      subtitle: 'Contraste doux avant de dormir',
      icon: Icons.nightlight_round,
      color: AppColors.info,
    ),
  ];

  List<_CosmeticOption> get _currentOptions {
    switch (_selectedTab) {
      case _MascotTab.appearance:
        return _appearanceOptions;
      case _MascotTab.accessories:
        return _accessoryOptions;
      case _MascotTab.ambience:
        return _ambienceOptions;
    }
  }

  String get _currentTitle {
    switch (_selectedTab) {
      case _MascotTab.appearance:
        return 'Apparence';
      case _MascotTab.accessories:
        return 'Accessoires';
      case _MascotTab.ambience:
        return 'Ambiance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: SafeArea(
        bottom: false,
        child: Consumer<MascotProvider>(
          builder: (context, provider, _) {
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: _buildTabs(isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildOptionSection(isDark, provider),
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
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

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
                'Personnalise sa présence, sans pression',
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
    final selectedColor = _selectedColor(provider);
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

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
                      color:
                          selectedColor.withValues(alpha: isDark ? 0.10 : 0.08),
                    ),
                  ),
                  const Mascot3DViewer(
                    config: Mascot3DConfig(
                      cameraOrbitRadius: 4.0,
                      autoRotateSpeed: 8,
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
            Text(
              _previewTitle(provider),
              style: AppTextStyles.titleMedium(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Une customisation volontairement douce : elle accompagne ton espace mental sans voler l’attention.',
              style: AppTextStyles.bodySmall(color: subtitleColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Row(
      children: _MascotTab.values.map((tab) {
        final selected = tab == _selectedTab;
        final label = switch (tab) {
          _MascotTab.appearance => 'Apparence',
          _MascotTab.accessories => 'Accessoires',
          _MascotTab.ambience => 'Ambiance',
        };

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = tab);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelMedium(
                    color: selected
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOptionSection(bool isDark, MascotProvider provider) {
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentTitle,
          style: AppTextStyles.titleMedium(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choisis un détail qui rend Elyrii plus familier.',
          style: AppTextStyles.bodySmall(color: subtitleColor),
        ),
        const SizedBox(height: 12),
        ..._currentOptions.map(
          (option) {
            final selected = provider.mascot.equippedCosmetics.contains(
              option.id,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CosmeticOptionTile(
                option: option,
                selected: selected,
                isDark: isDark,
                onTap: () => provider.equipCosmetic(option.id),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _selectedColor(MascotProvider provider) {
    final ids = provider.mascot.equippedCosmetics;
    for (final option in [
      ..._appearanceOptions,
      ..._accessoryOptions,
      ..._ambienceOptions,
    ]) {
      if (ids.contains(option.id)) return option.color;
    }
    return AppColors.primary;
  }

  String _previewTitle(MascotProvider provider) {
    final count = provider.mascot.equippedCosmetics.length;
    if (count == 0) return 'Présence par défaut';
    if (count == 1) return '1 détail équipé';
    return '$count détails équipés';
  }
}

class _CosmeticOptionTile extends StatelessWidget {
  final _CosmeticOption option;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _CosmeticOptionTile({
    required this.option,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return LiquidGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: selected
          ? option.color.withValues(alpha: isDark ? 0.16 : 0.12)
          : null,
      borderColor: selected ? option.color.withValues(alpha: 0.35) : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: option.color.withValues(alpha: isDark ? 0.18 : 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(option.icon, color: option.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: AppTextStyles.titleSmall(
                    color: selected ? option.color : textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.subtitle,
                  style: AppTextStyles.bodySmall(color: subtitleColor),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: selected
                ? Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey('selected'),
                    color: option.color,
                    size: 22,
                  )
                : Icon(
                    Icons.circle_outlined,
                    key: const ValueKey('idle'),
                    color: subtitleColor.withValues(alpha: 0.35),
                    size: 22,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CosmeticOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _CosmeticOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
