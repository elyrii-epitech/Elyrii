part of 'challenges_page.dart';

class _RingPainter extends CustomPainter {
  final double rate;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _RingPainter({
    required this.rate,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (rate > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * math.pi * rate.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.rate != rate ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

class _GardenMeadow extends StatelessWidget {
  final List<UserChallenge> completedChallenges;
  const _GardenMeadow({required this.completedChallenges});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = completedChallenges.length;

    return Semantics(
      label: count == 0
          ? "Prairie du jardin sans fleur pour l'instant."
          : "Prairie du jardin avec $count ${count == 1 ? 'fleur épanouie' : 'fleurs épanouies'}.",
      image: true,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: dark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(AppDimensions.radius20),
          border: Border.all(color: AppColors.gardenBorder(dark)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MeadowPainter(
                  challenges: completedChallenges,
                  dark: dark,
                ),
              ),
            ),
            if (count == 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.potted_plant_rounded,
                        size: AppDimensions.iconLg,
                        color: AppColors.green(dark).withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: AppDimensions.spacing8),
                      Text(
                        'Ta prairie attend ses premières fleurs',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleSmall(
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Text(
                        'Chaque défi accompli fera éclore une fleur dans ton paysage.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MeadowPainter extends CustomPainter {
  final List<UserChallenge> challenges;
  final bool dark;

  const _MeadowPainter({required this.challenges, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Rolling hill 1 (back)
    final backHillPaint = Paint()
      ..color = AppColors.green(dark).withValues(alpha: dark ? 0.22 : 0.18)
      ..style = PaintingStyle.fill;
    final backHill = Path()
      ..moveTo(0, h * 0.72)
      ..cubicTo(w * 0.35, h * 0.62, w * 0.65, h * 0.78, w, h * 0.68)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(backHill, backHillPaint);

    // Rolling hill 2 (front)
    final frontHillPaint = Paint()
      ..color = AppColors.green(dark).withValues(alpha: dark ? 0.38 : 0.32)
      ..style = PaintingStyle.fill;
    final frontHill = Path()
      ..moveTo(0, h * 0.82)
      ..cubicTo(w * 0.25, h * 0.76, w * 0.75, h * 0.86, w, h * 0.78)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(frontHill, frontHillPaint);

    if (challenges.isEmpty) return;

    final displayCount = math.min(challenges.length, 30);
    final stemPaint = Paint()
      ..color = AppColors.green(dark)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final petalColors = dark
        ? const [
            Color(0xFFEF9A9A),
            Color(0xFFCE93D8),
            Color(0xFFFFCC80),
            Color(0xFF90CAF9),
            Color(0xFFA5D6A7),
            Color(0xFFFFF59D),
          ]
        : const [
            Color(0xFFE57373),
            Color(0xFFBA68C8),
            Color(0xFFFFB74D),
            Color(0xFF64B5F6),
            Color(0xFF81C784),
            Color(0xFFFFD54F),
          ];

    for (var i = 0; i < displayCount; i++) {
      final challenge = challenges[i];
      final seed = (challenge.id.hashCode ^ (i * 37)).abs();
      final jitter = ((seed % 100) / 100.0 - 0.5) * 0.5;
      final fracX = ((i + 0.5) / displayCount + jitter / displayCount).clamp(
        0.04,
        0.96,
      );
      final x = fracX * w;
      final groundY = h * 0.88 - ((seed >> 3) % 24);
      final stemHeight = 44.0 + ((seed >> 7) % 40);
      final blossomY = groundY - stemHeight;
      final curveOffset = (((seed >> 11) % 17) - 8.0);

      final stemPath = Path()
        ..moveTo(x, groundY)
        ..quadraticBezierTo(
          x + curveOffset,
          groundY - stemHeight * 0.5,
          x,
          blossomY,
        );
      canvas.drawPath(stemPath, stemPaint);

      // Blossom
      final color = petalColors[seed % petalColors.length];
      final petalPaint = Paint()..color = color;
      final petalCount = 5 + (seed % 2);
      const petalRadius = 6.0;
      for (var p = 0; p < petalCount; p++) {
        final angle = p * (2 * math.pi / petalCount);
        final px = x + math.cos(angle) * petalRadius;
        final py = blossomY + math.sin(angle) * petalRadius;
        canvas.drawCircle(Offset(px, py), 4.2, petalPaint);
      }
      canvas.drawCircle(
        Offset(x, blossomY),
        3.2,
        Paint()..color = AppColors.xpBar,
      );
    }
  }

  @override
  bool shouldRepaint(_MeadowPainter oldDelegate) =>
      oldDelegate.challenges != challenges || oldDelegate.dark != dark;
}

class _CompletedChallengesHistory extends StatefulWidget {
  final List<UserChallenge> completedChallenges;
  const _CompletedChallengesHistory({required this.completedChallenges});

  @override
  State<_CompletedChallengesHistory> createState() =>
      _CompletedChallengesHistoryState();
}

class _CompletedChallengesHistoryState
    extends State<_CompletedChallengesHistory> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final all = widget.completedChallenges;
    if (all.isEmpty) {
      return Material(
        color: AppColors.gardenGroup(dark),
        borderRadius: BorderRadius.circular(AppDimensions.radius16),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Text(
            "Aucun défi terminé pour l'instant. Tes réussites apparaîtront ici.",
            style: AppTextStyles.bodySmall(color: context.textSecondary),
          ),
        ),
      );
    }

    final visible = _expanded ? all : all.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing8,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Défis terminés (${all.length})',
                style: AppTextStyles.titleSmall(color: context.textPrimary),
              ),
            ),
            if (all.length > 3)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Réduire' : 'Voir tout (${all.length})'),
              ),
          ],
        ),
        for (final item in visible)
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
                item.displayTitle,
                style: AppTextStyles.titleSmall(color: context.textPrimary),
              ),
              subtitle: item.completedAt != null
                  ? Text(
                      AppDates.format(item.completedAt!, 'd MMMM yyyy'),
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

class _GardenCalendar extends StatelessWidget {
  final CivilDay today;
  final CivilMonth month;
  final ValueChanged<CivilMonth> onMonth;
  final AccueilActivitySnapshot snapshot;
  final List<GardenDayProgress> progressList;
  final bool progressKnown;
  final ValueChanged<CivilDay> onDay;

  const _GardenCalendar({
    required this.today,
    required this.month,
    required this.onMonth,
    required this.snapshot,
    required this.progressList,
    required this.progressKnown,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = AppColors.gardenInk(dark);
    final firstOffset = month.firstDay.weekday - 1;
    final rowCount = (firstOffset + progressList.length + 6) ~/ 7;
    final canGoNext = month.isBefore(today.civilMonth);

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing8,
                    vertical: AppDimensions.spacing4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => onMonth(month.shifted(-1)),
                        tooltip: 'Mois précédent',
                        icon: const Icon(Symbols.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          _monthLabel(month),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleMedium(
                            color: dark ? Colors.white : context.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: canGoNext
                            ? () => onMonth(month.shifted(1))
                            : null,
                        tooltip: 'Mois suivant',
                        icon: const Icon(Symbols.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing8,
                  ),
                  child: Text(
                    'Défis terminés ce jour ÷ défis créés au plus tard ce jour et non terminés avant ce jour.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.gardenCaption(color: ink),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                Row(
                  children: [
                    for (var index = 0; index < 7; index++)
                      Expanded(
                        child: Text(
                          ['L', 'M', 'M', 'J', 'V', 'S', 'D'][index],
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
                            dark,
                            ink,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: AppDimensions.spacing8),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing8),
                  child: !progressKnown
                      ? Text(
                          'Les données de cette période ne sont pas disponibles.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall(color: ink),
                        )
                      : Wrap(
                          spacing: AppDimensions.spacing16,
                          runSpacing: AppDimensions.spacing8,
                          alignment: WrapAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.green(dark),
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacing4),
                                Text(
                                  'Défi terminé',
                                  style: AppTextStyles.gardenCaption(
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.track(dark),
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacing4),
                                Text(
                                  '0% (non terminé)',
                                  style: AppTextStyles.gardenCaption(
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '—',
                                  style: AppTextStyles.gardenCaption(
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacing4),
                                Text(
                                  'Sans défi',
                                  style: AppTextStyles.gardenCaption(
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ink.withValues(alpha: 0.3),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacing4),
                                Text(
                                  'À venir',
                                  style: AppTextStyles.gardenCaption(
                                    color: ink,
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
    bool dark,
    Color ink,
  ) {
    if (index < 0 || index >= progressList.length) {
      return const SizedBox(height: AppDimensions.controlSize);
    }
    final progress = progressList[index];
    final day = progress.day;
    final facts = snapshot.rituals[day];
    final isFuture = day.isAfter(today);
    final rate = progress.completionRate;

    final rateDesc = isFuture
        ? 'à venir'
        : progress.total == 0
            ? 'aucun défi'
            : '${progress.completed} sur ${progress.total} défis (${(rate! * 100).round()}%)';
    final gesturesCount = facts?.completedAt.length ?? 0;
    final gesturesDesc = gesturesCount > 0
        ? '$gesturesCount ${gesturesCount == 1 ? 'geste enregistré' : 'gestes enregistrés'}'
        : 'aucun geste enregistré';

    return Column(
      children: [
        Semantics(
          button: true,
          onTap: () => onDay(day),
          label:
              '${_dayLabel(day)}, $rateDesc, $gesturesDesc${progressKnown ? '' : ', fleurs non chargées'}',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onDay(day),
              borderRadius: BorderRadius.circular(
                AppDimensions.gardenPlotRadius,
              ),
              child: SizedBox(
                height: AppDimensions.controlSize,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing4,
                    vertical: AppDimensions.gardenPlotInset,
                  ),
                  child: Material(
                    color: rate != null && rate > 0
                        ? AppColors.gardenPlot(dark)
                        : AppColors.gardenEmptyPlot(dark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.gardenPlotRadius,
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
                          if (isFuture)
                            Text(
                              '${day.day}',
                              style: AppTextStyles.labelSmall(
                                color: ink.withValues(alpha: 0.35),
                              ),
                            )
                          else if (progress.total == 0)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: AppTextStyles.labelSmall(color: ink),
                                ),
                                Text(
                                  '—',
                                  style: AppTextStyles.gardenCaption(
                                    color: ink.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            )
                          else
                            SizedBox.square(
                              dimension: 34,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(34, 34),
                                    painter: _RingPainter(
                                      rate: rate ?? 0.0,
                                      trackColor: AppColors.track(dark),
                                      progressColor: AppColors.green(dark),
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  Text(
                                    '${day.day}',
                                    style: AppTextStyles.labelSmall(
                                      color: dark
                                          ? Colors.white
                                          : context.textPrimary,
                                    ),
                                  ),
                                ],
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
