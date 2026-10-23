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
  final bool flowersKnown;
  final MoodType? mood;
  const _FlowerSheet({
    required this.day,
    required this.rituals,
    required this.flowers,
    required this.flowersKnown,
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
                      flowers.isNotEmpty
                          ? '${flowers.length} ${flowers.length == 1 ? 'fleur a poussé' : 'fleurs ont poussé'} ce jour-là.'
                          : rituals?.completedAt.isNotEmpty == true
                          ? 'Tes petits gestes sont enregistrés.'
                          : 'Aucun geste enregistré sur cet appareil ce jour-là.',
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
        if (!flowersKnown)
          Text(
            'Les fleurs de cette journée ne sont pas disponibles. Tes gestes locaux restent consultables.',
            style: AppTextStyles.bodySmall(color: context.textSecondary),
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
