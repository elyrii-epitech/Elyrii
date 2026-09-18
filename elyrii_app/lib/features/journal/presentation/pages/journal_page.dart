import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
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
/// - Tirer-relâcher natif Cupertino ([CupertinoSliverRefreshControl]).
/// - Transitions douces avec [AnimatedSize] et fondu cubique ([_smoothFade]).
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: Consumer<JournalProvider>(
        builder: (context, provider, child) {
          final entries = provider.entries;
          final hasEntries = entries.isNotEmpty;

          return Stack(
            children: [
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 1. Tirer-relâcher natif Cupertino (remplace tout refresh Material)
                  CupertinoSliverRefreshControl(
                    onRefresh: () => provider.loadEntries(),
                  ),

                  // 2. En-tête spatial fluide (le titre défile avec le contenu)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppDimensions.pageHorizontalPadding,
                        topPadding + 14,
                        AppDimensions.pageHorizontalPadding,
                        4,
                      ),
                      child: _buildHeader(isDark),
                    ),
                  ),

              // 3. Contenu principal
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.pageHorizontalPadding,
                  12,
                  AppDimensions.pageHorizontalPadding,
                  MediaQuery.of(context).padding.bottom +
                      150, // Dégagement pour le dock flottant du shell
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A. Carte Héroïque du Refuge Intime
                      _buildJournalHeroCard(entries, isDark),
                      const SizedBox(height: 18),

                      // B. Bannière d'inspiration Coach IA
                      _buildInspirationBanner(isDark),
                      const SizedBox(height: 24),

                      // C. Liste des écrits ou État vide
                      AnimatedSize(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: [...previousChildren, ?currentChild],
                            );
                          },
                          transitionBuilder: _smoothFade,
                          child: hasEntries
                              ? _buildEntriesList(entries, isDark)
                              : _buildEmptyState(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
              ),

              // Boutons d'actions épinglés au scroll (tri et ajout de note restent fixes)
              Positioned(
                top: topPadding + 14,
                right: AppDimensions.pageHorizontalPadding,
                child: _buildPinnedActions(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Boutons d'actions épinglés au scroll en verre liquide (flèche de tri et +).
  Widget _buildPinnedActions(JournalProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton de tri (récent / ancien)
        LiquidGlassIconButton(
          icon: provider.sortNewest
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
          onPressed: () {
            ElyriiHaptics.selection();
            provider.toggleSort();
          },
        ),
        const SizedBox(width: 8),

        // Bouton nouvelle note
        LiquidGlassIconButton(
          icon: Icons.add_rounded,
          onPressed: () => _showEditorSheet(),
        ),
      ],
    );
  }

  /// En-tête spatial sans vide noir : le titre glisse sous les boutons épinglés.
  Widget _buildHeader(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne titre & sur-titre
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MES PENSÉES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Journal',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.1,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pose tes pensées, sans filtre.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        // Espace réservé pour ne pas chevaucher les boutons épinglés au scroll
        const SizedBox(width: 96 + 12),
      ],
    );
  }

  /// Carte Héroïque de l'espace d'expression intime.
  Widget _buildJournalHeroCard(List<JournalEntry> entries, bool isDark) {
    final count = entries.length;
    final latestMood = count > 0 ? _formatMoodEmoji(entries.first.mood) : '🌱';

    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Refuge de l\'esprit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Privé & Sûr',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tes pensées sont un sanctuaire d\'apaisement.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Bento statistiques douces
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count ${count > 1 ? "réflexions" : "réflexion"}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              'Déposées',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(latestMood, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              count > 0 ? 'Dernier écho' : 'Prendre racine',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              count > 0 ? 'Ton humeur' : 'Commence ici',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.20),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inspiration guidée du moment',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '« Qu\'est-ce qui occupe mes pensées en ce moment ? »',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

  /// Vue de la liste des entrées de journal.
  Widget _buildEntriesList(List<JournalEntry> entries, bool isDark) {
    return Column(
      key: const ValueKey('journal_entries_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Mes réflexions (${entries.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassJournalCard(
              entry: entry,
              isDark: isDark,
              onTap: () => _showEditorSheet(entry: entry),
            ),
          );
        }),
      ],
    );
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

  Widget _smoothFade(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
      child: child,
    );
  }
}
