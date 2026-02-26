import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/gamification/presentation/pages/challenges_page.dart';
import '../features/journal/presentation/pages/journal_page.dart';
import '../features/coach/presentation/pages/coach_page.dart';
import '../features/meditation/presentation/pages/meditation_page.dart';
import '../features/chatbot/presentation/pages/chatbot_page.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/widgets/glass_navigation_bar.dart';
import '../core/widgets/glass_bubble_button.dart';
import '../core/services/glass_performance_service.dart';

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<AnimationController> _iconControllers;
  late AnimationController _navBarController;
  late Animation<double> _navBarAnimation;
  late AnimationController _navBarPulseController;
  late Animation<double> _navBarScaleAnimation;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  late AnimationController _pageTransitionController;
  late Animation<double> _pageScaleAnimation;
  late Animation<double> _pageFadeAnimation;

  // Lazy loading: pages are built only when first accessed
  final Map<int, Widget> _loadedPages = {};

  // Page builders for lazy instantiation
  static const List<Widget Function()> _pageBuilders = [
    DashboardPage.new,
    ChallengesPage.new,
    JournalPage.new,
    MeditationPage.new,
    CoachPage.new,
    ChatbotPage.new,
  ];

  /// Get or create a page lazily
  Widget _getPage(int index) {
    return _loadedPages.putIfAbsent(index, () => _pageBuilders[index]());
  }

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
    GlassNavItem(
        icon: Icons.emoji_events_rounded, label: 'Challenges', index: 1),
    GlassNavItem(icon: Icons.book_rounded, label: 'Journal', index: 2),
    GlassNavItem(icon: Icons.spa_rounded, label: 'Meditation', index: 3),
    GlassNavItem(icon: Icons.person_rounded, label: 'Coach', index: 4),
  ];

  @override
  void initState() {
    super.initState();

    // Créer des controllers d'animation pour chaque item (navbar + chatbot = 6)
    _iconControllers = List.generate(
      6,
      (index) => AnimationController(
        duration: const Duration(
            milliseconds: AppDimensions.animationDurationLiquidGlass),
        vsync: this,
      ),
    );

    // Animations de scale (agrandissement)

    // Animations de bounce (rebond)

    // Animation d'apparition de la navbar
    _navBarController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _navBarAnimation = CurvedAnimation(
      parent: _navBarController,
      curve: Curves.easeOutBack,
    );

    // Animation de pulse pour la navbar (zoom/dézoom) - iOS 26: légèrement plus prononcé
    _navBarPulseController = AnimationController(
      duration: const Duration(milliseconds: 200), // Plus rapide
      vsync: this,
    );

    _navBarScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02, // iOS 26: de 1.015 à 1.02
    ).animate(
      CurvedAnimation(
        parent: _navBarPulseController,
        curve: Curves.easeOutCubic, // iOS 26: easeOutCubic
      ),
    );

    // Animation de flash blanc (durée augmentée pour être visible)
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 450), // Légèrement plus court
      vsync: this,
    );

    _flashAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _flashController,
        curve: Curves.easeOut,
      ),
    );

    // iOS 26: Animation de transition de page
    _pageTransitionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _pageScaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _pageTransitionController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pageFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _pageTransitionController,
        curve: Curves.easeOut,
      ),
    );

    // Animer l'item sélectionné au démarrage
    _iconControllers[0].forward();
    _pageTransitionController.value = 1.0; // Page visible immédiatement

    // Navbar visible immédiatement (pas d'animation d'apparition)
    _navBarController.value = 1.0;
  }

  @override
  void dispose() {
    for (var controller in _iconControllers) {
      controller.dispose();
    }
    _navBarController.dispose();
    _navBarPulseController.dispose();
    _flashController.dispose();
    _pageTransitionController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      // Haptic feedback
      HapticFeedback.lightImpact();

      // Reset l'animation de l'ancien item
      _iconControllers[_currentIndex].reverse();

      setState(() {
        _currentIndex = index;
      });

      // Lancer l'animation du nouvel item
      _iconControllers[index].forward();

      // Animer la navbar (pulse seulement)
      _navBarPulseController.forward().then((_) {
        _navBarPulseController.reverse();
      });

      // Flash unique - disparition instantanée à la fin
      if (_flashController.isAnimating) {
        _flashController.stop();
      }
      _flashController.reset();
      _flashController.forward().then((_) {
        _flashController.reset(); // Reset instantané au lieu de reverse
      });

      // iOS 26: Animation de transition de page
      final performanceService = GlassPerformanceService();
      if (performanceService.showTransitionAnimations) {
        _pageTransitionController.reset();
        _pageTransitionController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final performanceService = GlassPerformanceService();

    return Scaffold(
      extendBody: true,
      body: _buildPageContent(performanceService),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  /// Construit le contenu de la page avec animation iOS 26
  Widget _buildPageContent(GlassPerformanceService performanceService) {
    // Get only the current page (lazy loaded)
    final currentPage = _getPage(_currentIndex);

    if (!performanceService.showTransitionAnimations) {
      return KeyedSubtree(
        key: ValueKey(_currentIndex),
        child: currentPage,
      );
    }

    return AnimatedBuilder(
      animation: _pageTransitionController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pageScaleAnimation.value,
          child: Opacity(
            opacity: _pageFadeAnimation.value.clamp(0.0, 1.0),
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: currentPage,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return AnimatedBuilder(
      animation: _navBarAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * (1 - _navBarAnimation.value)),
          child: Opacity(
            opacity: _navBarAnimation.value.clamp(0.0, 1.0),
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_navBarPulseController, _flashController]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _navBarScaleAnimation.value,
                  child: Container(
                    margin:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                    height: 60,
                    child: Row(
                      children: [
                        // Navbar principale
                        Expanded(
                          child: GlassNavigationBar(
                            items: _navItems,
                            currentIndex: _currentIndex,
                            onItemSelected: _onItemTapped,
                            iconControllers: _iconControllers,
                            scaleAnimation: _navBarScaleAnimation,
                            flashAnimation: _flashAnimation,
                            isDark: isDark,
                            margin: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Bouton chatbot à droite
                        _buildChatbotButton(isDark),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatbotButton(bool isDark) {
    final isChatbotSelected = _currentIndex == 5; // Index 5 = Chatbot

    return GlassBubbleButtonStateful(
      icon: Icons.chat_bubble_rounded,
      onTap: () {
        // Utiliser _onItemTapped au lieu de Navigator.push
        _onItemTapped(5);
      },
      size: 54,
      showShimmer: isChatbotSelected, // Shimmer uniquement si sélectionné
      shimmerColor: AppColors.primary.withValues(alpha: 0.3),
      isDark: isDark,
      scaleAnimation: _navBarScaleAnimation,
      flashAnimation: _flashAnimation,
      tooltip: 'Chatbot',
      isSelected: isChatbotSelected, // Indiquer si sélectionné
    );
  }
}
