import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/journal_provider.dart';
import '../widgets/glass_journal_card.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/empty_journal_state.dart';
import 'journal_editor_page.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late JournalProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = JournalProvider();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _navigateToEditor({JournalEntry? entry}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => JournalEditorPage(
          provider: _provider,
          entry: entry,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.easeInOutCubic;

          var fadeTween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          var scaleTween = Tween(begin: 0.95, end: 1.0).chain(
            CurveTween(curve: curve),
          );

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: ScaleTransition(
              scale: animation.drive(scaleTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF171719) : const Color(0xFFE8E8EB),
        body: Stack(
          children: [
            // Contenu principal (liste des notes)
            Column(
              children: [
                Expanded(
                  child: Consumer<JournalProvider>(
                    builder: (context, provider, child) {
                      if (provider.entries.isEmpty) {
                        return EmptyJournalState(
                          onCreateFirst: () => _navigateToEditor(),
                          isDark: isDark,
                        );
                      }

                      return _buildJournalGrid(provider, isDark);
                    },
                  ),
                ),
              ],
            ),
            // AppBar flottant au-dessus avec SafeArea
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _buildAppBar(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pageHorizontalPadding),
      child: Row(
        children: [
          // Bouton tri
          Consumer<JournalProvider>(
            builder: (context, provider, child) {
              return GlassIconButton(
                isDark: isDark,
                icon: provider.sortNewest
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                onPressed: provider.toggleSort,
              );
            },
          ),
          const Spacer(),
          // Bouton ajouter
          GlassIconButton(
            isDark: isDark,
            icon: Icons.add_rounded,
            onPressed: () => _navigateToEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalGrid(JournalProvider provider, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pageHorizontalPadding,
        80, // Padding top pour passer sous l'AppBar
        AppDimensions.pageHorizontalPadding,
        100, // Extra padding pour le bottom
      ),
      itemCount: provider.entries.length,
      itemBuilder: (context, index) {
        final entry = provider.entries[index];
        return Padding(
          padding: const EdgeInsets.only(
            bottom: AppDimensions.spacingLg,
          ),
          child: GlassJournalCard(
            entry: entry,
            isDark: isDark,
            onTap: () => _navigateToEditor(entry: entry),
          ).animate().fadeIn(
            duration: 350.ms,
            delay: (30 * index).ms,
            curve: Curves.easeOutCubic,
          ).slideY(
            begin: 0.05,
            duration: 350.ms,
            delay: (30 * index).ms,
            curve: Curves.easeOutCubic,
          ),
        );
      },
    );
  }
}

