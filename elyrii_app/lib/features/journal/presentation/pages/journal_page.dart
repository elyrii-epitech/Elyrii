import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../providers/journal_provider.dart';
import '../widgets/glass_journal_card.dart';
import '../widgets/empty_journal_state.dart';
import '../widgets/journal_editor_sheet.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

/// Page principale du Journal intime suivant la philosophie Apple HIG.
/// Utilise un grand titre rétractable iOS (`SliverAppBar.large`), des actions
/// de navigation épurées et une grille aérée sans aucun Stack bricolé.
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _provider.loadEntries();
        }
      });
    }
  }

  void _showEditorSheet({JournalEntry? entry, String? initialPrompt}) {
    ElyriiHaptics.light();
    showLiquidGlassSheet(
      context: context,
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      child: JournalEditorSheet(
        provider: _provider,
        entry: entry,
        initialPrompt: initialPrompt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: Consumer<JournalProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              // Contenu principal défilant sous les boutons flottants
              CustomScrollView(
                scrollCacheExtent: const ScrollCacheExtent.pixels(200),
                slivers: [
                  // Dégagement pour passer sous les boutons flottants décrochés
                  const SliverToBoxAdapter(child: SizedBox(height: 72)),

                  // Grand titre « Journal » qui respire sans bandeau sombre
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pageHorizontalPadding,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Journal',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Contenu : état vide ou liste des cartes de notes
                  if (provider.entries.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: EmptyJournalState(
                        onCreateFirst: () => _showEditorSheet(),
                        onPromptSelected: (prompt) =>
                            _showEditorSheet(initialPrompt: prompt.title),
                        isDark: isDark,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.pageHorizontalPadding,
                        0,
                        AppDimensions.pageHorizontalPadding,
                        140, // Dégagement pour le dock flottant
                      ),
                      sliver: SliverList.builder(
                        itemCount: provider.entries.length,
                        itemBuilder: (context, index) {
                          const int maxAnimatedItems = 8;
                          final entry = provider.entries[index];
                          final card = Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimensions.spacingLg,
                            ),
                            child: GlassJournalCard(
                              entry: entry,
                              isDark: isDark,
                              onTap: () => _showEditorSheet(entry: entry),
                            ),
                          );

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
                      ),
                    ),
                ],
              ),

              // Boutons flottants décrochés en verre liquide : aucun bandeau noir
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pageHorizontalPadding,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        LiquidGlassIconButton(
                          icon: provider.sortNewest
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          onPressed: () {
                            ElyriiHaptics.selection();
                            provider.toggleSort();
                          },
                        ),
                        const Spacer(),
                        LiquidGlassIconButton(
                          icon: Icons.add_rounded,
                          onPressed: () => _showEditorSheet(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
