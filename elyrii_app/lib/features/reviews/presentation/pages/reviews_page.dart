import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/pushed_page.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../dashboard/data/models/dashboard_models.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../../dashboard/domain/accueil_content.dart';
import '../../../dashboard/domain/civil_day.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../../../meditation/data/models/meditation_session_model.dart';
import '../../../meditation/data/repositories/meditation_repository.dart';
import '../../../profile_setup/presentation/widgets/profile_controls.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/review_period.dart';

typedef _ReviewData = ({
  DashboardStats stats,
  List<MeditationSessionModel> sessions,
});

class ReviewsPage extends StatefulWidget {
  final DashboardRepository? repository;
  final MeditationRepository? meditationRepository;
  final DateTime Function()? now;
  const ReviewsPage({
    super.key,
    this.repository,
    this.meditationRepository,
    this.now,
  });
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  ReviewPeriod _period = ReviewPeriod.week;
  late Future<_ReviewData> _future;
  late ReviewWindow _window;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final today = CivilDay.fromLocal(widget.now?.call() ?? DateTime.now());
    _window = ReviewWindow(
      period: _period,
      today: today,
      createdAt: context.read<UserProvider?>()?.profile?.createdAt,
    );
    final repository =
        widget.repository ??
        DashboardRepository(client: context.read<ApiClient>());
    final client = context.read<ApiClient?>();
    final meditation =
        widget.meditationRepository ??
        (client == null ? null : MeditationRepository(client: client));
    final stats = repository.getStats(range: _window.range);
    final sessions =
        meditation?.getSessions(limit: 100) ??
        Future.value(<MeditationSessionModel>[]);
    _future = () async {
      final values = await Future.wait<Object>([stats, sessions]);
      return (
        stats: values[0] as DashboardStats,
        sessions: values[1] as List<MeditationSessionModel>,
      );
    }();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activities =
        context.watch<AccueilActivities?>()?.snapshot ??
        AccueilActivitySnapshot();
    return PushedPage(
      title: 'Mon bilan',
      children: [
        ProfileSegments<ReviewPeriod>(
          options: const {
            ReviewPeriod.week: 'Semaine',
            ReviewPeriod.month: 'Mois',
            ReviewPeriod.quarter: 'Trimestre',
          },
          selected: _period,
          onChanged: (period) {
            if (period != _period) {
              setState(() {
                _period = period;
                _load();
              });
            }
          },
        ),
        const SizedBox(height: AppDimensions.spacing12),
        Text(
          _periodLabel(),
          style: AppTextStyles.bodySmall(color: context.textSecondary),
        ),
        const SizedBox(height: AppDimensions.spacing24),
        FutureBuilder<_ReviewData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError) {
              return ProfileCard(
                child: Column(
                  children: [
                    Text(
                      'Impossible de charger le bilan pour le moment.',
                      style: AppTextStyles.bodyMedium(
                        color: context.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(_load),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }
            final data = snapshot.requireData;
            final projection = projectReview(
              window: _window,
              moodDays: activities.moodDays,
              timeline: data.stats.activityTimeline,
              sessions: data.sessions,
            );
            final history = {
              for (final point in data.stats.activityTimeline) point.day: point,
            };
            final insight = deriveInsight(
              history: history,
              coverage: CalendarCoverage(
                firstDay: _window.start,
                throughDay: _window.end,
              ),
              activities: activities,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChartCard(
                  title: 'Humeur',
                  icon: Icons.sentiment_satisfied_rounded,
                  color: AppColors.pink(dark),
                  background: AppColors.profileMoodCard(dark),
                  child: _MoodChart(
                    columns: projection.columns,
                    week: _period == ReviewPeriod.week,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                Text(
                  'Humeurs notées sur cet appareil.',
                  style: AppTextStyles.profileFootnote(
                    color: context.textTertiary,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing16),
                if (insight != null) ...[
                  ProfileCard(
                    color: Color.alphaBlend(
                      AppColors.yellow(dark)
                          .withValues(alpha: dark ? .17 : .13),
                      dark ? AppColors.scaffoldDark : Colors.white,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          color: AppColors.yellow(dark),
                          size: AppDimensions.profileSquare,
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight.title,
                                style: AppTextStyles.titleMedium(
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                insight.sentence,
                                style: AppTextStyles.bodyMedium(
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                ],
                _ChartCard(
                  title: 'Calme',
                  icon: Icons.air_rounded,
                  color: AppColors.teal(dark),
                  background: AppColors.profileCalmCard(dark),
                  value:
                      '${projection.calmTotal} min${projection.partialCalm ? ' · partiel' : ''}',
                  child: _BarChart(
                    columns: projection.columns,
                    week: _period == ReviewPeriod.week,
                    calm: true,
                  ),
                ),
                if (projection.partialCalm)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.spacing8),
                    child: Text(
                      'Historique des séances partiel.',
                      style: AppTextStyles.profileFootnote(
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                const SizedBox(height: AppDimensions.spacing16),
                _ChartCard(
                  title: 'Journal',
                  icon: Icons.edit_note_rounded,
                  color: AppColors.yellow(dark),
                  background: AppColors.profileJournalCard(dark),
                  value:
                      '${projection.journalTotal} ${projection.journalTotal == 1 ? 'écrit' : 'écrits'}',
                  child: _BarChart(
                    columns: projection.columns,
                    week: _period == ReviewPeriod.week,
                    calm: false,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _periodLabel() {
    String date(CivilDay day) => DateFormat(
      'd MMMM',
      'fr_FR',
    ).format(DateTime(day.year, day.month, day.day));
    return '${date(_window.start)} au ${date(_window.end)}';
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? value;
  final IconData icon;
  final Color color;
  final Color background;
  final Widget child;
  const _ChartCard({
    required this.title,
    this.value,
    required this.icon,
    required this.color,
    required this.background,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => ProfileCard(
    color: background,
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: AppDimensions.profileChartIcon,
              height: AppDimensions.profileChartIcon,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppDimensions.radius8),
              ),
              child: Icon(
                icon,
                size: AppDimensions.iconSm,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.titleSmall(color: context.textPrimary),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: AppTextStyles.editorDate(color: context.textPrimary),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing8),
        child,
      ],
    ),
  );
}

String _dayLabel(ReviewColumn column, bool week) {
  if (column.days.isEmpty) return '';
  return week
      ? const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][column.days.first.weekday - 1]
      : '${column.days.first.day}';
}

String _accessiblePeriod(ReviewColumn column) => column.days.isEmpty
    ? 'Avant ton arrivée'
    : column.days.length == 1
    ? column.days.first.isoDate
    : '${column.days.first.isoDate} au ${column.days.last.isoDate}';

class _MoodChart extends StatelessWidget {
  final List<ReviewColumn> columns;
  final bool week;
  const _MoodChart({required this.columns, required this.week});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: AppDimensions.profileChartHeight,
      child: Row(
        children: [
          SizedBox(
            width: AppDimensions.profileSquare,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final mood in [
                  MoodType.veryHappy,
                  MoodType.neutral,
                  MoodType.verySad,
                ])
                  Icon(
                    mood.icon,
                    size: AppDimensions.iconXs,
                    color: context.textTertiary,
                  ),
                const SizedBox(height: AppDimensions.spacing8),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: AppDimensions.spacing20,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 4; i++)
                        Divider(
                          height: AppDimensions.borderWidthThin,
                          color: dark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (final column in columns)
                      Expanded(
                        child: Semantics(
                          label:
                              '${_accessiblePeriod(column)}, ${column.mood?.label ?? 'humeur non renseignée'}',
                          child: ExcludeSemantics(
                            child: Stack(
                              children: [
                                if (column.mood != null)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom:
                                        AppDimensions.spacing24 +
                                        column.mood!.index *
                                            AppDimensions.profileMoodStep,
                                    child: Center(
                                      child: Container(
                                        width: AppDimensions.profileMoodDot,
                                        height: AppDimensions.profileMoodDot,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: column.mood!.colorFor(
                                            Theme.of(context).brightness,
                                          ),
                                          border: Border.all(
                                            width:
                                                AppDimensions.borderWidthMedium,
                                            color: dark
                                                ? AppColors.scaffoldDark
                                                : AppColors.scaffoldLight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Text(
                                    _dayLabel(column, week),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.moodLabel(
                                      color: context.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
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
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<ReviewColumn> columns;
  final bool week;
  final bool calm;
  const _BarChart({
    required this.columns,
    required this.week,
    required this.calm,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final values = [
      for (final column in columns) calm ? column.calm : column.journal,
    ];
    final maximum = values.fold(
      1,
      (maximum, value) => math.max(maximum, value ?? 0),
    );
    return SizedBox(
      height: AppDimensions.profileBarChart,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              child: Semantics(
                label:
                    '${_accessiblePeriod(columns[i])}, ${values[i] == null ? 'donnée inconnue' : '${values[i]} ${calm ? 'minutes de calme' : 'écrits'}'}',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: values[i] == null || values[i] == 0
                              ? const SizedBox.shrink()
                              : Container(
                                  width: AppDimensions.profileBarWidth,
                                  height:
                                      values[i]! /
                                      maximum *
                                      AppDimensions.profileBarHeight,
                                  decoration: BoxDecoration(
                                    color: calm
                                        ? AppColors.teal(dark)
                                        : AppColors.yellow(dark),
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radius4,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Text(
                        _dayLabel(columns[i], week),
                        style: AppTextStyles.moodLabel(
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
