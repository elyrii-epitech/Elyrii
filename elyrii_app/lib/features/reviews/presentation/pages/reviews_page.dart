import '../widgets/review_content.dart';

import 'package:flutter/cupertino.dart'
    show CupertinoSlidingSegmentedControl, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';

import '../../../../core/widgets/elyrii_page_header.dart';

import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../dashboard/data/models/dashboard_models.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';

/// Page d'analyse et de bilan émotionnel (extraite du Dashboard pour modularité).
class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key, this.repository});
  final DashboardRepository? repository;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  static const List<String> _ranges = ['7d', '30d', '90d'];

  late String _selectedRange;
  late Future<DashboardStats> _future;

  @override
  void initState() {
    super.initState();
    _selectedRange = _ranges[1];
    _future = _loadStats();
  }

  Future<DashboardStats> _loadStats() {
    final repository =
        widget.repository ??
        DashboardRepository(client: context.read<ApiClient>());
    return repository.getStats(range: _selectedRange);
  }

  /// Recharge les statistiques ; le Future retourné pilote le refresh control
  /// iOS (la molette se referme une fois les données arrivées).
  Future<void> _reload() async {
    try {
      final future = _loadStats();
      setState(() => _future = future);
      await future;
    } catch (_) {
      // L'état d'erreur est déjà restitué par le FutureBuilder sous forme de
      // bannière inline ; on évite juste une exception non gérée côté refresh.
    }
  }

  void _selectRange(String range) {
    if (_selectedRange == range) return;
    ElyriiHaptics.selection();
    setState(() {
      _selectedRange = range;
      _future = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: FutureBuilder<DashboardStats>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          // Squelette seulement au premier chargement : pendant un
          // pull-to-refresh, les anciennes données restent affichées.
          final isWaiting =
              snapshot.connectionState == ConnectionState.waiting &&
              data == null;

          return ElyriiPageFrame(
            header: ElyriiPageHeader(
              title: 'Bilan',
              subtitle: 'Ta semaine, en un coup d’œil.',
              leading: ElyriiBackButton(
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Dégagement de l'en-tête épinglé (flèche + titre + sous-titre).
                CupertinoSliverRefreshControl(onRefresh: _reload),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _RangeSelector(
                        isDark: isDark,
                        selectedRange: _selectedRange,
                        onSelected: _selectRange,
                      ),
                      const SizedBox(height: 20),
                      if (isWaiting)
                        ReviewSkeleton(isDark: isDark)
                      else if (snapshot.hasError)
                        LiquidGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Impossible de charger le bilan pour le moment.',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        )
                      else if (data != null) ...[
                        ReviewOverviewGrid(stats: data, isDark: isDark),
                        const SizedBox(height: 20),
                        ReviewSectionHeader(
                          title: 'Tendance de l’humeur',
                          subtitle: 'Nombre de prises d’humeur par jour',
                          isDark: isDark,
                        ),
                        ReviewTrendChart(stats: data, isDark: isDark),
                        const SizedBox(height: 20),
                        ReviewSectionHeader(
                          title: 'Répartition',
                          subtitle: 'Ce qui ressort le plus sur la période',
                          isDark: isDark,
                        ),
                        ReviewMoodDistributionList(stats: data, isDark: isDark),
                        const SizedBox(height: 20),
                        ReviewSectionHeader(
                          title: 'Activité',
                          subtitle:
                              'Journal et humeur sur la même ligne du temps',
                          isDark: isDark,
                        ),
                        ReviewActivityTimeline(stats: data, isDark: isDark),
                        const SizedBox(height: 140),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// En-tête épinglé : retour glass, titre et sous-titre centrés sur la
  /// flèche — ne suivent pas le scroll.
}

/// Sélecteur de période façon iOS : segmented control coulissant natif.
class _RangeSelector extends StatelessWidget {
  static const Map<String, String> _labels = {
    '7d': '7j',
    '30d': '30j',
    '90d': '90j',
  };

  final bool isDark;
  final String selectedRange;
  final ValueChanged<String> onSelected;

  const _RangeSelector({
    required this.isDark,
    required this.selectedRange,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: selectedRange,
        onValueChanged: (val) {
          if (val != null) onSelected(val);
        },
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        thumbColor: isDark ? AppColors.cardDark : Colors.white,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        children: {
          for (final entry in _labels.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selectedRange == entry.key
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: selectedRange == entry.key
                      ? (isDark ? AppColors.primaryDark : AppColors.primary)
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                ),
              ),
            ),
        },
      ),
    );
  }
}

/// Squelette de chargement façon iOS : blocs de surface qui respirent doucement,
/// en remplacement du spinner circulaire Material.
