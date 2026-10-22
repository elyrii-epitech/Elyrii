import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../dashboard/data/models/dashboard_models.dart';

class ReviewSkeleton extends StatefulWidget {
  final bool isDark;

  const ReviewSkeleton({super.key, required this.isDark});

  @override
  State<ReviewSkeleton> createState() => _ReviewSkeletonState();
}

class _ReviewSkeletonState extends State<ReviewSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = 1;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
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
        borderRadius: BorderRadius.circular(AppDimensions.radius20),
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
              final tileWidth =
                  (constraints.maxWidth - AppDimensions.spacing12) / 2;
              return Wrap(
                spacing: AppDimensions.spacing12,
                runSpacing: AppDimensions.spacing12,
                children: [
                  for (var i = 0; i < 4; i++)
                    SizedBox(width: tileWidth, child: block(height: 134)),
                ],
              );
            },
          ),
          const SizedBox(height: AppDimensions.spacing20),
          // Graphique de tendance
          block(height: 212),
          const SizedBox(height: AppDimensions.spacing20),
          // Répartition des humeurs
          block(height: 150),
        ],
      ),
    );
  }
}

class ReviewOverviewGrid extends StatelessWidget {
  final DashboardStats stats;

  const ReviewOverviewGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - AppDimensions.spacing12) / 2;

        return Wrap(
          spacing: AppDimensions.spacing12,
          runSpacing: AppDimensions.spacing12,
          children: [
            _SummaryTile(
              width: tileWidth,
              icon: Icons.local_fire_department_rounded,
              label: 'Série',
              value: '${stats.streak}',
              color: AppColors.secondary,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.mood_rounded,
              label: 'Humeurs',
              value: '${stats.moodLogsCount}',
              color: AppColors.primary,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.edit_note_rounded,
              label: 'Journal',
              value: '${stats.journalEntriesCount}',
              color: AppColors.accent,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.stars_rounded,
              label: 'Points',
              value: '${stats.totalPoints}',
              color: AppColors.success,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.flag_rounded,
              label: 'Défis',
              value:
                  '${stats.completedChallengesCount}/${stats.activeChallengesCount + stats.completedChallengesCount}',
              color: AppColors.warning,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.self_improvement_rounded,
              label: 'Méditation',
              value: '${stats.meditationSessionsCount}',
              color: AppColors.info,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.trending_up_rounded,
              label: 'Taux',
              value: '${(stats.completionRate * 100).round()}%',
              color: AppColors.successDark,
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

  const _SummaryTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimensions.radius8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Text(
              value,
              style: AppTextStyles.headlineSmall(color: context.textPrimary),
            ),
            const SizedBox(height: AppDimensions.spacing2),
            Text(
              label,
              style: AppTextStyles.bodySmall(color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const ReviewSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.spacing4,
        bottom: AppDimensions.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.overline(color: context.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacing2),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall(color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}

class ReviewTrendChart extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const ReviewTrendChart({
    super.key,
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final points = stats.moodTrend7Days;
    if (points.isEmpty) {
      return LiquidGlassCard(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Text(
          'Aucune humeur enregistrée sur cette période.',
          style: AppTextStyles.bodyMedium(color: context.textSecondary),
        ),
      );
    }

    final maxCount = points
        .map((point) => point.count)
        .fold<int>(0, (max, value) => value > max ? value : max)
        .clamp(1, 9999)
        .toDouble();
    final chart = LiquidGlassCard(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: SizedBox(
        height: 140 + MediaQuery.textScalerOf(context).scale(14) * 4,
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
                width: 44 * (MediaQuery.textScalerOf(context).scale(11) / 11),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${point.count}',
                      style: AppTextStyles.labelMedium(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing8),
                    Container(
                      height: 108,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        width: 16,
                        height: barHeight.clamp(6, 104).toDouble(),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radius8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing8),
                    Text(
                      parsedDate != null
                          ? _shortDateLabel(parsedDate)
                          : point.day,
                      style: AppTextStyles.labelSmall(
                        color: context.textTertiary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: chart),
        ExpansionTile(
          title: const Text('Données du graphique des humeurs'),
          children: [
            for (final point in points)
              ListTile(
                title: Text(
                  '${point.day} : ${point.count} humeur${point.count == 1 ? '' : 's'} enregistrée${point.count == 1 ? '' : 's'}',
                ),
              ),
          ],
        ),
      ],
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

class ReviewMoodDistributionList extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const ReviewMoodDistributionList({
    super.key,
    required this.stats,
    required this.isDark,
  });

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
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Text(
          'Aucune répartition disponible.',
          style: AppTextStyles.bodyMedium(color: context.textSecondary),
        ),
      );
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.count);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        children: items.map((item) {
          final percentage = total == 0 ? 0.0 : item.count / total;
          return Semantics(
            container: true,
            label:
                '${_moodLabel(item.moodType)} : ${item.count} humeurs, ${(percentage * 100).round()} pour cent',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
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
                  const SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _moodLabel(item.moodType),
                          style: AppTextStyles.labelMedium(
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        // Barre de progression déterminée : simple bloc coloré,
                        // sans LinearProgressIndicator Material.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusPill,
                          ),
                          child: Container(
                            height: 8,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentage
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                              child: Container(
                                color: _moodColor(item.moodType),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Text(
                    '${item.count}',
                    style: AppTextStyles.titleSmall(color: context.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ReviewActivityTimeline extends StatelessWidget {
  final DashboardStats stats;

  const ReviewActivityTimeline({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final points = stats.activityTimeline;
    if (points.isEmpty) {
      return LiquidGlassCard(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Text(
          'Aucune activité à afficher sur cette période.',
          style: AppTextStyles.bodyMedium(color: context.textSecondary),
        ),
      );
    }

    return LiquidGlassCard(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        children: points.map((point) {
          final parsedDate = DateTime.tryParse(point.day);
          final total = point.moodLogs + point.journalEntries;
          return Semantics(
            container: true,
            label:
                '${point.day} : ${point.moodLogs} humeurs et ${point.journalEntries} notes, total $total',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacing16),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      parsedDate != null
                          ? _shortDateLabel(parsedDate)
                          : point.day,
                      style: AppTextStyles.labelMedium(
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Humeurs ${point.moodLogs}  Journal ${point.journalEntries}  Total $total',
                          style: AppTextStyles.bodySmall(
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
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
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusPill,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacing8),
                            Expanded(
                              flex: point.journalEntries == 0
                                  ? 1
                                  : point.journalEntries,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.75,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusPill,
                                  ),
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
            ),
          );
        }).toList(),
      ),
    );
  }
}
