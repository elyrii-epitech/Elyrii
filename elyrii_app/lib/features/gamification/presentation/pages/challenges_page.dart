import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_shell.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/widgets/section_sky_header.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../dashboard/domain/accueil_content.dart';
import '../../../dashboard/domain/civil_day.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../../../journal/presentation/providers/journal_provider.dart';
import '../../../mascot/data/models/mascot_accessory.dart';
import '../../../mascot/data/models/mascot_model.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../../data/models/gamification_models.dart';
import '../../domain/garden_progress.dart';
import '../providers/gamification_provider.dart';
import '../widgets/challenge_collection.dart';

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

String _dayLabel(CivilDay day) =>
    AppDates.format(DateTime(day.year, day.month, day.day), 'EEEE d MMMM yyyy');
String _monthLabel(CivilMonth month) =>
    AppDates.format(DateTime(month.year, month.month), 'MMMM yyyy');

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  late CivilDay _today;
  late CivilMonth _month;
  Timer? _midnight;

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

  void _openDay(
    CivilDay day,
    AccueilActivitySnapshot snapshot,
    GardenDayProgress progress,
    List<UserChallenge> completedOnDay, {
    required bool progressKnown,
  }) {
    final hasFacts =
        (progressKnown && progress.total > 0) ||
        completedOnDay.isNotEmpty ||
        (snapshot.rituals[day]?.completedAt.isNotEmpty == true);
    if (day.isAfter(_today)) {
      _toast(
        'Cette journée est encore à venir. Ton jardin grandira à ton rythme.',
      );
    } else if (!hasFacts && day.isBefore(_today.addDays(-370))) {
      _toast("L'historique local de cette journée n'est plus disponible.");
    } else {
      _show(
        _dayLabel(day),
        _FlowerSheet(
          day: day,
          rituals: snapshot.rituals[day],
          completedChallenges: completedOnDay,
          progress: progress,
          flowersKnown: progressKnown,
          mood: snapshot.moodDays[day],
        ),
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
    final known = garden.hasLoadedData;

    final progressList = buildGardenProgress(
      today: _today,
      month: _month,
      activeChallenges: garden.activeChallenges,
      completedChallenges: garden.completedChallenges,
    );

    return Scaffold(
      backgroundColor: AppColors.sectionBody(dark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        const SectionSkyHeader(
                          title: 'Jardin',
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

                                const Divider(height: AppDimensions.spacing32),

                                if (snapshot.isLoading)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else if (snapshot.error != null)
                                  _localError(snapshot.error!)
                                else ...[
                                  _statsSection(garden, dark),
                                  const SizedBox(
                                    height: AppDimensions.spacing8,
                                  ),
                                  Text(
                                    'Complétion quotidienne',
                                    style: AppTextStyles.titleMedium(
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  _GardenCalendar(
                                    today: _today,
                                    month: _month,
                                    onMonth: (m) => setState(() => _month = m),
                                    snapshot: snapshot,
                                    progressList: progressList,
                                    progressKnown: known,
                                    onDay: (day) {
                                      final progress =
                                          progressList[day.day - 1];
                                      final completedOnDay = garden
                                          .completedChallenges
                                          .where((c) {
                                            final completedAt = c.completedAt;
                                            return completedAt != null &&
                                                CivilDay.fromLocal(
                                                      completedAt,
                                                    ) ==
                                                    day;
                                          })
                                          .toList();
                                      _openDay(
                                        day,
                                        snapshot,
                                        progress,
                                        completedOnDay,
                                        progressKnown: known,
                                      );
                                    },
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacing8,
                                  ),
                                  _recordedGestures(snapshot, dark),
                                ],

                                const Divider(height: AppDimensions.spacing32),

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
              SectionSkyBar(
                scroll: _scroll,
                title: 'Jardin',
                trailing: const SizedBox(width: AppDimensions.controlSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsSection(GamificationProvider garden, bool dark) {
    if (garden.isLoading && !garden.hasLoadedData) {
      return Column(
        children: [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'Chargement de ton jardin…',
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
          ),
        ],
      );
    }

    if (garden.error != null && !garden.hasLoadedData) {
      return Column(
        children: [
          Text(
            garden.error!,
            style: AppTextStyles.bodyMedium(color: AppColors.errorText(dark)),
          ),
          TextButton(
            onPressed: () => garden.loadAll(force: true),
            child: const Text('Réessayer'),
          ),
        ],
      );
    }

    final completed = garden.completedChallenges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing16,
      children: [
        if (garden.error != null)
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: AppColors.gardenGroup(dark),
              borderRadius: BorderRadius.circular(AppDimensions.radius12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    garden.error!,
                    style: AppTextStyles.bodySmall(
                      color: AppColors.errorText(dark),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => garden.loadAll(force: true),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Icon(
              Symbols.local_florist_rounded,
              color: AppColors.green(dark),
              size: AppDimensions.iconSm,
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: Text(
                'Ta prairie',
                style: AppTextStyles.titleMedium(color: context.textPrimary),
              ),
            ),
            Text(
              completed.isEmpty
                  ? '0 fleur'
                  : '${completed.length} ${completed.length == 1 ? 'fleur' : 'fleurs'}',
              style: AppTextStyles.labelMedium(
                color: AppColors.successText(dark),
              ),
            ),
          ],
        ),
        _GardenMeadow(completedChallenges: completed),
        _CompletedChallengesHistory(completedChallenges: completed),
      ],
    );
  }

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
        Material(
          color: AppColors.gardenGroup(dark),
          borderRadius: BorderRadius.circular(AppDimensions.radius20),
          clipBehavior: Clip.antiAlias,
          child: done.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing16),
                  child: Text(
                    "Aucun geste enregistré sur cet appareil aujourd'hui.",
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
                        detail: ritualDetail(
                          _gardenRituals.firstWhere(
                            (info) => info.ritual == entry.key,
                          ),
                          entry.value,
                        ),
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
