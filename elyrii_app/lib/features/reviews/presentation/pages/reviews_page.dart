import '../widgets/review_content.dart';

import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';

import '../../../../core/widgets/elyrii_page_header.dart';

import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
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

          return ElyriiPageFrame.detail(
            title: 'Bilan',
            leading: ElyriiBackButton(
              onPressed: () => Navigator.maybePop(context),
            ),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _reload),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.pageHorizontalPadding,
                  AppDimensions.spacing4,
                  AppDimensions.pageHorizontalPadding,
                  0,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _RangeSelector(
                      selectedRange: _selectedRange,
                      onSelected: _selectRange,
                    ),
                    const SizedBox(height: AppDimensions.spacing20),
                    if (isWaiting)
                      ReviewSkeleton(isDark: isDark)
                    else if (snapshot.hasError)
                      LiquidGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacing16,
                          ),
                          child: Text(
                            'Impossible de charger le bilan pour le moment.',
                            style: AppTextStyles.bodyMedium(
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      )
                    else if (data != null) ...[
                      ReviewOverviewGrid(stats: data),
                      const SizedBox(height: AppDimensions.spacing20),
                      const ReviewSectionHeader(
                        title: 'Tendance de l’humeur',
                        subtitle: 'Nombre de prises d’humeur par jour',
                      ),
                      ReviewTrendChart(stats: data, isDark: isDark),
                      const SizedBox(height: AppDimensions.spacing20),
                      const ReviewSectionHeader(
                        title: 'Répartition',
                        subtitle: 'Ce qui ressort le plus sur la période',
                      ),
                      ReviewMoodDistributionList(stats: data, isDark: isDark),
                      const SizedBox(height: AppDimensions.spacing20),
                      const ReviewSectionHeader(
                        title: 'Activité',
                        subtitle:
                            'Journal et humeur sur la même ligne du temps',
                      ),
                      ReviewActivityTimeline(stats: data),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sélecteur de période façon iOS : segmented control coulissant natif.
class _RangeSelector extends StatelessWidget {
  static const Map<String, String> _labels = {
    '7d': '7 jours',
    '30d': '30 jours',
    '90d': '90 jours',
  };

  final String selectedRange;
  final ValueChanged<String> onSelected;

  const _RangeSelector({required this.selectedRange, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSegmentedControl<String>(
      segments: _labels,
      selectedValue: selectedRange,
      onValueChanged: onSelected,
    );
  }
}

/// Squelette de chargement façon iOS : blocs de surface qui respirent doucement,
/// en remplacement du spinner circulaire Material.
