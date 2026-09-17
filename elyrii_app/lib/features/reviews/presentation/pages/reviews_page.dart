import 'package:flutter/cupertino.dart'
    show CupertinoSlidingSegmentedControl, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../dashboard/data/models/dashboard_models.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';

/// Page d'analyse et de bilan émotionnel (extraite du Dashboard pour modularité).
class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

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
    final client = context.read<ApiClient>();
    final repository = DashboardRepository(client: client);
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
    final topPadding = MediaQuery.of(context).padding.top;

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

          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Dégagement de l'en-tête épinglé (flèche + titre + sous-titre).
                  SliverToBoxAdapter(child: SizedBox(height: topPadding + 72)),
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
                          _ReviewsSkeleton(isDark: isDark)
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
                          _OverviewGrid(stats: data, isDark: isDark),
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'Tendance de l’humeur',
                            subtitle: 'Nombre de prises d’humeur par jour',
                            isDark: isDark,
                          ),
                          _TrendChart(stats: data, isDark: isDark),
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'Répartition',
                            subtitle: 'Ce qui ressort le plus sur la période',
                            isDark: isDark,
                          ),
                          _MoodDistributionList(stats: data, isDark: isDark),
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'Activité',
                            subtitle:
                                'Journal et humeur sur la même ligne du temps',
                            isDark: isDark,
                          ),
                          _ActivityTimeline(stats: data, isDark: isDark),
                          const SizedBox(height: 140),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
              // En-tête épinglé sur fond opaque : ne suit pas le scroll,
              // le contenu disparaît derrière.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: isDark
                      ? AppColors.scaffoldDark
                      : AppColors.scaffoldLight,
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.pageHorizontalPadding,
                    topPadding + 4,
                    AppDimensions.pageHorizontalPadding,
                    8,
                  ),
                  child: _buildHeader(context, isDark),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// En-tête épinglé : retour glass, titre et sous-titre centrés sur la
  /// flèche — ne suivent pas le scroll.
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        ElyriiBackButton(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
          onPressed: () {
            ElyriiHaptics.light();
            Navigator.maybePop(context);
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Text(
                'Bilan',
                textAlign: TextAlign.center,
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
              const SizedBox(height: 2),
              Text(
                'Ta semaine, en un coup d’œil.',
                textAlign: TextAlign.center,
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
        // Contrepoids de la flèche : le texte reste centré à l’écran.
        const SizedBox(width: 44),
      ],
    );
  }
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
class _ReviewsSkeleton extends StatefulWidget {
  final bool isDark;

  const _ReviewsSkeleton({required this.isDark});

  @override
  State<_ReviewsSkeleton> createState() => _ReviewsSkeletonState();
}

class _ReviewsSkeletonState extends State<_ReviewsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final blockColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    Widget block({double? width, required double height}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: blockColor,
        borderRadius: BorderRadius.circular(20),
      ),
    );

    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.4,
        end: 1,
      ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tuiles de synthèse (2 colonnes)
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < 4; i++)
                    SizedBox(width: tileWidth, child: block(height: 134)),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Graphique de tendance
          block(height: 212),
          const SizedBox(height: 20),
          // Répartition des humeurs
          block(height: 150),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const _OverviewGrid({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryTile(
              width: tileWidth,
              icon: Icons.local_fire_department_rounded,
              label: 'Streak',
              value: '${stats.streak}',
              color: AppColors.secondary,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.mood_rounded,
              label: 'Humeurs',
              value: '${stats.moodLogsCount}',
              color: AppColors.primary,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.edit_note_rounded,
              label: 'Journal',
              value: '${stats.journalEntriesCount}',
              color: AppColors.accent,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.stars_rounded,
              label: 'Points',
              value: '${stats.totalPoints}',
              color: AppColors.success,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.flag_rounded,
              label: 'Défis',
              value:
                  '${stats.completedChallengesCount}/${stats.activeChallengesCount + stats.completedChallengesCount}',
              color: AppColors.warning,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.self_improvement_rounded,
              label: 'Méditation',
              value: '${stats.meditationSessionsCount}',
              color: AppColors.info,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.trending_up_rounded,
              label: 'Taux',
              value: '${(stats.completionRate * 100).round()}%',
              color: AppColors.successDark,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const _TrendChart({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final points = stats.moodTrend7Days;
    if (points.isEmpty) {
      return LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Aucune humeur enregistrée sur cette période.',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    final maxCount = points
        .map((point) => point.count)
        .fold<int>(0, (max, value) => value > max ? value : max)
        .clamp(1, 9999)
        .toDouble();
    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 180,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              final parsedDate = DateTime.tryParse(point.day);
              final barHeight = 104.0 * (point.count / maxCount);
              final accent = point.count > 0
                  ? AppColors.primary.withValues(alpha: 0.85)
                  : (isDark ? Colors.white24 : Colors.black12);

              return SizedBox(
                width: 44,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${point.count}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 108,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 16,
                        height: barHeight.clamp(6, 104).toDouble(),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      parsedDate != null
                          ? _shortDateLabel(parsedDate)
                          : point.day,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

String _shortDateLabel(DateTime date) {
  const months = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Août',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

class _MoodDistributionList extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const _MoodDistributionList({required this.stats, required this.isDark});

  Color _moodColor(String moodType) {
    switch (moodType) {
      case 'verySad':
        return const Color(0xFF7BA3C7);
      case 'sad':
        return const Color(0xFF93B8DA);
      case 'neutral':
        return const Color(0xFFA39C96);
      case 'happy':
        return const Color(0xFFA8D5BA);
      case 'veryHappy':
        return const Color(0xFF7BC393);
      default:
        return AppColors.primary;
    }
  }

  String _moodLabel(String moodType) {
    switch (moodType) {
      case 'verySad':
        return 'Très triste';
      case 'sad':
        return 'Triste';
      case 'neutral':
        return 'Neutre';
      case 'happy':
        return 'Content';
      case 'veryHappy':
        return 'Très content';
      default:
        return 'Inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = stats.moodDistribution;
    if (items.isEmpty) {
      return LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Aucune répartition disponible.',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.count);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: items.map((item) {
          final percentage = total == 0 ? 0.0 : item.count / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _moodColor(item.moodType),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _moodLabel(item.moodType),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Barre de progression déterminée : simple bloc coloré,
                      // sans LinearProgressIndicator Material.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 8,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percentage.clamp(0.0, 1.0).toDouble(),
                            child: Container(color: _moodColor(item.moodType)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const _ActivityTimeline({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final points = stats.activityTimeline;
    if (points.isEmpty) {
      return LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Aucune activité à afficher sur cette période.',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: points.map((point) {
          final parsedDate = DateTime.tryParse(point.day);
          final total = point.moodLogs + point.journalEntries;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    parsedDate != null
                        ? _shortDateLabel(parsedDate)
                        : point.day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Humeurs ${point.moodLogs}  Journal ${point.journalEntries}  Total $total',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            flex: point.moodLogs == 0 ? 1 : point.moodLogs,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.75,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: point.journalEntries == 0
                                ? 1
                                : point.journalEntries,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
