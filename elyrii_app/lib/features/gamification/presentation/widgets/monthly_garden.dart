import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/domain/accueil_content.dart';
import '../../../dashboard/domain/civil_day.dart';
import '../../../dashboard/presentation/mood_presentation.dart';

class MonthlyGarden extends StatefulWidget {
  const MonthlyGarden({
    super.key,
    required this.month,
    required this.today,
    required this.flowers,
    required this.onMonth,
    required this.onFlower,
  });

  final CivilMonth month;
  final CivilDay today;
  final List<WeekFlower> flowers;
  final ValueChanged<CivilMonth> onMonth;
  final ValueChanged<WeekFlower> onFlower;

  @override
  State<MonthlyGarden> createState() => _MonthlyGardenState();
}

class _MonthlyGardenState extends State<MonthlyGarden>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  final Map<String, int> _slotByChallengeId = {};
  Set<String> _animatingIds = {};

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.flowers.length; i++) {
      _slotByChallengeId[widget.flowers[i].challengeId] = i;
    }

    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.flowerGrow,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.accueilRise,
    );
    _controller.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 1.0;
      _animatingIds = {};
    }
  }

  @override
  void didUpdateWidget(MonthlyGarden oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.month != oldWidget.month) {
      _slotByChallengeId.clear();
      for (var i = 0; i < widget.flowers.length; i++) {
        _slotByChallengeId[widget.flowers[i].challengeId] = i;
      }
      _animatingIds = {};
      _controller.stop();
      _controller.value = 1;
      return;
    }
    final newIds = <String>{};
    for (final flower in widget.flowers) {
      if (!_slotByChallengeId.containsKey(flower.challengeId)) {
        _slotByChallengeId[flower.challengeId] = _slotByChallengeId.length;
        newIds.add(flower.challengeId);
      }
    }
    if (newIds.isEmpty) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _animatingIds = {};
      _controller.value = 1;
    } else {
      _animatingIds = newIds;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _formatMonth(CivilMonth month) =>
      AppDates.format(DateTime(month.year, month.month), 'MMMM yyyy');

  String _formatCount(int count) {
    if (count == 0) return '0 fleur';
    if (count == 1) return '1 fleur';
    return '$count fleurs';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canGoNext = widget.month.firstDay.isBefore(
      widget.today.civilMonth.firstDay,
    );
    final layouts = _buildLayouts(
      widget.flowers,
      widget.month,
      _slotByChallengeId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Symbols.chevron_left_rounded),
              tooltip: 'Mois précédent',
              constraints: const BoxConstraints(
                minWidth: AppDimensions.controlSize,
                minHeight: AppDimensions.controlSize,
              ),
              onPressed: () => widget.onMonth(widget.month.shifted(-1)),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatMonth(widget.month),
                    style: AppTextStyles.titleMedium(
                      color: context.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacing2),
                  Text(
                    _formatCount(widget.flowers.length),
                    style: AppTextStyles.bodySmall(
                      color: context.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Symbols.chevron_right_rounded),
              tooltip: 'Mois suivant',
              constraints: const BoxConstraints(
                minWidth: AppDimensions.controlSize,
                minHeight: AppDimensions.controlSize,
              ),
              onPressed: canGoNext
                  ? () => widget.onMonth(widget.month.shifted(1))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _MeadowViewport(
          month: widget.month,
          flowers: widget.flowers,
          layouts: layouts,
          animatingIds: _animatingIds,
          animation: _animation,
          dark: dark,
          onFlower: widget.onFlower,
        ),
      ],
    );
  }
}

class _FlowerLayout {
  const _FlowerLayout({
    required this.flower,
    required this.slotIndex,
    required this.blossomCenter,
    required this.groundOffset,
    required this.stemHeight,
    required this.curveOffset,
    required this.seed,
    required this.species,
    required this.tapTarget,
    required this.semanticLabel,
  });

  final WeekFlower flower;
  final int slotIndex;
  final Offset blossomCenter;
  final Offset groundOffset;
  final double stemHeight;
  final double curveOffset;
  final int seed;
  final int species;
  final Rect tapTarget;
  final String semanticLabel;
}

List<_FlowerLayout> _buildLayouts(
  List<WeekFlower> flowers,
  CivilMonth month,
  Map<String, int> slotByChallengeId,
) {
  final monthSeed = month.year * 12 + month.month;
  const slotWidth = 56.0;
  const leftPadding = 32.0;

  return [
    for (final flower in flowers)
      () {
        final slot = slotByChallengeId[flower.challengeId]!;
        var seed = monthSeed;
        for (var i = 0; i < flower.challengeId.length; i++) {
          seed = (seed * 31 + flower.challengeId.codeUnitAt(i)) & 0x7fffffff;
        }
        final jitterX = ((seed % 9) - 4.0) * 0.75;
        final x = leftPadding + (slot + 0.5) * slotWidth + jitterX;
        final tier = slot % 2;
        final groundY = 152.0 + tier * 22.0 + (((seed >> 3) % 7) - 3.0);
        final stemHeight = 44.0 + ((seed >> 6) % 18);
        final blossomY = groundY - stemHeight;
        final curveOffset = (((seed >> 10) % 15) - 7.0);
        final species = (seed ^ monthSeed) % 4;
        final center = Offset(x, blossomY);
        final tapTarget = Rect.fromCenter(
          center: center,
          width: 48.0,
          height: 48.0,
        );
        final dayDate = DateTime(
          flower.day.year,
          flower.day.month,
          flower.day.day,
        );
        final formattedDate = AppDates.format(dayDate, 'd MMMM yyyy');
        final semanticLabel = 'Fleur : ${flower.title} · $formattedDate';

        return _FlowerLayout(
          flower: flower,
          slotIndex: slot,
          blossomCenter: center,
          groundOffset: Offset(x, groundY),
          stemHeight: stemHeight,
          curveOffset: curveOffset,
          seed: seed,
          species: species,
          tapTarget: tapTarget,
          semanticLabel: semanticLabel,
        );
      }(),
  ];
}

class _MeadowViewport extends StatelessWidget {
  const _MeadowViewport({
    required this.month,
    required this.flowers,
    required this.layouts,
    required this.animatingIds,
    required this.animation,
    required this.dark,
    required this.onFlower,
  });

  final CivilMonth month;
  final List<WeekFlower> flowers;
  final List<_FlowerLayout> layouts;
  final Set<String> animatingIds;
  final Animation<double> animation;
  final bool dark;
  final ValueChanged<WeekFlower> onFlower;

  static const double _meadowHeight = 200.0;
  static const double _slotWidth = 56.0;
  static const double _horizontalPadding = 32.0;

  @override
  Widget build(BuildContext context) {
    final painter = _MeadowPainter(
      month: month,
      layouts: layouts,
      animatingIds: animatingIds,
      animation: animation,
      dark: dark,
    );
    return Container(
      height: flowers.isEmpty ? null : _meadowHeight,
      constraints: const BoxConstraints(minHeight: _meadowHeight),
      decoration: BoxDecoration(
        color: dark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppDimensions.radius20),
        border: Border.all(color: AppColors.gardenBorder(dark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: flowers.isEmpty
          ? Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: CustomPaint(painter: painter)),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.potted_plant_rounded,
                        size: AppDimensions.iconMd,
                        color: AppColors.green(dark),
                      ),
                      const SizedBox(height: AppDimensions.spacing8),
                      Text(
                        'Aucun défi complété ce mois-ci',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleSmall(
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Text(
                        'Accomplis des défis pour faire éclore ton jardin.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxSlot = layouts.fold<int>(
                  0,
                  (largest, layout) => math.max(largest, layout.slotIndex),
                );
                final contentWidth = math.max(
                  constraints.maxWidth,
                  _horizontalPadding * 2 + (maxSlot + 1) * _slotWidth,
                );
                return SingleChildScrollView(
                  key: ValueKey(month),
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: contentWidth,
                    height: _meadowHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: painter),
                        for (final layout in layouts)
                          Positioned(
                            left: layout.tapTarget.left,
                            top: layout.tapTarget.top,
                            width: layout.tapTarget.width,
                            height: layout.tapTarget.height,
                            child: Semantics(
                              button: true,
                              label: layout.semanticLabel,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onFlower(layout.flower),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MeadowPainter extends CustomPainter {
  _MeadowPainter({
    required this.month,
    required this.layouts,
    required this.animatingIds,
    required this.animation,
    required this.dark,
  }) : super(repaint: animation);

  final CivilMonth month;
  final List<_FlowerLayout> layouts;
  final Set<String> animatingIds;
  final Animation<double> animation;
  final bool dark;

  final Paint _skyPaint = Paint()..style = PaintingStyle.fill;
  final Paint _hillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _soilPaint = Paint()..style = PaintingStyle.fill;
  final Paint _stemPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;
  final Paint _leafPaint = Paint()..style = PaintingStyle.fill;
  final Paint _petalPaint = Paint()..style = PaintingStyle.fill;
  final Paint _centerPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final monthSeed = month.year * 12 + month.month;

    _skyPaint.color = dark ? AppColors.cardDark : AppColors.cardLight;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _skyPaint);

    _hillPaint.color = AppColors.green(dark)
        .withValues(alpha: dark ? 0.22 : 0.18);
    final backHill = Path()..moveTo(0, h * 0.68);
    var bx = 0.0;
    while (bx < w) {
      final step = math.min(160.0, w - bx);
      final mid = bx + step * 0.5;
      final end = bx + step;
      final wave = math.sin((bx / 160.0 + (monthSeed % 5)) * math.pi) * 12.0;
      backHill.quadraticBezierTo(mid, h * 0.62 + wave, end, h * 0.68);
      bx = end;
    }
    backHill.lineTo(w, h);
    backHill.lineTo(0, h);
    backHill.close();
    canvas.drawPath(backHill, _hillPaint);

    _hillPaint.color = AppColors.green(dark)
        .withValues(alpha: dark ? 0.38 : 0.32);
    final frontHill = Path()..moveTo(0, h * 0.80);
    var fx = 0.0;
    while (fx < w) {
      final step = math.min(180.0, w - fx);
      final mid = fx + step * 0.5;
      final end = fx + step;
      final wave = math.sin((fx / 180.0 + (monthSeed % 3)) * math.pi) * 10.0;
      frontHill.quadraticBezierTo(mid, h * 0.74 + wave, end, h * 0.80);
      fx = end;
    }
    frontHill.lineTo(w, h);
    frontHill.lineTo(0, h);
    frontHill.close();
    canvas.drawPath(frontHill, _hillPaint);

    _soilPaint.color = AppColors.gardenGroup(dark);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.88, w, h * 0.12), _soilPaint);

    if (layouts.isEmpty) return;

    final brightness = dark ? Brightness.dark : Brightness.light;
    _stemPaint.color = AppColors.green(dark);
    _leafPaint.color = AppColors.green(dark);

    for (final layout in layouts) {
      final isNew = animatingIds.contains(layout.flower.challengeId);
      final k = isNew ? animation.value : 1.0;
      final stemK = (k / 0.6).clamp(0.0, 1.0);
      final petalK = ((k - 0.4) / 0.6).clamp(0.0, 1.0);

      final currentStemHeight = layout.stemHeight * stemK;
      final currentBlossomY = layout.groundOffset.dy - currentStemHeight;
      final currentCenter = Offset(layout.blossomCenter.dx, currentBlossomY);

      final stemPath = Path()
        ..moveTo(layout.groundOffset.dx, layout.groundOffset.dy)
        ..quadraticBezierTo(
          layout.groundOffset.dx + layout.curveOffset * stemK,
          layout.groundOffset.dy - currentStemHeight * 0.5,
          currentCenter.dx,
          currentCenter.dy,
        );
      canvas.drawPath(stemPath, _stemPaint);

      if (stemK > 0.45) {
        final leafProgress = ((stemK - 0.45) / 0.55).clamp(0.0, 1.0);
        final leafY = layout.groundOffset.dy - currentStemHeight * 0.45;
        final leafDir = (layout.slotIndex % 2 == 0) ? 1.0 : -1.0;
        final leafX = layout.groundOffset.dx + layout.curveOffset * 0.45;

        canvas.save();
        canvas.translate(leafX, leafY);
        canvas.scale(leafProgress * ((layout.slotIndex % 2 == 0) ? 1.0 : 0.9));
        final leafPath = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(leafDir * 8, -4, leafDir * 12, 0)
          ..quadraticBezierTo(leafDir * 6, 5, 0, 0)
          ..close();
        canvas.drawPath(leafPath, _leafPaint);
        canvas.restore();
      }

      if (petalK > 0.0) {
        final tierScale = (layout.slotIndex % 2 == 0) ? 0.95 : 1.0;
        final scale = petalK * tierScale;

        canvas.save();
        canvas.translate(currentCenter.dx, currentCenter.dy);
        canvas.scale(scale);

        final color =
            layout.flower.mood?.colorFor(brightness) ??
            _paletteColor(layout.seed, monthSeed, dark);
        _petalPaint.color = color;
        _centerPaint.color = AppColors.xpBar;

        _drawBlossom(canvas, layout.species);
        canvas.restore();
      }
    }
  }

  Color _paletteColor(int seed, int monthSeed, bool dark) {
    return switch ((seed + monthSeed) % 6) {
      0 => AppColors.pink(dark),
      1 => AppColors.violet(dark),
      2 => AppColors.orange(dark),
      3 => AppColors.teal(dark),
      4 => AppColors.accent,
      _ => AppColors.yellow(dark),
    };
  }

  void _drawBlossom(Canvas canvas, int species) {
    switch (species) {
      case 0:
        // Marguerite à 6 pétales arrondis
        const count = 6;
        for (var i = 0; i < count; i++) {
          final angle = i * (2 * math.pi / count);
          final px = math.cos(angle) * 7.5;
          final py = math.sin(angle) * 7.5;
          canvas.drawCircle(Offset(px, py), 5.0, _petalPaint);
        }
        canvas.drawCircle(Offset.zero, 4.0, _centerPaint);
      case 1:
        // Tulipe / cloche à 3 pétales enveloppants
        canvas.drawOval(const Rect.fromLTWH(-7, -10, 6, 12), _petalPaint);
        canvas.drawOval(const Rect.fromLTWH(1, -10, 6, 12), _petalPaint);
        canvas.drawOval(const Rect.fromLTWH(-4, -12, 8, 14), _petalPaint);
        canvas.drawCircle(const Offset(0, -2), 3.0, _centerPaint);
      case 2:
        // Étoile campagnarde à 5 pétales fins
        const count = 5;
        for (var i = 0; i < count; i++) {
          final angle = i * (2 * math.pi / count) - math.pi / 2;
          final px = math.cos(angle) * 8.5;
          final py = math.sin(angle) * 8.5;
          canvas.drawCircle(Offset(px, py), 4.5, _petalPaint);
        }
        canvas.drawCircle(Offset.zero, 3.5, _centerPaint);
      default:
        // Rosette / pivoine double
        const count = 7;
        for (var i = 0; i < count; i++) {
          final angle = i * (2 * math.pi / count);
          final px = math.cos(angle) * 7.0;
          final py = math.sin(angle) * 7.0;
          canvas.drawCircle(Offset(px, py), 4.5, _petalPaint);
        }
        canvas.drawCircle(Offset.zero, 5.0, _centerPaint);
    }
  }

  @override
  bool shouldRepaint(_MeadowPainter oldDelegate) {
    return oldDelegate.month != month ||
        oldDelegate.layouts != layouts ||
        oldDelegate.animatingIds != animatingIds ||
        oldDelegate.animation != animation ||
        oldDelegate.dark != dark;
  }
}
