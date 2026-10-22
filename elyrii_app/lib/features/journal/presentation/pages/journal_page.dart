import 'package:flutter/material.dart';

import '../../../../core/widgets/elyrii_page_header.dart';

import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../providers/journal_provider.dart';
import '../widgets/empty_journal_state.dart';
import '../widgets/glass_journal_card.dart';
import '../widgets/journal_editor_sheet.dart';

/// Page principale du Journal intime suivant la philosophie Apple HIG.
///
/// Refonte Apple HIG & Liquid Glass (Septembre 2026) :
/// - Suppression des boutons isolés flottant maladroitement au-dessus de la vue.
/// - En-tête spatial fluide avec micro-sur-titre « MES PENSÉES », grand titre
///   « Journal » et boutons d'action intégrés en verre liquide.
/// - Carte Héroïque « Espace de Réflexion » avec bento de statistiques douces
///   (nombre d'écrits, dernière humeur).
/// - Passerelle d'inspiration avec le Coach IA pour stimuler l'écriture bienveillante.
/// - Tirer-relâcher natif Cupertino via [ElyriiPageFrame.onRefresh].
/// - Cartes construites à la demande par un [SliverList].
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
          final entries = provider.entries;

          return ElyriiPageFrame.tab(
            title: 'Journal',
            onRefresh: () => provider.loadEntries(),
            actions: [
              LiquidGlassIconButton(
                tooltip: 'Changer l’ordre des notes',
                icon: provider.sortNewest
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                onPressed: () {
                  ElyriiHaptics.selection();
                  provider.toggleSort();
                },
              ),
              LiquidGlassIconButton(
                tooltip: 'Écrire une note',
                icon: Icons.add_rounded,
                onPressed: () => _showEditorSheet(),
              ),
            ],
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              ..._buildContentSlivers(entries, isDark),
              if (provider.hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacing20),
                    child: LiquidGlassButton(
                      label: 'Charger les notes suivantes',
                      isLoading: provider.loadingMore,
                      onPressed: provider.loadingMore
                          ? null
                          : provider.loadMore,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Carte Héroïque de l'espace d'expression intime.
  Widget _buildJournalHeroCard(List<JournalEntry> entries, bool isDark) {
    final count = entries.length;
    final latestMood = count > 0 ? _formatMoodEmoji(entries.first.mood) : '🌱';

    return LiquidGlassCard(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cercle décoratif en halo doux
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.25),
                      AppColors.secondary.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppDimensions.spacing8,
                      runSpacing: AppDimensions.spacing8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Refuge de l\'esprit',
                          style: AppTextStyles.titleMedium(
                            color: context.textPrimary,
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing8,
                            vertical: AppDimensions.spacing2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radius8,
                            ),
                          ),
                          child: Text(
                            'Privé & Sûr',
                            style: AppTextStyles.badge(
                              color: AppColors.readableAccent(
                                AppColors.primary,
                                isDark:
                                    Theme.of(context).brightness ==
                                    Brightness.dark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacing2),
                    Text(
                      'Tes pensées sont un sanctuaire d\'apaisement.',
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Bento statistiques douces
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing12,
                    vertical: AppDimensions.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(AppDimensions.radius12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.primary,
                        size: AppDimensions.iconSm,
                      ),
                      const SizedBox(width: AppDimensions.spacing8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count ${count > 1 ? "réflexions" : "réflexion"}',
                              style: AppTextStyles.titleSmall(
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              'Déposées',
                              style: AppTextStyles.bodySmall(
                                color: context.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing12,
                    vertical: AppDimensions.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(AppDimensions.radius12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: AppDimensions.iconSm,
                        height: AppDimensions.iconSm,
                        child: Center(
                          child: Semantics(
                            label: count > 0
                                ? 'Dernière humeur : ${entries.first.mood ?? 'non renseignée'}'
                                : null,
                            excludeSemantics: true,
                            child: Text(
                              latestMood,
                              style: AppTextStyles.titleMedium(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacing8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              count > 0 ? 'Dernier écho' : 'Prendre racine',
                              style: AppTextStyles.titleSmall(
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              count > 0 ? 'Ton humeur' : 'Commence ici',
                              style: AppTextStyles.bodySmall(
                                color: context.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bannière d'inspiration pour stimuler l'écriture libre ou guidée.
  Widget _buildInspirationBanner(bool isDark) {
    return GestureDetector(
      onTap: () {
        ElyriiHaptics.light();
        _showEditorSheet(
          initialPrompt: 'Qu\'est-ce qui occupe mes pensées en ce moment ?',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing16,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radius16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.20),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inspiration guidée du moment',
                    style: AppTextStyles.titleSmall(color: context.textPrimary),
                  ),
                  const SizedBox(height: AppDimensions.spacing2),
                  Text(
                    '« Qu\'est-ce qui occupe mes pensées en ce moment ? »',
                    style: AppTextStyles.labelSmall(
                      color: context.textSecondary,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  /// Build journal cards only when they enter the viewport.
  List<Widget> _buildContentSlivers(List<JournalEntry> entries, bool isDark) {
    const horizontal = AppDimensions.pageHorizontalPadding;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          horizontal,
          AppDimensions.spacing12,
          horizontal,
          AppDimensions.spacing24,
        ),
        sliver: SliverToBoxAdapter(
          child: Column(
            children: [
              _buildJournalHeroCard(entries, isDark),
              const SizedBox(height: AppDimensions.spacing16),
              _buildInspirationBanner(isDark),
            ],
          ),
        ),
      ),
      if (entries.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverToBoxAdapter(child: _buildEmptyState(isDark)),
        )
      else ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            horizontal + AppDimensions.spacing4,
            0,
            horizontal,
            AppDimensions.spacing8,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Mes réflexions (${entries.length})',
              style: AppTextStyles.overline(color: context.textSecondary),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverList.builder(
            key: const ValueKey('journal_entries_list'),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                key: ValueKey(entry.id),
                padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
                child: GlassJournalCard(
                  entry: entry,
                  isDark: isDark,
                  onTap: () => _showEditorSheet(entry: entry),
                ),
              );
            },
          ),
        ),
      ],
    ];
  }

  /// Vue de l'état vide bienveillant quand aucune note n'est encore écrite.
  Widget _buildEmptyState(bool isDark) {
    return KeyedSubtree(
      key: const ValueKey('journal_empty_state'),
      child: EmptyJournalState(
        onCreateFirst: () => _showEditorSheet(),
        onPromptSelected: (prompt) =>
            _showEditorSheet(initialPrompt: prompt.title),
        isDark: isDark,
      ),
    );
  }

  String _formatMoodEmoji(String? mood) {
    if (mood == null) return '🌱';
    switch (mood.toLowerCase()) {
      case 'happy':
      case 'joyeux':
        return '☀️';
      case 'calm':
      case 'paisible':
        return '🌸';
      case 'sad':
      case 'triste':
        return '🌧️';
      case 'anxious':
      case 'anxieux':
        return '⚡';
      default:
        return '🌱';
    }
  }
}
