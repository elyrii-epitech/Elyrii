import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/design_system/haptics/elyrii_haptics.dart';
import '../../core/widgets/glass_bubble_button.dart';
import '../../core/widgets/glass_navigation_bar.dart';
import '../../core/theme/app_dimensions.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  static bool usesAccessibleDock(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppDimensions.dockMinWidth ||
      MediaQuery.textScalerOf(context).scale(11) >
          AppDimensions.dockMaxLabelSize;

  static double dockHeightOf(BuildContext context) =>
      usesAccessibleDock(context)
      ? AppDimensions.accessibleDockHeight(
          MediaQuery.textScalerOf(context).scale(16),
        )
      : AppDimensions.dockHeight;

  static double bottomClearanceOf(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return dockHeightOf(context) +
        AppDimensions.dockBottomMargin(bottom) +
        bottom +
        AppDimensions.spacing24;
  }

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Symbols.home_rounded, label: 'Accueil', index: 0),
    GlassNavItem(icon: Symbols.yard_rounded, label: 'Défis', index: 1),
    GlassNavItem(icon: Symbols.book_2_rounded, label: 'Journal', index: 2),
    GlassNavItem(icon: Symbols.spa_rounded, label: 'Méditer', index: 3),
    GlassNavItem(icon: Icons.route_rounded, label: 'Programmes', index: 4),
  ];

  void _onTabSelected(int index) {
    ElyriiHaptics.selection();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = navigationShell.currentIndex;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomMargin = AppDimensions.dockBottomMargin(bottomInset);
    final accessibleDock = AppShell.usesAccessibleDock(context);

    return Scaffold(
      extendBody: true,
      // Chat owns keyboard avoidance so nested scaffolds do not resize twice.
      resizeToAvoidBottomInset: currentIndex != 5,
      body: navigationShell,
      bottomNavigationBar:
          currentIndex == 5 && MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : Align(
              heightFactor: 1,
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimensions.maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.spacing16,
                    0,
                    AppDimensions.spacing16,
                    bottomMargin,
                  ),
                  child: accessibleDock
                      ? SizedBox(
                          height: AppShell.dockHeightOf(context),
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(currentIndex),
                            initialValue: currentIndex,
                            itemHeight: null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Navigation',
                            ),
                            items: [
                              for (var i = 0; i < 6; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.spacing12,
                                    ),
                                    child: Text(
                                      i == 5
                                          ? 'Chat Elyrii'
                                          : _navItems[i].label,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) _onTabSelected(value);
                            },
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: GlassNavigationBar(
                                items: _navItems,
                                currentIndex: currentIndex < 5
                                    ? currentIndex
                                    : -1,
                                onItemSelected: _onTabSelected,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacing8),
                            GlassBubbleButton(
                              icon: Icons.chat_bubble_rounded,
                              onTap: () => _onTabSelected(5),
                              size: AppDimensions.dockHeight,
                              isDark: isDark,
                              isSelected: currentIndex == 5,
                              tooltip: 'Chat Elyrii',
                              iconAsset: 'assets/brand/mascot_nav.png',
                              iconAssetSize: AppDimensions.dockAvatar,
                            ),
                          ],
                        ),
                ),
              ),
            ),
    );
  }
}
