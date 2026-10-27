import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_shell.dart';
import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/section_sky_header.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../dashboard/domain/accueil_content.dart';
import '../../../dashboard/domain/civil_day.dart';
import '../providers/gamification_provider.dart';
import '../widgets/challenge_collection.dart';
import '../widgets/monthly_garden.dart';

const _extraRituals = [
  AccueilRitualInfo(
    ritual: AccueilRitual.reachOut,
    title: 'Écrire à un proche',
    pendingDetail: 'Lien · 2 min',
    icon: Symbols.favorite_rounded,
    color: AppColors.pink,
  ),
  AccueilRitualInfo(
    ritual: AccueilRitual.water,
    title: "Boire un verre d'eau",
    pendingDetail: 'Corps · 1 min',
    icon: Symbols.water_drop_rounded,
    color: AppColors.teal,
  ),
  AccueilRitualInfo(
    ritual: AccueilRitual.music,
    title: 'Écouter une chanson calme',
    pendingDetail: 'Respiration · 4 min',
    icon: Symbols.music_note_rounded,
    color: AppColors.violet,
  ),
];
final _gardenRituals = List<AccueilRitualInfo>.unmodifiable([
  ...accueilRituals,
  ..._extraRituals,
]);

String _dayLabel(CivilDay day) =>
    AppDates.format(DateTime(day.year, day.month, day.day), 'EEEE d MMMM yyyy');

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage>
    with WidgetsBindingObserver {
  static const _collapsedCount = 3;

  final _scroll = ScrollController();
  late CivilDay _today;
  late CivilMonth _month;
  Timer? _midnight;
  bool _showAllCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = CivilDay.fromLocal(DateTime.now());
    _month = _today.civilMonth;
    _scheduleMidnight();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<GamificationProvider>().loadAll());
    });
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      _updateDay,
    );
  }

  void _updateDay() {
    final next = CivilDay.fromLocal(DateTime.now());
    if (next != _today) {
      setState(() {
        if (_month == _today.civilMonth) _month = next.civilMonth;
        _today = next;
      });
    }
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _updateDay();
    unawaited(context.read<GamificationProvider>().loadAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      context.read<GamificationProvider>().loadAll(force: true);

  void _selectMonth(CivilMonth month) => setState(() {
    _month = month;
    _showAllCompleted = false;
  });

  void _openFlower(WeekFlower flower) {
    Navigator.of(context, rootNavigator: true).push<void>(
      AppSheetRoute<void>(
        reduced: MediaQuery.disableAnimationsOf(context),
        builder: (context) => AppSheetPanel(
          title: flower.title,
          child: Text(
            'Terminé le ${_dayLabel(flower.day)}',
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<AccueilActivities>().snapshot;
    final garden = context.watch<GamificationProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = AppShell.bottomClearanceOf(context);

    return Scaffold(
      backgroundColor: AppColors.sectionBody(dark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: Stack(
            children: [
              RefreshIndicator(
                edgeOffset:
                    MediaQuery.paddingOf(context).top +
                    AppDimensions.controlSize,
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Stack(
                        children: [
                          const SectionSkyHeader(
                            title: 'Défis',
                            scene: SectionSkyScene.garden,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              top:
                                  AppDimensions.sectionSkyHeight -
                                  AppDimensions.sectionBodyOverlap,
                            ),
                            child: SectionSkyBody(
                              bottomPadding: bottom + AppDimensions.spacing32,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: AppDimensions.spacing16,
                                children: [
                                  ChallengeCollection(provider: garden),
                                  _recordedGestures(snapshot, dark),
                                  const Divider(
                                    height: AppDimensions.spacing32,
                                  ),
                                  _monthlyGarden(garden, snapshot, dark),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Symbols.eco_rounded,
                                        color: AppColors.green(dark),
                                        size: AppDimensions.iconSm,
                                      ),
                                      const SizedBox(
                                        width: AppDimensions.spacing8,
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Chaque défi terminé fait grandir ton jardin.',
                                          style: AppTextStyles.bodySmall(
                                            color: context.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SectionSkyBar(
                scroll: _scroll,
                title: 'Défis',
                trailing: const SizedBox(width: AppDimensions.controlSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthlyGarden(
    GamificationProvider garden,
    AccueilActivitySnapshot snapshot,
    bool dark,
  ) {
    if (!garden.hasLoadedData) {
      return garden.error != null
          ? Text(
              'Tes fleurs apparaîtront dès que ton jardin sera synchronisé.',
              style: AppTextStyles.bodyMedium(color: context.textSecondary),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final completed = garden.completedChallenges;
    final end = _month.lastDay.isAfter(_today) ? _today : _month.lastDay;
    final flowers = buildGardenFlowers(
      completedChallenges: completed,
      activities: snapshot,
      start: _month.firstDay,
      end: end,
    );
    final undated = {
      for (final challenge in completed)
        if (challenge.completedAt == null) challenge.id,
    }.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing16,
      children: [
        MonthlyGarden(
          month: _month,
          today: _today,
          flowers: flowers,
          onMonth: _selectMonth,
          onFlower: _openFlower,
        ),
        _completedList(flowers, dark),
        if (undated > 0)
          Text(
            undated == 1
                ? "1 défi terminé n'a pas de date et ne peut pas être placé dans un mois."
                : "$undated défis terminés n'ont pas de date et ne peuvent pas être placés dans un mois.",
            style: AppTextStyles.bodySmall(color: context.textSecondary),
          ),
      ],
    );
  }

  Widget _completedList(List<WeekFlower> flowers, bool dark) {
    if (flowers.isEmpty) {
      return Material(
        color: AppColors.gardenGroup(dark),
        borderRadius: BorderRadius.circular(AppDimensions.radius16),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Text(
            'Aucun défi terminé pendant ce mois.',
            style: AppTextStyles.bodySmall(color: context.textSecondary),
          ),
        ),
      );
    }
    final recent = flowers.reversed;
    final visible = _showAllCompleted ? recent : recent.take(_collapsedCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing8,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppDimensions.spacing8,
          children: [
            Text(
              'Défis terminés',
              style: AppTextStyles.titleSmall(color: context.textPrimary),
            ),
            if (recent.length > _collapsedCount)
              Semantics(
                expanded: _showAllCompleted,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showAllCompleted = !_showAllCompleted),
                  child: Text(
                    _showAllCompleted
                        ? 'Réduire'
                        : 'Voir tout (${recent.length})',
                  ),
                ),
              ),
          ],
        ),
        for (final flower in visible)
          Material(
            color: AppColors.gardenGroup(dark),
            borderRadius: BorderRadius.circular(AppDimensions.radius12),
            child: ListTile(
              dense: true,
              leading: Icon(
                Symbols.check_circle_rounded,
                color: AppColors.green(dark),
                size: AppDimensions.iconSm,
              ),
              title: Text(
                flower.title,
                style: AppTextStyles.titleSmall(color: context.textPrimary),
              ),
              subtitle: Text(
                AppDates.format(
                  DateTime(flower.day.year, flower.day.month, flower.day.day),
                  'd MMMM yyyy',
                ),
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _recordedGestures(AccueilActivitySnapshot snapshot, bool dark) {
    final done =
        snapshot.rituals[_today]?.completedAt ??
        const <AccueilRitual, DateTime>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Aujourd'hui",
          style: AppTextStyles.titleMedium(color: context.textPrimary),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        if (snapshot.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (snapshot.error != null)
          Column(
            children: [
              Text(
                snapshot.error!,
                style: AppTextStyles.bodyMedium(
                  color: AppColors.errorText(dark),
                ),
              ),
              TextButton(
                onPressed: () => context.read<AccueilActivities>().reload(),
                child: const Text('Réessayer'),
              ),
            ],
          )
        else
          Material(
            color: AppColors.gardenGroup(dark),
            borderRadius: BorderRadius.circular(AppDimensions.radius20),
            clipBehavior: Clip.antiAlias,
            child: done.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    child: Text(
                      "Aucune activité enregistrée sur cet appareil aujourd’hui.",
                      style: AppTextStyles.bodyMedium(
                        color: context.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final entry in done.entries)
                        _RitualRow(
                          info: _gardenRituals.firstWhere(
                            (info) => info.ritual == entry.key,
                          ),
                          completedAt: entry.value,
                          trailing: Icon(
                            Symbols.check_rounded,
                            color: AppColors.green(dark),
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _RitualRow extends StatelessWidget {
  final AccueilRitualInfo info;
  final DateTime completedAt;
  final Widget trailing;
  const _RitualRow({
    required this.info,
    required this.completedAt,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = info.color(dark);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppDimensions.spacing4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppDimensions.radius8),
        ),
        child: Icon(
          info.icon,
          color: AppColors.onTint(true),
          size: AppDimensions.iconSm,
        ),
      ),
      title: Text(
        info.title,
        style: AppTextStyles.titleSmall(color: context.textPrimary),
      ),
      subtitle: Text(
        ritualDetail(info, completedAt),
        style: AppTextStyles.bodySmall(color: context.textSecondary),
      ),
      trailing: trailing,
    );
  }
}
