import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/haptics/elyrii_haptics.dart';
import '../../core/widgets/glass_bubble_button.dart';
import '../../core/widgets/glass_navigation_bar.dart';

/// Shell principal hébergeant les branches d'onglets persistantes sous GoRouter.
///
/// Contrairement à l'ancien `HomeNavigation` qui détruisait les pages lors du changement d'onglet,
/// [StatefulNavigationShell] préserve l'arbre d'état complet, le scroll et la mémoire de chaque vue.
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  late List<AnimationController> _iconControllers;

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.home_rounded, label: 'Accueil', index: 0),
    GlassNavItem(icon: Icons.yard_rounded, label: 'Jardin', index: 1),
    GlassNavItem(icon: Icons.book_rounded, label: 'Journal', index: 2),
    GlassNavItem(icon: Icons.spa_rounded, label: 'Méditation', index: 3),
    GlassNavItem(icon: Icons.person_rounded, label: 'Coach', index: 4),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      _navItems.length,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    final currentIndex = widget.navigationShell.currentIndex;
    if (currentIndex < _iconControllers.length) {
      _iconControllers[currentIndex].value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIdx = oldWidget.navigationShell.currentIndex;
    final newIdx = widget.navigationShell.currentIndex;
    if (oldIdx != newIdx) {
      if (oldIdx < _iconControllers.length) {
        _iconControllers[oldIdx].reverse();
      }
      if (newIdx < _iconControllers.length) {
        _iconControllers[newIdx].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabSelected(int index) {
    ElyriiHaptics.selection();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = widget.navigationShell.currentIndex;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // UIKit / liquid_glass_widgets : verticalPadding = 20.0 au-dessus du Home Indicator
    final bottomMargin = bottomInset > 0 ? 20.0 : 16.0;

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomMargin,
        ),
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: GlassNavigationBar(
                items: _navItems,
                currentIndex: currentIndex < 5 ? currentIndex : -1,
                onItemSelected: _onTabSelected,
                iconControllers: _iconControllers,
                isDark: isDark,
                margin: EdgeInsets.zero,
                height: 64,
                borderRadius: 32,
              ),
            ),
            const SizedBox(width: 10),
            GlassBubbleButtonStateful(
              icon: Icons.chat_bubble_rounded,
              onTap: () => _onTabSelected(5),
              size: 64,
              isDark: isDark,
              isSelected: currentIndex == 5,
              tooltip: 'Chatbot',
            ),
          ],
        ),
      ),
    );
  }
}
