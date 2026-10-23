import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_shell.dart';
import '../../../../core/localization/app_dates.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/section_sky_header.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../dashboard/domain/accueil_content.dart';
import '../../../dashboard/domain/civil_day.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../../../journal/presentation/providers/journal_provider.dart';
import '../../../mascot/data/models/mascot_model.dart';
import '../../../mascot/data/models/mascot_accessory.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../../data/models/gamification_models.dart';
import '../providers/gamification_provider.dart';

part 'jardin_calendar.dart';
part 'jardin_sheets.dart';

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
    pendingDetail: 'Calme · 4 min',
    icon: Symbols.music_note_rounded,
    color: AppColors.violet,
  ),
];
final _gardenRituals = List<AccueilRitualInfo>.unmodifiable([
  ...accueilRituals,
  ..._extraRituals,
]);
const _ritualCategories = {
  AccueilRitual.breathe: 'Calme',
  AccueilRitual.gratitude: 'Écriture',
  AccueilRitual.walk: 'Corps',
  AccueilRitual.reachOut: 'Lien',
  AccueilRitual.water: 'Corps',
  AccueilRitual.music: 'Calme',
};

String _dayLabel(CivilDay day) =>
    AppDates.format(DateTime(day.year, day.month, day.day), 'EEEE d MMMM yyyy');
String _monthLabel(CivilMonth month) =>
    AppDates.format(DateTime(month.year, month.month), 'MMMM yyyy');

enum _GardenView { week, month }

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _todayKey = GlobalKey();
  final _periodKey = GlobalKey();
  final _frameKey = GlobalKey();
  double? _periodOrigin;
  _GardenView _view = _GardenView.month;
  late CivilDay _today;
  late CivilMonth _month;
  late CivilDay _monday;
  Timer? _midnight;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = CivilDay.fromLocal(DateTime.now());
    _month = _today.civilMonth;
    _monday = AccueilActivities.mondayOf(_today);
    _scheduleMidnight();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<GamificationProvider>().loadAll());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final period =
          _periodKey.currentContext?.findRenderObject() as RenderBox?;
      final frame = _frameKey.currentContext?.findRenderObject() as RenderBox?;
      if (period == null || frame == null) return;
      final origin =
          period.localToGlobal(Offset.zero, ancestor: frame).dy +
          _scroll.offset;
      if (_periodOrigin != origin) setState(() => _periodOrigin = origin);
    });
  }

  bool get _periodPinned =>
      _periodOrigin != null &&
      _scroll.hasClients &&
      _scroll.offset >=
          _periodOrigin! -
              MediaQuery.paddingOf(context).top -
              AppDimensions.sectionPeriodTop;

  Widget _periodButton() => TextButton.icon(
    onPressed: _period,
    icon: const Icon(Symbols.expand_more_rounded),
    iconAlignment: IconAlignment.end,
    label: Text(
      _view == _GardenView.month
          ? _monthLabel(_month)
          : '${_monday.day} – ${_monday.addDays(6).day} ${_monthLabel(_monday.civilMonth)}',
    ),
  );

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
        if (_monday == AccueilActivities.mondayOf(_today)) {
          _monday = AccueilActivities.mondayOf(next);
        }
        _today = next;
      });
    }
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updateDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: AppMotion.gardenToast),
      snackBarAnimationStyle: AnimationStyle.noAnimation,
    );
  }

  Future<void> _show(String title, Widget child) =>
      Navigator.of(context, rootNavigator: true).push<void>(
        AppSheetRoute<void>(
          reduced: MediaQuery.disableAnimationsOf(context),
          builder: (context) => AppSheetPanel(title: title, child: child),
        ),
      );

  void _period() {
    _show(
      'Choisir une période',
      _PeriodSheet(
        month: _month,
        onMonth: (month) {
          setState(() {
            _month = month;
            _view = _GardenView.month;
          });
        },
        onWeek: () {
          setState(() {
            _monday = AccueilActivities.mondayOf(_today);
            _view = _GardenView.week;
          });
        },
      ),
    );
  }

  void _goToToday() {
    final target = _todayKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.gardenTodayScroll,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _toggle(AccueilRitual ritual, bool done) async {
    final store = context.read<AccueilActivities>();
    final snapshot = store.snapshot;
    if (snapshot.isLoading || snapshot.isWriting || snapshot.error != null) {
      return;
    }
    final garden = context.read<GamificationProvider>();
    final known = garden.hasLoadedData && garden.error == null;
    final before = garden.completedChallenges
        .map((challenge) => challenge.id)
        .toSet();
    final day = _today;
    final saved = await store.setRitualDone(
      day: day,
      ritual: ritual,
      done: done,
    );
    if (!saved || !done) return;
    await garden.loadAll(force: true);
    final newFlower = garden.completedChallenges.any(
      (challenge) => !before.contains(challenge.id),
    );
    if (!mounted ||
        !known ||
        garden.error != null ||
        !newFlower ||
        _celebrating ||
        day != _today) {
      return;
    }
    _celebrating = true;
    final count = garden.completedChallenges.length;
    await _show(
      'Une nouvelle fleur !',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GardenFlower(
            size: AppDimensions.gardenBloomSize,
            color: AppColors.yellowDark,
          ),
          Text(
            'Ton jardin en compte $count.',
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            "Tu as pris un moment pour toi.\nC'est ça qui compte.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall(color: context.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Voir mon jardin'),
          ),
        ],
      ),
    );
    _celebrating = false;
  }

  void _openDay(
    CivilDay day,
    AccueilActivitySnapshot snapshot,
    List<WeekFlower> flowers,
  ) {
    final done = snapshot.rituals[day];
    if (flowers.isNotEmpty || done?.completedAt.isNotEmpty == true) {
      _show(
        _dayLabel(day),
        _FlowerSheet(
          day: day,
          rituals: done,
          flowers: flowers,
          mood: snapshot.moodDays[day],
        ),
      );
    } else if (day == _today) {
      _goToToday();
    } else if (day.isAfter(_today)) {
      _toast(
        'Cette journée est encore à venir. Ton jardin grandira à ton rythme.',
      );
    } else if (day.isBefore(_today.addDays(-370))) {
      _toast("L'historique local de cette journée n'est plus disponible.");
    } else {
      _toast(
        'Pas de défi terminé ce jour-là. Tu peux reprendre quand tu veux.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AccueilActivities>();
    final snapshot = store.snapshot;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = AppShell.bottomClearanceOf(context);
    final garden = context.watch<GamificationProvider>();
    final known =
        garden.hasLoadedData && !garden.isLoading && garden.error == null;
    final flowers = buildGardenFlowers(
      completedChallenges: garden.completedChallenges,
      activities: snapshot,
      start: _view == _GardenView.month ? _month.firstDay : _monday,
      end: _view == _GardenView.month ? _month.lastDay : _monday.addDays(6),
    );
    return Scaffold(
      backgroundColor: AppColors.sectionBody(dark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: Stack(
            key: _frameKey,
            children: [
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        const SectionSkyHeader(
                          title: 'Jardin',
                          subtitle: 'Tes petits gestes prennent des couleurs.',
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
                                _segments(dark),
                                AnimatedBuilder(
                                  animation: _scroll,
                                  child: Align(
                                    key: _periodKey,
                                    child: _periodButton(),
                                  ),
                                  builder: (context, child) => IgnorePointer(
                                    ignoring: _periodPinned,
                                    child: Opacity(
                                      opacity: _periodPinned ? 0 : 1,
                                      child: child,
                                    ),
                                  ),
                                ),
                                if (snapshot.isLoading)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else if (snapshot.error != null)
                                  _localError(snapshot.error!)
                                else ...[
                                  if (!known)
                                    Column(
                                      children: [
                                        Text(
                                          garden.error ??
                                              'Chargement de ton jardin…',
                                          style: AppTextStyles.bodyMedium(
                                            color: context.textSecondary,
                                          ),
                                        ),
                                        if (garden.error != null)
                                          TextButton(
                                            onPressed: () =>
                                                garden.loadAll(force: true),
                                            child: const Text('Réessayer'),
                                          ),
                                      ],
                                    )
                                  else ...[
                                    _GardenCalendar(
                                      today: _today,
                                      month: _month,
                                      monday: _monday,
                                      week: _view == _GardenView.week,
                                      snapshot: snapshot,
                                      flowers: flowers,
                                      onDay: (day) => _openDay(
                                        day,
                                        snapshot,
                                        flowers
                                            .where(
                                              (flower) => flower.day == day,
                                            )
                                            .toList(),
                                      ),
                                    ),
                                    if (_view == _GardenView.month)
                                      Text(
                                        '${flowers.length} fleurs en ${_monthLabel(_month)}',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.gardenNote(dark),
                                        ),
                                      ),
                                    if (_view == _GardenView.week)
                                      _weekAnswer(flowers.length, dark),
                                  ],
                                  _rituals(snapshot, dark),
                                ],
                                Material(
                                  color: AppColors.gardenGroup(dark),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radius20,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppDimensions.spacing16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      spacing: AppDimensions.spacing12,
                                      children: [
                                        Text(
                                          'Faire pousser mon jardin',
                                          style: AppTextStyles.titleMedium(
                                            color: context.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Chaque défi terminé fait pousser une fleur et te rapproche d’une nouvelle tenue.',
                                          style: AppTextStyles.bodyMedium(
                                            color: context.textSecondary,
                                          ),
                                        ),
                                        FilledButton.tonalIcon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primaryText(dark),
                                            foregroundColor: AppColors.onTint(
                                              dark,
                                            ),
                                          ),
                                          onPressed: () => _show(
                                            'Tes défis',
                                            _GardenChallenges(
                                              provider: context
                                                  .read<GamificationProvider>(),
                                            ),
                                          ),
                                          icon: const Icon(Symbols.eco_rounded),
                                          label: const Text('Choisir un défi'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _rewards(dark),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        'Un jour plus doux ? Repose-toi.\nTon jardin grandit à ton rythme.',
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, child) {
                    final compact =
                        _scroll.hasClients &&
                        _scroll.offset > AppDimensions.sectionScrollThreshold;
                    return SafeArea(
                      bottom: false,
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : AppMotion.bandFade,
                        curve: AppMotion.accueilEase,
                        color: compact
                            ? (dark
                                  ? AppColors.glassBackgroundDark
                                  : AppColors.glassBackgroundLight)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing20,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedOpacity(
                                opacity: compact ? 1 : 0,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : AppMotion.bandFade,
                                curve: AppMotion.accueilEase,
                                child: Text(
                                  'Jardin',
                                  style: AppTextStyles.navTitle(
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _period,
                              tooltip: 'Choisir une période',
                              icon: const Icon(Symbols.calendar_month_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top:
                    MediaQuery.paddingOf(context).top +
                    AppDimensions.sectionPeriodTop,
                left: AppDimensions.spacing20,
                right: AppDimensions.spacing20,
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, child) => Offstage(
                    offstage: !_periodPinned,
                    child: Align(
                      child: Material(
                        color: dark
                            ? AppColors.glassBackgroundDark
                            : AppColors.glassBackgroundLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusPill,
                        ),
                        child: _periodButton(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segments(bool dark) => Container(
    padding: const EdgeInsets.all(AppDimensions.spacing4),
    decoration: BoxDecoration(
      color: dark ? AppColors.cardDark : AppColors.cardLight,
      borderRadius: BorderRadius.circular(AppDimensions.radius12),
    ),
    child: Row(
      children: [
        for (final view in _GardenView.values)
          Expanded(
            child: Semantics(
              selected: _view == view,
              child: InkWell(
                onTap: () => setState(() => _view = view),
                borderRadius: BorderRadius.circular(AppDimensions.radius8),
                child: AnimatedContainer(
                  constraints: const BoxConstraints(
                    minHeight: AppDimensions.controlSize,
                  ),
                  alignment: Alignment.center,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppMotion.gardenSegment,
                  curve: AppMotion.accueilEase,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: _view == view
                        ? AppColors.primaryText(dark)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppDimensions.radius8),
                  ),
                  child: Text(
                    view == _GardenView.week ? 'Semaine' : 'Mois',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelMedium(
                      color: _view == view
                          ? AppColors.onTint(dark)
                          : context.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _localError(String error) => Column(
    children: [
      Text(
        error,
        style: AppTextStyles.bodyMedium(
          color: AppColors.errorText(
            Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
      TextButton(
        onPressed: () => context.read<AccueilActivities>().reload(),
        child: const Text('Réessayer'),
      ),
    ],
  );

  Widget _weekAnswer(int count, bool dark) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.gardenGroup(dark),
        borderRadius: BorderRadius.circular(AppDimensions.radius20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count fleurs cette semaine. Chaque petit geste compte.',
            style: AppTextStyles.bodyMedium(color: context.textPrimary),
          ),
          TextButton.icon(
            onPressed: () =>
                _show('Respirer 2 minutes', const _GardenBreathing()),
            icon: const Icon(Symbols.air_rounded),
            label: const Text('Respirer 2 min'),
          ),
        ],
      ),
    );
  }

  Widget _rituals(AccueilActivitySnapshot snapshot, bool dark) {
    final selected = _gardenRituals
        .where(
          (info) =>
              accueilRituals.contains(info) ||
              snapshot.addedRituals.contains(info.ritual),
        )
        .toList();
    final done =
        snapshot.rituals[_today]?.completedAt ??
        const <AccueilRitual, DateTime>{};
    return Column(
      key: _todayKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            Text(
              "Aujourd'hui",
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            Text(
              '${selected.where((info) => done.containsKey(info.ritual)).length} sur ${selected.length}',
              style: AppTextStyles.bodySmall(color: context.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing12),
        Material(
          color: AppColors.gardenGroup(dark),
          borderRadius: BorderRadius.circular(AppDimensions.radius20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final info in selected)
                _RitualRow(
                  info: info,
                  detail: ritualDetail(info, done[info.ritual]),
                  trailing: Checkbox(
                    value: done.containsKey(info.ritual),
                    semanticLabel: info.title,
                    onChanged: snapshot.isWriting
                        ? null
                        : (value) => _toggle(info.ritual, value!),
                  ),
                ),
              ListTile(
                leading: Icon(
                  Symbols.add_rounded,
                  color: AppColors.primaryText(dark),
                ),
                title: Text(
                  'Ajouter un rituel',
                  style: AppTextStyles.titleSmall(
                    color: AppColors.primaryText(dark),
                  ),
                ),
                onTap: snapshot.isWriting
                    ? null
                    : () => _show(
                        'Ajouter un rituel',
                        _AddRitualSheet(
                          store: context.read<AccueilActivities>(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rewards(bool dark) {
    final garden = context.watch<GamificationProvider>();
    final known = garden.hasLoadedData && garden.error == null;
    final count = garden.completedChallenges.length;
    final rewards = [
      'flower_crown',
      'star_crown',
    ].map((id) => MascotAccessories.byId(id)!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Prochaines récompenses',
          style: AppTextStyles.titleMedium(color: context.textPrimary),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        if (!known)
          Text(
            garden.error ?? 'Chargement des récompenses…',
            style: AppTextStyles.bodySmall(color: context.textSecondary),
          ),
        if (garden.error != null)
          TextButton(
            onPressed: () => garden.loadAll(force: true),
            child: const Text('Réessayer'),
          ),
        if (known)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: AppDimensions.spacing12,
              children: [
                for (final reward in rewards)
                  SizedBox(
                    width: AppDimensions.gardenRewardWidth,
                    child: Material(
                      color: AppColors.gardenReward(dark),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radius20,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius20,
                        ),
                        onTap: () => _show(
                          'Une tenue pour Elyrii',
                          _RewardSheet(
                            reward: reward,
                            count: count,
                            mascot: context
                                .read<MascotProvider>()
                                .mascot
                                .copyWith(equippedCosmetics: [reward.id]),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacing12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: AppDimensions.spacing8,
                            children: [
                              Container(
                                height: AppDimensions.gardenRewardHeight,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.gardenRewardThumb(dark),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radius12,
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/accessory_portraits/${reward.id}.png',
                                  height: AppDimensions.gardenRewardHeight,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Text(
                                reward.name,
                                style: AppTextStyles.titleSmall(
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                '${math.min(count, reward.requiredChallenges)} sur ${reward.requiredChallenges} défis',
                                style: AppTextStyles.bodySmall(
                                  color: context.textSecondary,
                                ),
                              ),
                              LinearProgressIndicator(
                                value: (count / reward.requiredChallenges)
                                    .clamp(0, 1),
                                color: AppColors.green(dark),
                                backgroundColor: AppColors.track(dark),
                              ),
                            ],
                          ),
                        ),
                      ),
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
  final String detail;
  final Widget trailing;
  const _RitualRow({
    required this.info,
    required this.detail,
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
        detail,
        style: AppTextStyles.bodySmall(color: context.textSecondary),
      ),
      trailing: trailing,
    );
  }
}
