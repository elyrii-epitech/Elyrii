part of 'dashboard_page.dart';

enum _AccueilOverlay { calendar, streak, flowers, dressing }

class _AccueilOverlayRoute extends PopupRoute<_AccueilOverlay> {
  final _AccueilOverlay kind;
  final bool reduced;
  final bool isDark;
  final DateTime now;
  final ValueChanged<_LookPreview?> onPreview;
  bool _saving = false;

  @override
  bool didPop(_AccueilOverlay? result) => !_saving && super.didPop(result);
  _AccueilOverlayRoute({
    required this.kind,
    required this.reduced,
    required this.isDark,
    required this.now,
    required this.onPreview,
  });

  @override
  Color? get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => 'Fermer la présentation';
  @override
  Duration get transitionDuration => reduced
      ? Duration.zero
      : kind == _AccueilOverlay.calendar
      ? AppMotion.calendarTransform
      : AppMotion.sheetEnter;
  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final calendar = kind == _AccueilOverlay.calendar;
    final dressing = kind == _AccueilOverlay.dressing;
    final safe = MediaQuery.paddingOf(context);
    final dock = AppShell.bottomClearanceOf(context) - AppDimensions.spacing24;
    final screen = MediaQuery.sizeOf(context);
    final top = calendar
        ? safe.top + AppDimensions.accueilBarHeight
        : math.min(
            safe.top + AppDimensions.accueilDressTop,
            screen.height * .46,
          );
    final maxHeight = calendar
        ? math.max(0.0, screen.height - top - dock - AppDimensions.spacing12)
        : dressing
        ? screen.height - top - safe.bottom - AppDimensions.spacing8
        : screen.height - safe.top - AppDimensions.spacing24;
    final panel = Align(
      alignment: calendar ? Alignment.topCenter : Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: calendar ? top : 0,
          left: AppDimensions.spacing8,
          right: AppDimensions.spacing8,
          bottom: calendar ? 0 : safe.bottom + AppDimensions.spacing8,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
            maxHeight: maxHeight,
          ),
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: switch (kind) {
                _AccueilOverlay.calendar => 'Calendrier',
                _AccueilOverlay.streak => 'Série',
                _AccueilOverlay.flowers => 'Fleurs de la semaine',
                _AccueilOverlay.dressing => 'Tenue d’Elyrii',
              },
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark
                      ? Color(
                          dressing
                              ? 0xF51E1B2A
                              : calendar
                              ? 0xF71E1B2A
                              : 0xE61E1B2A,
                        )
                      : Color(
                          dressing
                              ? 0xF7FAF9FD
                              : calendar
                              ? 0xFAFFFFFF
                              : 0xBDFAF9FD,
                        ),
                  borderRadius: BorderRadius.circular(
                    calendar ? AppDimensions.radius30 : AppDimensions.radius38,
                  ),
                  border: Border.all(
                    color: isDark
                        ? AppColors.glassBorderDark
                        : AppColors.glassBorderLight,
                    width: .5,
                  ),
                ),
                child: switch (kind) {
                  _AccueilOverlay.calendar => _CalendarPanel(now: now),
                  _AccueilOverlay.streak => _StreakSheet(now: now),
                  _AccueilOverlay.flowers => _FlowersSheet(now: now),
                  _AccueilOverlay.dressing => _Dressing(
                    onPreview: onPreview,
                    onBusy: (value) => _saving = value,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      child: panel,
      builder: (context, child) {
        final k = animation.value;
        final rise = AppMotion.accueilRise.transform(k);
        final veilDuration = calendar
            ? AppMotion.calendarFade
            : AppMotion.sheetVeil;
        final veil = AppMotion.accueilEase.transform(
          (k *
                  transitionDuration.inMicroseconds /
                  math.max(1, veilDuration.inMicroseconds))
              .clamp(0, 1),
        );
        final panelFade = calendar
            ? AppMotion.accueilEase.transform(
                (k *
                        AppMotion.calendarTransform.inMicroseconds /
                        AppMotion.calendarFade.inMicroseconds)
                    .clamp(0, 1),
              )
            : 1.0;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: dressing
                        ? 0
                        : (calendar
                                  ? (isDark ? .35 : .15)
                                  : (isDark ? .42 : .20)) *
                              veil,
                  ),
                ),
              ),
            ),
            if (calendar)
              Transform.translate(
                offset: Offset(
                  0,
                  -AppDimensions.accueilCalendarRiseDistance * (1 - rise),
                ),
                child: Transform.scale(
                  scale: .94 + .06 * rise,
                  alignment: Alignment.topCenter,
                  child: Opacity(
                    opacity: reduced ? 1 : panelFade,
                    child: child,
                  ),
                ),
              )
            else
              FractionalTranslation(
                translation: Offset(0, reduced ? 0 : 1.05 * (1 - rise)),
                child: child,
              ),
          ],
        );
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final bool closeEnabled;
  const _SheetHeader(this.title, {this.trailing, this.closeEnabled = true});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 36,
        height: 5,
        margin: const EdgeInsets.only(
          top: AppDimensions.spacing8,
          bottom: AppDimensions.spacing12,
        ),
        decoration: BoxDecoration(
          color: context.textTertiary.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(AppDimensions.radius4),
        ),
      ),
      Row(
        children: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: closeEnabled ? () => Navigator.of(context).pop() : null,
            icon: const Icon(Symbols.close_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.sheetTitle(color: context.textPrimary),
            ),
          ),
          trailing ?? const SizedBox(width: AppDimensions.controlSize),
        ],
      ),
    ],
  );
}

class _StreakSheet extends StatelessWidget {
  final DateTime now;
  const _StreakSheet({required this.now});
  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final today = CivilDay.fromLocal(now);
    final week = buildStreakWeek(
      today: today,
      currentStreak: dashboard.currentStreak,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing20,
        0,
        AppDimensions.spacing20,
        AppDimensions.spacing24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader('Série'),
          const SizedBox(height: AppDimensions.spacing16),
          if (dashboard.coverage == null)
            const Center(
              child: Text('Ta série sera affichée après le chargement.'),
            )
          else ...[
            Row(
              children: [
                CustomPaint(size: const Size(64, 76), painter: _FlamePainter()),
                const SizedBox(width: AppDimensions.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: dashboard.currentStreak.toDouble(),
                        ),
                        duration: _motion(context, AppMotion.countUp),
                        builder: (_, value, _) => Text(
                          '${(dashboard.currentStreak * AppMotion.countUpProgress(dashboard.currentStreak == 0 ? 1 : value / dashboard.currentStreak)).round()} ${dashboard.currentStreak == 1 ? 'jour' : 'jours'}',
                          style: AppTextStyles.streakHeadline(
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing8),
                      Text(
                        'Chaque présence compte, à ton rythme.',
                        style: AppTextStyles.bodyMedium(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing24),
            Row(
              children: [
                for (var i = 0; i < week.length; i++)
                  Expanded(
                    child: _Rise(
                      index: i,
                      duration: AppMotion.ritualCheck,
                      stagger: AppMotion.weekDotStagger,
                      distance: 0,
                      child: Column(
                        children: [
                          Text(
                            _weekdays[i],
                            style: AppTextStyles.labelSmall(
                              color: context.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing8),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: week[i].state == StreakDayState.done
                                  ? AppColors.orange(dark)
                                  : dark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                            ),
                            child: week[i].state == StreakDayState.done
                                ? const Icon(
                                    Symbols.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.spacing24),
          _SmallButton(
            label: 'Voir mon mois',
            plain: true,
            onTap: () => Navigator.of(context).pop(_AccueilOverlay.calendar),
          ),
        ],
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 76);
    final outer = Path()
      ..moveTo(32, 4)
      ..cubicTo(38, 18, 54, 26, 54, 46)
      ..arcToPoint(
        const Offset(10, 46),
        radius: const Radius.elliptical(22, 22),
        clockwise: true,
      )
      ..cubicTo(10, 36, 16, 29, 20, 24)
      ..cubicTo(20, 32, 24, 36, 28, 36)
      ..cubicTo(26, 24, 28, 14, 32, 4)
      ..close();
    canvas.drawPath(outer, Paint()..color = AppColors.orangeDark);
    final inner = Path()
      ..moveTo(32, 40)
      ..cubicTo(36, 46, 42, 49, 42, 57)
      ..arcToPoint(
        const Offset(22, 57),
        radius: const Radius.elliptical(10, 10),
        clockwise: true,
      )
      ..cubicTo(22, 52, 25, 49, 27, 47)
      ..cubicTo(27, 50, 29, 52, 31, 52)
      ..cubicTo(30, 47, 31, 43, 32, 40)
      ..close();
    canvas.drawPath(inner, Paint()..color = AppColors.yellowDark);
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => false;
}

class _FlowersSheet extends StatelessWidget {
  final DateTime now;
  const _FlowersSheet({required this.now});
  @override
  Widget build(BuildContext context) {
    final garden = context.watch<GamificationProvider>();
    final activities = context.watch<AccueilActivities>().snapshot;
    final flowers = buildWeekFlowers(
      today: CivilDay.fromLocal(now),
      completedChallenges: garden.completedChallenges,
      activities: activities,
    );
    final ready =
        garden.hasLoadedData && !garden.isLoading && garden.error == null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing20,
        0,
        AppDimensions.spacing20,
        AppDimensions.spacing24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader('Fleurs de la semaine'),
          const SizedBox(height: AppDimensions.spacing16),
          if (!ready) ...[
            if (garden.isLoading)
              const Center(child: CircularProgressIndicator()),
            if (garden.error != null)
              _InlineError(
                message: garden.error!,
                retry: () => garden.loadAll(force: true),
              ),
          ] else ...[
            _FlowerBed(flowers: flowers),
            const SizedBox(height: AppDimensions.spacing16),
            Text(
              '${flowers.all.length} ${flowers.all.length == 1 ? 'fleur' : 'fleurs'} cette semaine',
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              'Chaque défi terminé fait pousser une fleur. Sa couleur reprend l’humeur notée ce jour-là.',
              style: AppTextStyles.bodyMedium(color: context.textSecondary),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            for (final flower in flowers.all)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
                child: Row(
                  children: [
                    _SectionIcon(
                      icon: Symbols.local_florist_rounded,
                      color:
                          flower.mood?.colorFor(Theme.of(context).brightness) ??
                          context.textTertiary,
                    ),
                    const SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat(
                              'EEEE',
                              'fr_FR',
                            ).format(flower.day.toLocalDateTime()),
                            style: AppTextStyles.titleSmall(
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            '${flower.title}${flower.mood == null ? '' : ' · ${flower.mood!.label}'}',
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
          ],
          const SizedBox(height: AppDimensions.spacing16),
          _SmallButton(
            label: 'Voir mon jardin',
            filled: true,
            onTap: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.challenges);
            },
          ),
        ],
      ),
    );
  }
}

class _FlowerBed extends StatefulWidget {
  final WeekFlowers flowers;
  const _FlowerBed({required this.flowers});
  @override
  State<_FlowerBed> createState() => _FlowerBedState();
}

class _FlowerBedState extends State<_FlowerBed>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.flowerGrow + AppMotion.flowerStagger * 6,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppDimensions.radius20),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => CustomPaint(
        size: const Size(double.infinity, 150),
        painter: _FlowerPainter(
          widget.flowers,
          Theme.of(context).brightness,
          _controller.value,
        ),
      ),
    ),
  );
}

class _FlowerPainter extends CustomPainter {
  final WeekFlowers flowers;
  final Brightness brightness;
  final double progress;
  _FlowerPainter(this.flowers, this.brightness, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 350, size.height / 150);
    final dark = brightness == Brightness.dark;
    final paint = Paint();
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 350, 150),
      paint..color = Color(dark ? 0xFF1E1840 : 0xFFE3EFE7),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 112, 350, 38),
      paint..color = Color(dark ? 0xFF2A2158 : 0xFFD6CCF5),
    );
    for (var i = 0; i < 7; i++) {
      final x = 35.0 + 47 * i;
      final entries = flowers.byWeekday[i + 1] ?? const <WeekFlower>[];
      final total =
          (AppMotion.flowerGrow + AppMotion.flowerStagger * 6).inMilliseconds;
      final k = AppMotion.accueilRise.transform(
        ((progress * total - i * AppMotion.flowerStagger.inMilliseconds) /
                AppMotion.flowerGrow.inMilliseconds)
            .clamp(0, 1),
      );
      for (var j = 0; j < math.max(1, entries.length); j++) {
        final flower = entries.isEmpty ? null : entries[j];
        final dx = x + (j - (entries.length - 1) / 2) * 10;
        final top = flower == null ? 92.0 : 64.0 - j % 2 * 9;
        canvas.drawLine(
          Offset(dx, 114),
          Offset(dx, 114 - (114 - top) * k),
          paint
            ..color = AppColors.green(dark)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        canvas.save();
        canvas.translate(dx, 114 - (114 - top) * k);
        canvas.scale(k);
        canvas.drawPath(
          Path()
            ..moveTo(0, 28)
            ..quadraticBezierTo(-12, 24, -14, 14)
            ..quadraticBezierTo(-2, 16, 0, 28)
            ..close(),
          paint
            ..color = AppColors.green(dark)
            ..style = PaintingStyle.fill,
        );
        if (flower == null) {
          canvas.drawOval(
            const Rect.fromLTWH(-5, -11, 10, 14),
            paint..color = AppColors.green(dark).withValues(alpha: .7),
          );
        } else {
          canvas.scale(.6 + .4 * k);
          final color =
              flower.mood?.colorFor(brightness) ??
              Color(dark ? 0xFFBDB6D2 : 0xFF777087);
          for (final (dx, dy) in [
            (0.0, -12.0),
            (10.0, -4.0),
            (-10.0, -4.0),
            (6.0, 7.0),
            (-6.0, 7.0),
          ]) {
            canvas.drawCircle(Offset(dx, dy), 8, paint..color = color);
          }
          canvas.drawCircle(
            const Offset(0, -2),
            5,
            paint..color = Colors.white.withValues(alpha: .85),
          );
        }
        canvas.restore();
      }
      final text = TextPainter(
        text: TextSpan(
          text: _weekdays[i],
          style: AppTextStyles.labelSmall(
            color: dark
                ? Colors.white.withValues(alpha: .75)
                : const Color(0xFF494451),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(x - text.width / 2, 128));
    }
  }

  @override
  bool shouldRepaint(_FlowerPainter old) =>
      old.progress != progress ||
      old.flowers != flowers ||
      old.brightness != brightness;
}

class _CalendarPanel extends StatefulWidget {
  final DateTime now;
  const _CalendarPanel({required this.now});
  @override
  State<_CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<_CalendarPanel> {
  late CivilDay _selected = CivilDay.fromLocal(widget.now);
  late CivilMonth _month = CivilMonth.containing(_selected);
  void _shift(int by) {
    setState(() => _month = _month.shifted(by));
    unawaited(context.read<DashboardProvider>().ensureCalendarHistory(_month));
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final activities = context.watch<AccueilActivities>().snapshot;
    final today = CivilDay.fromLocal(widget.now);
    final calendar = buildCalendarMonth(
      month: _month,
      today: today,
      history: dashboard.history,
      coverage: dashboard.coverage,
      activities: activities,
      currentStreak: dashboard.currentStreak,
    );
    final selectedCalendar = buildCalendarMonth(
      month: CivilMonth.containing(_selected),
      today: today,
      history: dashboard.history,
      coverage: dashboard.coverage,
      activities: activities,
      currentStreak: dashboard.currentStreak,
    );
    final selected = selectedCalendar.cells.firstWhere(
      (cell) => cell.day == _selected,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cells = <CalendarCell?>[
      ...List<CalendarCell?>.filled(calendar.leadingBlanks, null),
      ...calendar.cells,
    ];
    final rows = (cells.length / 7).ceil();
    final title = DateFormat(
      'MMMM yyyy',
      'fr_FR',
    ).format(_month.firstDay.toLocalDateTime());
    final detail = switch (selected.state) {
      CalendarCellState.future => 'À venir',
      CalendarCellState.uncovered => 'Données indisponibles pour ce jour',
      CalendarCellState.absent => 'Pas venu ce jour-là, et ce n’est pas grave.',
      CalendarCellState.presentWithMood ||
      CalendarCellState.presentWithoutMood => [
        selected.mood?.label ?? 'Présence notée',
        if (activities.rituals[_selected] != null)
          '${activities.rituals[_selected]!.completedAt.length} rituels sur 3',
        if (selected.journalEntries > 0)
          '${selected.journalEntries} ${selected.journalEntries == 1 ? 'écrit' : 'écrits'}',
      ].join(' · '),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${title[0].toUpperCase()}${title.substring(1)}',
                  style: AppTextStyles.titleMedium(color: context.textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'Mois précédent',
                onPressed: () => _shift(-1),
                icon: const Icon(Symbols.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Mois suivant',
                onPressed: _month.firstDay.isBefore(today)
                    ? () => _shift(1)
                    : null,
                icon: const Icon(Symbols.chevron_right_rounded),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Symbols.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Row(
            children: [
              for (final day in _weekdays)
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall(
                      color: context.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          for (var row = 0; row < rows; row++)
            _Rise(
              key: ValueKey('${_month.firstDay.isoDate}-$row'),
              index: row,
              duration: AppMotion.calendarRowRise,
              stagger: AppMotion.calendarRowStagger,
              distance: AppDimensions.accueilCalendarRiseDistance,
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child:
                          row * 7 + col >= cells.length ||
                              cells[row * 7 + col] == null
                          ? const SizedBox(
                              height: AppDimensions.accueilHeaderControl,
                            )
                          : _calendarDay(
                              context,
                              cells[row * 7 + col]!,
                              dark,
                              joinsLeft:
                                  col > 0 &&
                                  cells[row * 7 + col - 1]?.inStreak == true,
                              joinsRight:
                                  col < 6 &&
                                  row * 7 + col + 1 < cells.length &&
                                  cells[row * 7 + col + 1]?.inStreak == true,
                            ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppDimensions.spacing12),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing4,
            children: [
              for (final mood in MoodType.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: mood.colorFor(Theme.of(context).brightness),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing4),
                    Text(
                      mood.label,
                      style: AppTextStyles.labelSmall(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              Expanded(
                child: _calendarStat(
                  context,
                  dashboard.coverage == null
                      ? '—'
                      : '${dashboard.currentStreak} jours',
                  'Série en cours',
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: _calendarStat(
                  context,
                  '${calendar.presentDays} / ${calendar.elapsedDays}',
                  'Jours présents',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: dark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(AppDimensions.radius16),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        selected.mood?.colorFor(Theme.of(context).brightness) ??
                        context.textTertiary,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat(
                          'EEEE d MMMM',
                          'fr_FR',
                        ).format(_selected.toLocalDateTime()),
                        style: AppTextStyles.labelMedium(
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        detail,
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
          if (dashboard.isLoading) const LinearProgressIndicator(),
          if (dashboard.error != null)
            _InlineError(message: dashboard.error!, retry: dashboard.refresh),
        ],
      ),
    );
  }

  Widget _calendarDay(
    BuildContext context,
    CalendarCell cell,
    bool dark, {
    required bool joinsLeft,
    required bool joinsRight,
  }) {
    final present =
        cell.state == CalendarCellState.presentWithMood ||
        cell.state == CalendarCellState.presentWithoutMood;
    final selected = cell.day == _selected;
    final band = AppColors.orange(dark).withValues(alpha: .22);
    return AccessibleAction(
      label:
          '${cell.day.day} ${DateFormat('MMMM', 'fr_FR').format(cell.day.toLocalDateTime())}${cell.isToday ? ', aujourd’hui' : ''}',
      selected: selected,
      onPressed: () => setState(() => _selected = cell.day),
      child: SizedBox(
        height: AppDimensions.accueilHeaderControl,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (cell.inStreak)
              Positioned.fill(
                top: AppDimensions.spacing4 + AppDimensions.spacing2,
                bottom: AppDimensions.spacing4 + AppDimensions.spacing2,
                child: Row(
                  children: [
                    Expanded(
                      child: ColoredBox(
                        color: joinsLeft ? band : Colors.transparent,
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: joinsRight ? band : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.primaryText(dark)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      cell.mood?.colorFor(Theme.of(context).brightness) ??
                      (present
                          ? (dark ? AppColors.cardDark : AppColors.cardLight)
                          : null),
                  border: cell.isToday && !present
                      ? Border.all(color: context.textPrimary, width: 2)
                      : null,
                ),
                child: Text(
                  '${cell.day.day}',
                  style: AppTextStyles.labelMedium(
                    color: cell.mood != null
                        ? const Color(0xFF1B1530)
                        : present
                        ? context.textPrimary
                        : cell.state == CalendarCellState.absent
                        ? context.textTertiary
                        : context.textTertiary.withValues(alpha: .45),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarStat(BuildContext context, String value, String label) =>
      Container(
        padding: const EdgeInsets.all(AppDimensions.spacing12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.cardDark
              : AppColors.cardLight,
          borderRadius: BorderRadius.circular(AppDimensions.radius16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall(color: context.textTertiary),
            ),
          ],
        ),
      );
}
