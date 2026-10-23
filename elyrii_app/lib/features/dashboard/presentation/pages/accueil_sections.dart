part of 'dashboard_page.dart';

class _AccueilSections extends StatelessWidget {
  final DateTime now;
  final Future<void> Function(AccueilAction) onAction;
  const _AccueilSections({required this.now, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final store = context.watch<AccueilActivities>();
    final activities = store.snapshot;
    final journal = context.watch<JournalProvider>();
    final mood = dashboard.selectedMood;
    final answer = answerForMood(mood, now);
    final layout = layoutForMood(mood);
    final today = CivilDay.fromLocal(now);
    final thread = projectThread(
      entries: journal.entries,
      now: now,
      activities: activities,
    );
    final insight = deriveInsight(
      history: dashboard.history,
      coverage: dashboard.coverage,
      activities: activities,
    );
    final monday = today.addDays(1 - today.weekday);
    final social = activities.socialWeeks[monday];
    final parts = <Widget>[
      _MoodPicker(
        part: dayPartOf(now),
        mood: mood,
        busy: dashboard.isSavingMood,
        onSelect: dashboard.selectMood,
      ),
      _Rise(
        key: const ValueKey('answer'),
        index: 1,
        child: _AnswerCard(answer: answer, mood: mood, onAction: onAction),
      ),
      if (dashboard.isSavingMood)
        Semantics(
          liveRegion: true,
          child: const Text('Enregistrement de ton humeur…'),
        ),
      if (dashboard.error != null)
        _InlineError(message: dashboard.error!, retry: dashboard.refresh),
      if (dashboard.cachedAt != null)
        Text(
          'Données hors ligne du ${DateFormat('d MMMM à HH:mm', 'fr_FR').format(dashboard.cachedAt!.toLocal())}.',
          style: AppTextStyles.bodySmall(color: context.textSecondary),
        ),
      if (activities.error != null) _InlineError(message: activities.error!),
      if (layout.showsRest)
        _Surface(
          child: Row(
            children: [
              _SectionIcon(
                icon: Symbols.bedtime_rounded,
                color: AppColors.violet(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(
                  restTitle,
                  style: AppTextStyles.titleSmall(color: context.textPrimary),
                ),
              ),
            ],
          ),
        ),
      if (layout.showsRituals)
        _Rise(
          key: const ValueKey('rituals'),
          index: 2,
          child: activities.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _Rituals(today: today, store: store),
        ),
      if (thread != null)
        _Rise(
          key: const ValueKey('thread'),
          index: 3,
          child: _ThreadCard(
            thread: thread,
            store: store,
            onChat: () => onAction(const OpenChat()),
          ),
        ),
      if (layout.showsSocial &&
          !activities.isLoading &&
          activities.error == null)
        _Rise(
          key: const ValueKey('social'),
          index: 4,
          child: _Surface(
            soft: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionIcon(
                      icon: Symbols.favorite_rounded,
                      color: AppColors.pink(
                        Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Un pas vers les autres',
                            style: AppTextStyles.titleSmall(
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing2),
                          Text(
                            socialIdeaAt(social?.ideaIndex ?? 0),
                            style: AppTextStyles.bodyMedium(
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing12),
                Wrap(
                  spacing: AppDimensions.spacing8,
                  runSpacing: AppDimensions.spacing8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _SmallButton(
                      onSoft: true,
                      label: social?.isDone(today) == true
                          ? 'Fait aujourd’hui'
                          : 'C’est fait',
                      onTap:
                          activities.isWriting || social?.isDone(today) == true
                          ? null
                          : () async {
                              if (await store.completeSocialStep(day: today)) {
                                ElyriiHaptics.success();
                              }
                            },
                    ),
                    _SmallButton(
                      label: 'Une autre idée',
                      plain: true,
                      onTap: activities.isWriting
                          ? null
                          : () => store.nextSocialIdea(day: today),
                    ),
                    Text(
                      '${social?.completedAt.length ?? 0} pas sur 3 cette semaine',
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (insight != null)
        _Rise(
          key: const ValueKey('insight'),
          index: 5,
          child: AccessibleAction(
            label: 'Ce qui t’aide, ouvrir le bilan',
            onPressed: () => onAction(const OpenReviews()),
            child: _Surface(
              child: Row(
                children: [
                  _SectionIcon(
                    icon: Symbols.lightbulb_rounded,
                    color: AppColors.yellow(
                      Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ce qui t’aide',
                          style: AppTextStyles.titleSmall(
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          insight.sentence,
                          style: AppTextStyles.bodySmall(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Symbols.chevron_right_rounded,
                    color: context.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimensions.accueilSectionGap),
          parts[i],
        ],
      ],
    );
  }
}

class _MoodPicker extends StatelessWidget {
  final DayPart part;
  final MoodType? mood;
  final bool busy;
  final Future<bool> Function(MoodType) onSelect;
  const _MoodPicker({
    required this.part,
    required this.mood,
    required this.busy,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final moment = switch (part) {
      DayPart.morning => 'ce matin',
      DayPart.afternoon => 'cet après-midi',
      DayPart.evening => 'ce soir',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comment te sens-tu $moment ?',
          style: AppTextStyles.titleMedium(color: context.textPrimary),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        LayoutBuilder(
          builder: (context, constraints) {
            final large = MediaQuery.textScalerOf(context).scale(11) > 16.5;
            final items = [
              for (final value in MoodType.values)
                SizedBox(
                  width: large ? null : constraints.maxWidth / 5,
                  child: Semantics(
                    selected: mood == value,
                    child: AccessibleAction(
                      label: value.label,
                      excludeChildSemantics: true,
                      onPressed: busy
                          ? null
                          : () {
                              ElyriiHaptics.selection();
                              onSelect(value);
                            },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: mood == value
                                ? AppDimensions.accueilMoodFaceSelectedScale
                                : 1,
                            duration: _motion(context, AppMotion.moodFaceTap),
                            curve: AppMotion.accueilEase,
                            child: Container(
                              width: AppDimensions.accueilMoodFace,
                              height: AppDimensions.accueilMoodFace,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: value
                                    .colorFor(Theme.of(context).brightness)
                                    .withValues(alpha: mood == value ? 1 : .18),
                                boxShadow: mood == value
                                    ? [
                                        BoxShadow(
                                          color: value
                                              .colorFor(
                                                Theme.of(context).brightness,
                                              )
                                              .withValues(alpha: .3),
                                          spreadRadius: 3,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                value.icon,
                                size: 28,
                                color: mood == value
                                    ? const Color(0xFF1B1530)
                                    : value.colorFor(
                                        Theme.of(context).brightness,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing8),
                          Text(
                            value.label,
                            style: mood == value
                                ? AppTextStyles.moodLabelSelected(
                                    color: context.textPrimary,
                                  )
                                : AppTextStyles.moodLabel(
                                    color: context.textTertiary,
                                  ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ];
            return large
                ? Wrap(
                    spacing: AppDimensions.spacing16,
                    runSpacing: AppDimensions.spacing12,
                    children: items,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items,
                  );
          },
        ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final AccueilAnswer answer;
  final MoodType? mood;
  final Future<void> Function(AccueilAction) onAction;
  const _AnswerCard({
    required this.answer,
    required this.mood,
    required this.onAction,
  });
  @override
  Widget build(BuildContext context) => _MotionSize(
    duration: AppMotion.answerSize,
    child: _Surface(
      soft: answer.isSoftPink,
      child: AnimatedSwitcher(
        duration: _motion(context, AppMotion.answerTextFade),
        switchInCurve: AppMotion.accueilEase,
        switchOutCurve: AppMotion.accueilEase,
        child: Column(
          key: ValueKey(mood),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(AppDimensions.spacing4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.cardDark
                        : AppColors.cardLight,
                  ),
                  child: Image.asset('assets/splash_icon.png'),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        answer.title,
                        style: AppTextStyles.titleSmall(
                          color: context.textPrimary,
                        ),
                      ),
                      if (answer.body case final body?) ...[
                        const SizedBox(height: AppDimensions.spacing2),
                        Text(
                          body,
                          style: AppTextStyles.bodyMedium(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (answer.actions.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacing12),
              Wrap(
                spacing: AppDimensions.spacing8,
                runSpacing: AppDimensions.spacing8,
                children: [
                  for (final action in answer.actions)
                    _SmallButton(
                      onSoft: answer.isSoftPink,
                      label: action.label,
                      icon: action.icon,
                      filled: action.filled,
                      onTap: () => onAction(action.action),
                    ),
                ],
              ),
            ],
            if (answer.showsHelp) ...[
              const SizedBox(height: AppDimensions.spacing12),
              AccessibleAction(
                label: helpLine,
                onPressed: () => onAction(const CallHelp()),
                child: Row(
                  children: [
                    Icon(
                      Symbols.call_rounded,
                      size: 18,
                      color: AppColors.helpInk(
                        Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing8),
                    Expanded(
                      child: Text(
                        helpLine,
                        style: AppTextStyles.labelMedium(
                          color: AppColors.helpInk(
                            Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Rituals extends StatelessWidget {
  final CivilDay today;
  final AccueilActivities store;
  const _Rituals({required this.today, required this.store});
  @override
  Widget build(BuildContext context) {
    final snapshot = store.snapshot;
    final done =
        snapshot.rituals[today]?.completedAt ??
        const <AccueilRitual, DateTime>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Rituels du jour',
                style: AppTextStyles.titleMedium(color: context.textPrimary),
              ),
            ),
            Text(
              '${accueilRituals.where((info) => done.containsKey(info.ritual)).length} sur ${accueilRituals.length}',
              style: AppTextStyles.bodySmall(color: context.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing12),
        LayoutBuilder(
          builder: (context, constraints) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final stacked =
                MediaQuery.textScalerOf(context).scale(13) > 19.5 ||
                constraints.maxWidth < 280;
            Widget tile(AccueilRitualInfo ritual) {
              final doneAt = done[ritual.ritual];
              return AccessibleAction(
                label:
                    '${doneAt != null ? 'Décocher' : 'Cocher'} ${ritual.title}',
                onPressed: snapshot.isWriting || snapshot.error != null
                    ? null
                    : () async {
                        final saved = await store.setRitualDone(
                          day: today,
                          ritual: ritual.ritual,
                          done: doneAt == null,
                        );
                        if (saved) ElyriiHaptics.success();
                      },
                child: Opacity(
                  opacity: doneAt != null ? .55 : 1,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 118),
                    padding: const EdgeInsets.symmetric(
                      horizontal:
                          AppDimensions.spacing8 + AppDimensions.spacing2,
                      vertical: AppDimensions.spacing12,
                    ),
                    decoration: _cardDecoration(
                      context,
                      AppDimensions.radius18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionIcon(
                              icon: ritual.icon,
                              color: ritual.color(dark),
                              small: true,
                            ),
                            _RitualCheck(done: doneAt != null),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        Text(
                          ritual.title,
                          style: AppTextStyles.ritualTitle(
                            color: context.textPrimary,
                          ),
                        ),
                        if (stacked)
                          const SizedBox(height: AppDimensions.spacing8)
                        else
                          const Spacer(),
                        Text(
                          doneAt == null
                              ? ritual.pendingDetail
                              : 'Fait à ${DateFormat('HH:mm').format(doneAt.toLocal())}',
                          style: AppTextStyles.ritualDetail(
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, ritual) in accueilRituals.indexed) ...[
                    if (index > 0)
                      const SizedBox(height: AppDimensions.spacing8),
                    tile(ritual),
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, ritual) in accueilRituals.indexed) ...[
                    if (index > 0)
                      const SizedBox(width: AppDimensions.spacing8),
                    Expanded(child: tile(ritual)),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RitualCheck extends StatelessWidget {
  final bool done;
  const _RitualCheck({required this.done});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.primaryText(dark) : Colors.transparent,
        border: Border.all(
          color: done ? AppColors.primaryText(dark) : context.textTertiary,
          width: 1.5,
        ),
      ),
      child: AnimatedSwitcher(
        duration: _motion(context, AppMotion.ritualCheck),
        switchInCurve: AppMotion.accueilPop,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: .6, end: 1.0).animate(animation),
          child: child,
        ),
        child: done
            ? Icon(
                Symbols.check_rounded,
                key: const ValueKey(true),
                size: 15,
                color: AppColors.onTint(dark),
              )
            : const SizedBox.shrink(key: ValueKey(false)),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final AccueilThread thread;
  final AccueilActivities store;
  final VoidCallback onChat;
  const _ThreadCard({
    required this.thread,
    required this.store,
    required this.onChat,
  });
  @override
  Widget build(BuildContext context) {
    final answer = store.snapshot.threadAnswers[thread.entryId];
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            thread.preamble,
            style: AppTextStyles.bodySmall(color: context.textTertiary),
          ),
          Container(
            margin: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacing8,
            ),
            padding: const EdgeInsets.only(left: AppDimensions.spacing12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.violet(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                  width: 2,
                ),
              ),
            ),
            child: Text(
              '« ${thread.quote} »',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium(color: context.textSecondary),
            ),
          ),
          Text(
            answer == null ? thread.question : threadReplyLine(answer.reply),
            style: AppTextStyles.titleSmall(color: context.textPrimary),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              if (answer == null) ...[
                _SmallButton(
                  label: 'Plutôt bien',
                  onTap: store.snapshot.isWriting
                      ? null
                      : () => store.answerThread(
                          entryId: thread.entryId,
                          reply: ThreadReply.ratherGood,
                        ),
                ),
                _SmallButton(
                  label: 'Bof',
                  onTap: store.snapshot.isWriting
                      ? null
                      : () => store.answerThread(
                          entryId: thread.entryId,
                          reply: ThreadReply.notGreat,
                        ),
                ),
              ],
              _SmallButton(
                label: 'J’en parle',
                plain: answer != null,
                onTap: onChat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(
  BuildContext context,
  double radius, {
  bool soft = false,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: soft
        ? Color.alphaBlend(
            AppColors.pink(dark).withValues(alpha: dark ? .17 : .13),
            dark ? const Color(0xFF15121F) : Colors.white,
          )
        : dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: dark ? AppColors.borderDark : const Color(0x09140E30),
      width: .5,
    ),
    boxShadow: dark
        ? null
        : const [
            BoxShadow(
              color: Color(0x0A140E30),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Color(0x0B140E30),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
  );
}

class _Surface extends StatelessWidget {
  final Widget child;
  final bool soft;
  const _Surface({required this.child, this.soft = false});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: _motion(context, AppMotion.answerBackground),
    curve: AppMotion.accueilEase,
    padding: const EdgeInsets.all(AppDimensions.spacing16),
    decoration: _cardDecoration(
      context,
      soft ? AppDimensions.accueilSectionGap : AppDimensions.radius20,
      soft: soft,
    ),
    child: child,
  );
}

class _SectionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool small;
  const _SectionIcon({
    required this.icon,
    required this.color,
    this.small = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: small ? 32 : 40,
    height: small ? 32 : 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(AppDimensions.radius12),
    ),
    child: Icon(icon, size: small ? 19 : 22, color: color, fill: 1),
  );
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool plain;
  final bool onSoft;
  const _SmallButton({
    required this.label,
    this.icon,
    this.onTap,
    this.filled = false,
    this.plain = false,
    this.onSoft = false,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Tint on tint-soft over the dark pink card measures 4.3:1; the label ink keeps 4.5:1.
    final color = filled
        ? AppColors.onTint(dark)
        : onSoft && dark && !plain
        ? context.textPrimary
        : AppColors.primaryText(dark);
    return AccessibleAction(
      label: label,
      excludeChildSemantics: true,
      onPressed: onTap,
      child: Align(
        widthFactor: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12 + AppDimensions.spacing2,
            vertical: AppDimensions.spacing4,
          ),
          decoration: BoxDecoration(
            color: plain
                ? Colors.transparent
                : filled
                ? AppColors.primaryText(dark)
                : AppColors.tintSoft(dark),
            borderRadius: BorderRadius.circular(AppDimensions.radius18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppDimensions.spacing4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.buttonSmall(
                    color: onTap == null ? context.textTertiary : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const _InlineError({required this.message, this.retry});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      children: [
        Text(
          message,
          style: AppTextStyles.bodySmall(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Actualiser')),
      ],
    ),
  );
}
