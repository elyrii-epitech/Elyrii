part of 'challenges_page.dart';

class _FlowerSheet extends StatelessWidget {
  final CivilDay day;
  final RitualDay? rituals;
  final List<UserChallenge> completedChallenges;
  final GardenDayProgress? progress;
  final bool flowersKnown;
  final MoodType? mood;
  const _FlowerSheet({
    required this.day,
    required this.rituals,
    required this.completedChallenges,
    required this.progress,
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
              if (completedChallenges.isNotEmpty)
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
                      completedChallenges.isNotEmpty
                          ? '${completedChallenges.length} ${completedChallenges.length == 1 ? 'défi terminé a fleuri' : 'défis terminés ont fleuri'} ce jour-là.'
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
            'Les défis de cette journée ne sont pas disponibles. Tes gestes locaux restent consultables.',
            style: AppTextStyles.bodySmall(color: context.textSecondary),
          )
        else if (progress != null)
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: AppColors.gardenGroup(dark),
              borderRadius: BorderRadius.circular(AppDimensions.radius16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppDimensions.spacing4,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.insights_rounded,
                      size: AppDimensions.iconSm,
                      color: AppColors.green(dark),
                    ),
                    const SizedBox(width: AppDimensions.spacing8),
                    Expanded(
                      child: Text(
                        progress!.total > 0
                            ? '${progress!.completed} sur ${progress!.total} défis terminés (${(progress!.completionRate! * 100).round()}%)'
                            : "Aucun défi n'était proposé ce jour-là",
                        style: AppTextStyles.titleSmall(
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Défis terminés ce jour ÷ défis créés au plus tard ce jour et non terminés avant ce jour.',
                  style: AppTextStyles.bodySmall(color: context.textSecondary),
                ),
              ],
            ),
          ),
        if (completedChallenges.isNotEmpty) ...[
          Text(
            'Tes défis terminés',
            style: AppTextStyles.titleMedium(color: context.textPrimary),
          ),
          for (final challenge in completedChallenges)
            ListTile(
              leading: Icon(
                Symbols.local_florist_rounded,
                color: AppColors.green(dark),
              ),
              title: Text(
                challenge.displayTitle,
                style: AppTextStyles.titleSmall(color: context.textPrimary),
              ),
            ),
        ],
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
