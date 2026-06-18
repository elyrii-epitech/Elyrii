import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/mascot_3d_viewer.dart';
import '../providers/mascot_provider.dart';

class MascotCustomizationPage extends StatefulWidget {
  const MascotCustomizationPage({super.key});

  @override
  State<MascotCustomizationPage> createState() =>
      _MascotCustomizationPageState();
}

class _MascotCustomizationPageState extends State<MascotCustomizationPage> {
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
                    child: _buildAccessoriesGrid(isDark, provider),
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

    final hasHat = provider.mascot.equippedCosmetics.contains('custom1');
    final matrix = theme.id == 'nature' ? null : theme.colorMatrix;

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
                  Mascot3DViewer(
                    config: const Mascot3DConfig(
                      autoRotate: false,
                      interactionEnabled: false,
                      showLoadingIndicator: true,
                    ),
                    width: 210,
                    height: 220,
                    colorMatrix: matrix,
                  ),
                  if (hasHat)
                    const Positioned(
                      top: 10,
                      child: Mascot3DViewer(
                        config: Mascot3DConfig(
                          assetPath: 'assets/custom1.glb',
                          autoRotate: false,
                          interactionEnabled: false,
                          showLoadingIndicator: false,
                        ),
                        width: 90,
                        height: 90,
                      ),
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
          'Équipe Elyrii avec des objets débloqués.',
          style: AppTextStyles.bodySmall(color: subtitleColor),
        ),
      ],
    );
  }

  Widget _buildAccessoriesGrid(bool isDark, MascotProvider provider) {
    const accessories = [
      _AccessoryDef(id: 'custom1', name: 'Chapeau de diplomé', emoji: '🎓'),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: accessories.map((acc) {
        final isEquipped = provider.mascot.equippedCosmetics.contains(acc.id);
        final theme = provider.currentTheme;
        return _AccessoryCard(
          name: acc.name,
          emoji: acc.emoji,
          isEquipped: isEquipped,
          isDark: isDark,
          accentColor: theme.accentColor,
          onTap: () {
            HapticFeedback.selectionClick();
            provider.equipCosmetic(acc.id);
          },
        );
      }).toList(),
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

class _AccessoryDef {
  final String id;
  final String name;
  final String emoji;

  const _AccessoryDef({
    required this.id,
    required this.name,
    required this.emoji,
  });
}

class _AccessoryCard extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isEquipped;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  const _AccessoryCard({
    required this.name,
    required this.emoji,
    required this.isEquipped,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isEquipped
            ? accentColor.withValues(alpha: isDark ? 0.16 : 0.12)
            : null,
        borderColor: isEquipped ? accentColor.withValues(alpha: 0.45) : null,
        child: SizedBox(
          width: 140,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.titleSmall(
                        color: isEquipped ? accentColor : textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEquipped ? 'Equipé' : 'Touche pour équiper',
                      style: AppTextStyles.labelSmall(color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
