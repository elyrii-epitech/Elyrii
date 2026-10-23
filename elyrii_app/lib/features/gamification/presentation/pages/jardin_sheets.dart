part of 'challenges_page.dart';

class _PeriodSheet extends StatefulWidget {
  final CivilMonth month;
  final ValueChanged<CivilMonth> onMonth;
  final VoidCallback onWeek;
  const _PeriodSheet({
    required this.month,
    required this.onMonth,
    required this.onWeek,
  });
  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late CivilMonth _month;
  @override
  void initState() {
    super.initState();
    _month = widget.month;
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppDimensions.spacing12,
    children: [
      Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _month = _month.shifted(-1)),
            tooltip: 'Mois précédent',
            icon: const Icon(Symbols.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              _monthLabel(_month),
              textAlign: TextAlign.center,
              style: AppTextStyles.titleSmall(color: context.textPrimary),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _month = _month.shifted(1)),
            tooltip: 'Mois suivant',
            icon: const Icon(Symbols.chevron_right_rounded),
          ),
        ],
      ),
      Text(
        'Du 1 au ${_month.lastDay.day} ${_monthLabel(_month)}',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall(color: context.textSecondary),
      ),
      FilledButton.tonal(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.tintSoft(
            Theme.of(context).brightness == Brightness.dark,
          ),
          foregroundColor: AppColors.primaryText(
            Theme.of(context).brightness == Brightness.dark,
          ),
        ),
        onPressed: () {
          widget.onMonth(_month);
          Navigator.of(context).pop();
        },
        child: const Text('Voir le mois'),
      ),
      TextButton(
        onPressed: () {
          widget.onWeek();
          Navigator.of(context).pop();
        },
        child: const Text('Cette semaine'),
      ),
    ],
  );
}

class _FlowerSheet extends StatelessWidget {
  final CivilDay day;
  final RitualDay? rituals;
  final List<WeekFlower> flowers;
  final MoodType? mood;
  const _FlowerSheet({
    required this.day,
    required this.rituals,
    required this.flowers,
    required this.mood,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entries =
        context
            .watch<JournalProvider?>()
            ?.entries
            .where((entry) => CivilDay.fromLocal(entry.createdAt) == day)
            .toList() ??
        [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing16,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          decoration: BoxDecoration(
            color: AppColors.gardenRewardThumb(dark),
            borderRadius: BorderRadius.circular(AppDimensions.radius20),
          ),
          child: Row(
            children: [
              if (flowers.isNotEmpty)
                _GardenFlower(
                  size: AppDimensions.gardenRewardHeight,
                  color:
                      mood?.colorFor(Theme.of(context).brightness) ??
                      AppColors.green(dark),
                )
              else
                Icon(
                  Symbols.eco_rounded,
                  size: AppDimensions.controlSize,
                  color: AppColors.green(dark),
                ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mood?.label ?? 'Une journée pour toi',
                      style: AppTextStyles.titleMedium(
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      flowers.isEmpty
                          ? 'Tes petits gestes sont enregistrés.'
                          : '${flowers.length} ${flowers.length == 1 ? 'fleur a poussé' : 'fleurs ont poussé'} ce jour-là.',
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (flowers.isNotEmpty)
          Text(
            'Tes défis terminés',
            style: AppTextStyles.titleMedium(color: context.textPrimary),
          ),
        for (final flower in flowers)
          ListTile(
            leading: Icon(
              Symbols.local_florist_rounded,
              color: AppColors.green(dark),
            ),
            title: Text(
              flower.title,
              style: AppTextStyles.titleSmall(color: context.textPrimary),
            ),
          ),
        if (rituals?.completedAt.isNotEmpty == true)
          Text(
            'Tes petits gestes',
            style: AppTextStyles.titleMedium(color: context.textPrimary),
          ),
        for (final done
            in rituals?.completedAt.entries ??
                const <MapEntry<AccueilRitual, DateTime>>[])
          _RitualRow(
            info: _gardenRituals.firstWhere((info) => info.ritual == done.key),
            detail: ritualDetail(
              _gardenRituals.firstWhere((info) => info.ritual == done.key),
              done.value,
            ),
            trailing: Icon(Symbols.check_rounded, color: AppColors.green(dark)),
          ),
        for (final entry in entries)
          ListTile(
            leading: Icon(
              Symbols.book_2_rounded,
              color: AppColors.yellow(dark),
            ),
            title: Text(
              entry.title,
              style: AppTextStyles.titleSmall(color: context.textPrimary),
            ),
            subtitle: const Text('Dans ton journal'),
            trailing: const Icon(Symbols.arrow_forward_rounded),
            onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
              AppSheetRoute<void>(
                reduced: MediaQuery.disableAnimationsOf(context),
                builder: (context) => AppSheetPanel(
                  title: entry.title,
                  child: SelectableText(
                    entry.content ?? '',
                    style: AppTextStyles.bodyLarge(color: context.textPrimary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddRitualSheet extends StatefulWidget {
  final AccueilActivities store;
  const _AddRitualSheet({required this.store});
  @override
  State<_AddRitualSheet> createState() => _AddRitualSheetState();
}

class _AddRitualSheetState extends State<_AddRitualSheet> {
  String _category = 'Tous';
  bool _saving = false;
  String? _error;

  Future<void> _add(AccueilRitualInfo info) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.store.addRitual(info.ritual);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error =
          widget.store.snapshot.error ??
          'Le rituel n’a pas pu être ajouté. Réessaie.';
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppDimensions.spacing16,
    children: [
      Text(
        "Un petit geste qui te fait du bien. Un seul suffit pour aujourd'hui.",
        style: AppTextStyles.bodyMedium(color: context.textSecondary),
      ),
      Wrap(
        spacing: AppDimensions.gardenGap,
        runSpacing: AppDimensions.gardenGap,
        children: [
          for (final category in ['Tous', 'Calme', 'Corps', 'Lien', 'Écriture'])
            ChoiceChip(
              label: Text(category),
              selected: category == _category,
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _category = category),
            ),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          style: AppTextStyles.bodySmall(
            color: AppColors.errorText(
              Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      for (final info in _gardenRituals.where(
        (info) =>
            _category == 'Tous' || _ritualCategories[info.ritual] == _category,
      ))
        _RitualRow(
          info: info,
          detail: info.pendingDetail,
          trailing:
              accueilRituals.contains(info) ||
                  widget.store.snapshot.addedRituals.contains(info.ritual)
              ? const Icon(
                  Symbols.check_rounded,
                  semanticLabel: 'Déjà dans ta journée',
                )
              : IconButton(
                  onPressed: _saving ? null : () => _add(info),
                  tooltip: 'Ajouter ${info.title}',
                  icon: const Icon(Symbols.add_circle_rounded),
                ),
        ),
    ],
  );
}

class _RewardSheet extends StatelessWidget {
  final MascotAccessory reward;
  final int count;
  final MascotModel mascot;
  const _RewardSheet({
    required this.reward,
    required this.count,
    required this.mascot,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing16,
      children: [
        Container(
          height: AppDimensions.gardenPreviewHeight,
          decoration: BoxDecoration(
            color: AppColors.gardenRewardThumb(dark),
            borderRadius: BorderRadius.circular(AppDimensions.radius20),
          ),
          child: Center(
            child: Semantics(
              label: 'Elyrii avec ${reward.name}',
              image: true,
              child: MascotWithAccessories(
                config: const Mascot3DConfig.authPage(),
                width: AppDimensions.gardenPreviewHeight,
                height: AppDimensions.gardenPreviewHeight,
                mascot: mascot,
              ),
            ),
          ),
        ),
        Text(
          reward.name,
          style: AppTextStyles.titleMedium(color: context.textPrimary),
        ),
        Text(
          reward.description,
          style: AppTextStyles.bodyMedium(color: context.textSecondary),
        ),
        Text(
          reward.isUnlocked(count)
              ? 'Cette tenue est débloquée dans ton dressing.'
              : '${reward.requiredChallenges} défis · encore ${reward.remainingChallenges(count)}',
          style: AppTextStyles.titleSmall(color: context.textPrimary),
        ),
        LinearProgressIndicator(
          value: (count / reward.requiredChallenges).clamp(0, 1),
          color: AppColors.green(dark),
          backgroundColor: AppColors.track(dark),
        ),
        Text(
          'Les défis terminés débloquent cette tenue. Tes rituels locaux restent dans ton jardin.',
          style: AppTextStyles.bodySmall(color: context.textSecondary),
        ),
      ],
    );
  }
}

class _GardenBreathing extends StatefulWidget {
  const _GardenBreathing();
  @override
  State<_GardenBreathing> createState() => _GardenBreathingState();
}

class _GardenBreathingState extends State<_GardenBreathing>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _started;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _tick({int minimum = 0}) {
    if (_started == null) return;
    setState(
      () => _seconds = math.max(
        minimum,
        DateTime.now().difference(_started!).inSeconds,
      ),
    );
    if (_seconds >= AppMotion.gardenBreathSession.inSeconds) _timer?.cancel();
  }

  void _start() {
    setState(() {
      _started = DateTime.now();
      _seconds = 0;
    });
    _timer = Timer.periodic(
      AppMotion.gardenBreathPhase,
      (timer) =>
          _tick(minimum: timer.tick * AppMotion.gardenBreathPhase.inSeconds),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _started != null) _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _seconds >= AppMotion.gardenBreathSession.inSeconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing16,
      children: [
        Icon(
          Symbols.air_rounded,
          size: AppDimensions.controlSize,
          color: AppColors.teal(
            Theme.of(context).brightness == Brightness.dark,
          ),
        ),
        Text(
          "Inspire doucement. Expire à ton rythme. Tu n'as rien à réussir.",
          style: AppTextStyles.bodyMedium(color: context.textSecondary),
        ),
        Semantics(
          liveRegion: true,
          child: FilledButton(
            onPressed: _started == null
                ? _start
                : finished
                ? () => Navigator.of(context).pop()
                : null,
            child: Text(
              _started == null
                  ? 'Commencer'
                  : finished
                  ? 'Terminer mon moment'
                  : (_seconds ~/ AppMotion.gardenBreathPhase.inSeconds).isEven
                  ? 'Inspire doucement · 4 secondes'
                  : 'Expire doucement · 4 secondes',
            ),
          ),
        ),
      ],
    );
  }
}

class _GardenChallenges extends StatefulWidget {
  final GamificationProvider provider;
  const _GardenChallenges({required this.provider});

  @override
  State<_GardenChallenges> createState() => _GardenChallengesState();
}

class _GardenChallengesState extends State<_GardenChallenges> {
  bool _busy = false;
  String? _feedback;

  Future<void> _perform(Future<bool> Function() command, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    final saved = await command();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = saved
          ? success
          : widget.provider.error ??
                'Le changement n’a pas été enregistré. Réessaie.';
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, child) {
      final provider = widget.provider;
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.spacing16,
        children: [
          Text(
            'Un petit pas à ton rythme. Les défis terminés font pousser les fleurs de ton jardin.',
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
          ),
          if (_feedback != null && provider.error == null)
            Semantics(
              liveRegion: true,
              child: Text(
                _feedback!,
                style: AppTextStyles.bodySmall(color: context.textPrimary),
              ),
            ),
          if (provider.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (provider.error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                provider.error!,
                style: AppTextStyles.bodyMedium(
                  color: AppColors.errorText(dark),
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => provider.loadAll(force: true),
              child: const Text('Réessayer'),
            ),
          ] else if (provider.hasLoadedData) ...[
            Text(
              'En cours',
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            if (provider.activeChallenges.isEmpty)
              Text(
                'Aucun défi en cours. Choisis une idée qui te fait du bien.',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            for (final challenge in provider.activeChallenges)
              _ChallengeIdea(
                title: challenge.displayTitle,
                description: challenge.displayDescription,
                progress: challenge,
              ),
            Text(
              'Les idées d’Elyrii',
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            if (provider.proposals.isEmpty)
              Text(
                'Pas de proposition pour le moment.',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            for (final proposal in provider.proposals)
              _ChallengeIdea(
                title: proposal.displayTitle,
                description: proposal.displayDescription,
                action: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppDimensions.spacing8,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => provider.rejectChallenge(proposal.id),
                              'La proposition a été retirée.',
                            ),
                      child: const Text('Refuser'),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryText(dark),
                        foregroundColor: AppColors.onTint(dark),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => provider.acceptChallenge(proposal.id),
                              'Ton défi est en cours.',
                            ),
                      child: const Text('Accepter'),
                    ),
                  ],
                ),
              ),
            Text(
              'Idées de défis',
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            if (provider.availableChallenges.isEmpty)
              Text(
                'Les prochains défis apparaîtront ici.',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            for (final challenge in provider.availableChallenges)
              _ChallengeIdea(
                title: challenge.title,
                description: challenge.description ?? '',
                action: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _perform(
                          () => provider.startChallenge(challenge.id),
                          'Ton défi est en cours.',
                        ),
                  icon: const Icon(Symbols.add_rounded),
                  label: const Text('Commencer'),
                ),
              ),
          ],
        ],
      );
    },
  );
}

class _ChallengeIdea extends StatelessWidget {
  final String title;
  final String description;
  final UserChallenge? progress;
  final Widget? action;
  const _ChallengeIdea({
    required this.title,
    required this.description,
    this.progress,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final challenge = progress;
    return Material(
      color: AppColors.gardenGroup(dark),
      borderRadius: BorderRadius.circular(AppDimensions.radius16),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.spacing8,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.eco_rounded,
                  size: AppDimensions.iconSm,
                  color: AppColors.green(dark),
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.titleSmall(color: context.textPrimary),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty)
              Text(
                description,
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            if (challenge != null && challenge.progress != null) ...[
              Text(
                challenge.progressText,
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
              LinearProgressIndicator(
                value: challenge.progressFraction,
                color: AppColors.green(dark),
                backgroundColor: AppColors.track(dark),
              ),
            ],
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}
