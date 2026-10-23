part of 'challenges_page.dart';

class _GardenCalendar extends StatelessWidget {
  final CivilDay today;
  final CivilMonth month;
  final CivilDay monday;
  final bool week;
  final AccueilActivitySnapshot snapshot;
  final List<WeekFlower> flowers;
  final bool flowersKnown;
  final ValueChanged<CivilDay> onDay;

  const _GardenCalendar({
    required this.today,
    required this.month,
    required this.monday,
    required this.week,
    required this.snapshot,
    required this.flowers,
    required this.flowersKnown,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final days = week
        ? List.generate(7, (index) => monday.addDays(index))
        : month.days;
    final flowerDays = flowers.map((flower) => flower.day).toSet();
    final ink = AppColors.gardenInk(dark);
    final firstOffset = week ? 0 : month.firstDay.weekday - 1;
    final rowCount = (firstOffset + days.length + 6) ~/ 7;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(
            AppDimensions.gardenCalendarMinWidth,
            constraints.maxWidth,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.gardenTouchPadding),
            decoration: BoxDecoration(
              color: AppColors.gardenBoard(dark),
              border: Border.all(color: AppColors.gardenBorder(dark)),
              borderRadius: BorderRadius.circular(AppDimensions.spacing24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          week
                              ? 'Du ${monday.day} au ${monday.addDays(6).day} ${_monthLabel(monday.civilMonth)}'
                              : _monthLabel(month),
                          style: AppTextStyles.titleMedium(
                            color: dark ? Colors.white : context.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Symbols.local_florist_rounded,
                        color: AppColors.gardenNote(dark),
                        size: AppDimensions.iconSm,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Row(
                  children: [
                    for (var index = 0; index < 7; index++)
                      Expanded(
                        child: Text(
                          '${['L', 'M', 'M', 'J', 'V', 'S', 'D'][index]}${week ? ' ${days[index].day}' : ''}',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.gardenCaption(color: ink),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing4),
                for (var row = 0; row < rowCount; row++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var column = 0; column < 7; column++)
                        Expanded(
                          child: _cell(
                            context,
                            row * 7 + column - firstOffset,
                            days,
                            flowerDays,
                            dark,
                          ),
                        ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing8),
                  child: !flowersKnown
                      ? Text(
                          'Les fleurs de cette période ne sont pas disponibles.',
                          style: AppTextStyles.bodySmall(color: ink),
                        )
                      : week
                      ? Row(
                          children: [
                            Text(
                              '${flowers.length}',
                              style: AppTextStyles.headlineSmall(
                                color: dark
                                    ? AppColors.accentDark
                                    : AppColors.gardenNote(dark),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacing12),
                            Expanded(
                              child: Text(
                                'fleurs cette semaine\n${flowerDays.length} journées avec une fleur',
                                style: AppTextStyles.bodySmall(color: ink),
                              ),
                            ),
                          ],
                        )
                      : Wrap(
                          spacing: AppDimensions.spacing12,
                          runSpacing: AppDimensions.spacing8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _GardenFlower(
                                  size: AppDimensions.spacing16,
                                  color: AppColors.greenDark,
                                ),
                                const SizedBox(width: AppDimensions.spacing4),
                                Flexible(
                                  child: Text(
                                    'Un défi terminé',
                                    style: AppTextStyles.gardenCaption(
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: AppDimensions.spacing12,
                                  height: AppDimensions.spacing12,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.primaryText(dark),
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radius4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacing4),
                                Flexible(
                                  child: Text(
                                    "Aujourd'hui",
                                    style: AppTextStyles.gardenCaption(
                                      color: ink,
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
          ),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    int index,
    List<CivilDay> days,
    Set<CivilDay> flowerDays,
    bool dark,
  ) {
    if (index < 0 || index >= days.length) {
      return const SizedBox(height: AppDimensions.controlSize);
    }
    final day = days[index];
    final facts = snapshot.rituals[day];
    final flower = flowerDays.contains(day);
    final mood = snapshot.moodDays[day];
    final color =
        mood?.colorFor(Theme.of(context).brightness) ?? AppColors.green(dark);
    final info = facts?.completedAt.isNotEmpty == true
        ? _gardenRituals.firstWhere(
            (info) => info.ritual == facts!.completedAt.keys.first,
          )
        : null;
    return Column(
      spacing: AppDimensions.spacing8,
      children: [
        Semantics(
          button: true,
          onTap: () => onDay(day),
          label:
              '${_dayLabel(day)}, ${flower
                  ? 'une fleur'
                  : facts?.completedAt.isNotEmpty == true
                  ? '${facts!.completedAt.length} gestes enregistrés'
                  : day == today
                  ? "aujourd'hui"
                  : day.isAfter(today)
                  ? 'à venir'
                  : day.isBefore(today.addDays(-370))
                  ? 'historique local indisponible'
                  : 'aucun geste enregistré sur cet appareil'}${flowersKnown ? '' : ', fleurs non chargées'}',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onDay(day),
              borderRadius: BorderRadius.circular(
                AppDimensions.gardenPlotRadius,
              ),
              child: SizedBox(
                height: week
                    ? AppDimensions.gardenWeekPlotHeight
                    : AppDimensions.controlSize,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing4,
                    vertical: week ? 0 : AppDimensions.gardenPlotInset,
                  ),
                  child: Material(
                    color: flower
                        ? AppColors.gardenPlot(dark)
                        : AppColors.gardenEmptyPlot(dark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        week
                            ? AppDimensions.radius12
                            : AppDimensions.gardenPlotRadius,
                      ),
                      side: day == today
                          ? BorderSide(
                              color: AppColors.primaryText(dark),
                              width: AppDimensions.borderWidthMedium,
                            )
                          : BorderSide.none,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (flower)
                            _GardenFlower(
                              size: week
                                  ? AppDimensions.spacing32
                                  : AppDimensions.gardenFlowerSize,
                              color: color,
                            ),
                          if (!week || !flower)
                            Align(
                              alignment: flower
                                  ? Alignment.bottomLeft
                                  : Alignment.center,
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.spacing2,
                                ),
                                child: Text(
                                  '${day.day}',
                                  style: AppTextStyles.labelSmall(
                                    color: AppColors.gardenInk(dark),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (week)
          Text(
            info == null
                ? day.isAfter(today)
                      ? 'À venir'
                      : day == today
                      ? "Aujourd'hui"
                      : '—'
                : switch (info.ritual) {
                    AccueilRitual.breathe => 'Souffle',
                    AccueilRitual.gratitude => 'Écrire',
                    AccueilRitual.walk => 'Marche',
                    AccueilRitual.reachOut => 'Lien',
                    AccueilRitual.water => 'Eau',
                    AccueilRitual.music => 'Musique',
                  },
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTextStyles.gardenCaption(
              color: AppColors.gardenInk(dark),
            ),
          ),
      ],
    );
  }
}

class _GardenFlower extends StatelessWidget {
  final double size;
  final Color color;
  const _GardenFlower({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: RepaintBoundary(child: CustomPaint(painter: _FlowerPainter(color))),
  );
}

class _FlowerPainter extends CustomPainter {
  final Color color;
  const _FlowerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final paint = Paint()..color = AppColors.success;
    canvas.drawLine(
      const Offset(32, 38),
      const Offset(32, 60),
      paint
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(31, 54)
        ..cubicTo(18, 55, 15, 45, 15, 45)
        ..cubicTo(25, 43, 32, 47, 31, 54)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(33, 49)
        ..cubicTo(45, 49, 48, 40, 48, 40)
        ..cubicTo(38, 39, 31, 44, 33, 49)
        ..close(),
      paint,
    );
    canvas.translate(32, 28);
    paint.color = color;
    for (var index = 0; index < 6; index++) {
      canvas.drawOval(const Rect.fromLTWH(-8, -23, 16, 24), paint);
      canvas.rotate(math.pi / 3);
    }
    canvas.drawCircle(Offset.zero, 7, paint..color = AppColors.xpBar);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowerPainter oldDelegate) => oldDelegate.color != color;
}
