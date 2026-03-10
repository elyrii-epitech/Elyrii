import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';
import '../providers/journal_provider.dart';
import '../widgets/glass_journal_card.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/empty_journal_state.dart';
import '../widgets/journal_editor_sheet.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  JournalProvider get _provider => context.read<JournalProvider>();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _provider.loadEntries();
    }
  }

  void _showEditorSheet({JournalEntry? entry}) {
    HapticFeedback.lightImpact();
    showLiquidGlassSheet(
      context: context,
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      child: JournalEditorSheet(provider: _provider, entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
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
                        onCreateFirst: () => _showEditorSheet(),
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
            child: SafeArea(bottom: false, child: _buildAppBar(isDark)),
          ),
        ],
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
            onPressed: () => _showEditorSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalGrid(JournalProvider provider, bool isDark) {
    // Limit staggered animations to first 8 items for performance
    const int maxAnimatedItems = 8;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pageHorizontalPadding,
        80, // Padding top pour passer sous l'AppBar
        AppDimensions.pageHorizontalPadding,
        100, // Extra padding pour le bottom
      ),
      cacheExtent: 200, // Pre-render items for smoother scrolling
      itemCount: provider.entries.length,
      itemBuilder: (context, index) {
        final entry = provider.entries[index];
        final card = Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingLg),
          child: GlassJournalCard(
            entry: entry,
            isDark: isDark,
            onTap: () => _showEditorSheet(entry: entry),
          ),
        );

        // Only animate first 8 items to prevent jank
        if (index < maxAnimatedItems) {
          return card
              .animate()
              .fadeIn(
                duration: 350.ms,
                delay: (30 * index).ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.05,
                duration: 350.ms,
                delay: (30 * index).ms,
                curve: Curves.easeOutCubic,
              );
        }

        return card;
      },
    );
  }
}
