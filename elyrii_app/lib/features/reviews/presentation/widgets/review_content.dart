import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
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

class ReviewOverviewGrid extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const ReviewOverviewGrid({
    super.key,
    required this.stats,
    required this.isDark,
  });

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
              label: 'Série',
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

class ReviewSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const ReviewSectionHeader({
    super.key,
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

class ReviewActivityTimeline extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const ReviewActivityTimeline({
    super.key,
    required this.stats,
    required this.isDark,
  });

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
