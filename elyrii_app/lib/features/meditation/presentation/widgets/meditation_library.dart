import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/section_sky_header.dart';
import '../controllers/meditation_controller.dart';
import '../meditation_practices.dart';
import 'meditation_practice_preview.dart';
import 'meditation_duration_capsule.dart';

class MeditationLibrary extends StatefulWidget {
  final MeditationController controller;
  const MeditationLibrary({super.key, required this.controller});

  @override
  State<MeditationLibrary> createState() => _MeditationLibraryState();
}

class _MeditationLibraryState extends State<MeditationLibrary> {
  int _duration = 5;
  final _offset = ValueNotifier(0.0);
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() => _offset.value = math.max(0, _scroll.offset);

  @override
  void dispose() {
    _scroll.dispose();
    _offset.dispose();
    super.dispose();
  }

  Future<void> _open(MeditationPractice practice, BuildContext source) async {
    final box = source.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final duration = _duration;
    final start = await Navigator.of(context, rootNavigator: true).push<bool>(
      AppSheetRoute<bool>(
        reduced: MediaQuery.disableAnimationsOf(context),
        cardOrigin: origin,
        builder: (_) =>
            MeditationPracticePreview(practice: practice, duration: duration),
      ),
    );
    if (!mounted || start != true) return;
    widget.controller.setExercise(practice.exercise);
    widget.controller.setDuration(duration);
    await widget.controller.startSession();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final curation = MeditationPractice.curation[_duration]!;
    final practices = MeditationPractice.forDuration(_duration);
    final featured = MeditationPractice.forId(curation.featured)!;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final headerHeight =
        AppDimensions.sectionSkyHeight *
        MediaQuery.textScalerOf(context).scale(1).clamp(1, double.infinity);
    final capsuleRestTop =
        headerHeight -
        AppDimensions.sectionBodyOverlap -
        AppDimensions.accueilCapsuleOverhang;
    final capsulePinnedTop =
        MediaQuery.paddingOf(context).top +
        AppDimensions.accueilCapsulePinnedTop;
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: CustomScrollView(
              key: const Key('meditation-library-scroll'),
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SectionSkyHeader(
                        title: 'Méditer',
                        scene: SectionSkyScene.water,
                        height: headerHeight,
                        titleBottom:
                            AppDimensions.sectionTitleBottom +
                            AppDimensions.accueilCapsuleHeight,
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: headerHeight - AppDimensions.sectionBodyOverlap,
                        ),
                        child: SectionSkyBody(
                          bottomPadding: AppShell.bottomClearanceOf(context),
                          topPadding: AppDimensions.accueilSheetTopPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _featured(featured),
                              const SizedBox(
                                height: AppDimensions.accueilSectionGap,
                              ),
                              for (
                                var i = 0;
                                i < curation.shelves.length;
                                i++
                              ) ...[
                                _shelf(
                                  const [
                                    'Pour dormir',
                                    'Pour te calmer',
                                    'Pour te concentrer',
                                  ][i],
                                  curation.shelves[i],
                                ),
                                const SizedBox(
                                  height: AppDimensions.accueilSectionGap,
                                ),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: _heading('Toutes les pratiques'),
                                  ),
                                  Text(
                                    '${practices.length}',
                                    style: AppTextStyles.bodySmall(
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spacing12),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: dark
                                      ? AppColors.surfaceDark
                                      : AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radius20,
                                  ),
                                  border: Border.all(
                                    color: dark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                    width: .5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < practices.length;
                                      i++
                                    ) ...[
                                      _practiceRow(practices[i]),
                                      if (i < practices.length - 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: AppDimensions.spacing48,
                                          ),
                                          child: Divider(
                                            height: .5,
                                            thickness: .5,
                                            color: dark
                                                ? AppColors.dividerDark
                                                : AppColors.dividerLight,
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
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
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _offset,
          builder: (context, offset, _) {
            final compact = offset >= capsuleRestTop - capsulePinnedTop;
            return IgnorePointer(
              child: AnimatedOpacity(
                opacity: compact ? 1 : 0,
                duration: reduced ? Duration.zero : AppMotion.bandFade,
                curve: AppMotion.accueilEase,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      height:
                          MediaQuery.paddingOf(context).top +
                          AppDimensions.accueilBarHeight,
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.spacing12,
                      ),
                      decoration: BoxDecoration(
                        color: dark
                            ? AppColors.glassBackgroundDark
                            : AppColors.glassBackgroundLight,
                        border: Border(
                          bottom: BorderSide(
                            color: dark
                                ? AppColors.dividerDark
                                : AppColors.dividerLight,
                            width: .5,
                          ),
                        ),
                      ),
                      child: Text(
                        'Méditer',
                        style: AppTextStyles.navTitle(
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: _offset,
          builder: (context, offset, _) => Positioned(
            top: math.max(capsulePinnedTop, capsuleRestTop - offset),
            left: AppDimensions.pageHorizontalPadding,
            right: AppDimensions.pageHorizontalPadding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth:
                      AppDimensions.maxContentWidth -
                      AppDimensions.pageHorizontalPadding * 2,
                ),
                child: MeditationDurationCapsule(
                  selected: _duration,
                  compact: offset >= capsuleRestTop - capsulePinnedTop,
                  onChanged: (duration) => setState(() => _duration = duration),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heading(String title) => Semantics(
    header: true,
    child: Text(
      title,
      style: AppTextStyles.titleMedium(color: context.textPrimary),
    ),
  );

  Widget _featured(MeditationPractice practice) => Builder(
    builder: (source) => Semantics(
      button: true,
      label: 'Découvrir ${practice.title}',
      excludeSemantics: true,
      child: Material(
        color: practice.color,
        borderRadius: BorderRadius.circular(AppDimensions.radius24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('meditation-featured'),
          onTap: () => _open(practice, source),
          child: SizedBox(
            height:
                AppDimensions.meditationFeaturedHeight *
                MediaQuery.textScalerOf(context)
                    .scale(1)
                    .clamp(1, double.infinity),
            child: Stack(
              children: [
                const Positioned(
                  top: 0,
                  right: -AppDimensions.accueilSectionGap,
                  child: SizedBox(
                    width: AppDimensions.meditationFeaturedArtWidth,
                    height: AppDimensions.meditationFeaturedArtHeight,
                    child: CustomPaint(painter: _PracticeArt()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pour ce soir',
                        style: AppTextStyles.bodySmall(color: Colors.white),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  practice.title,
                                  style: AppTextStyles.titleMedium(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacing4),
                                Text(
                                  "$_duration min · pour t'endormir",
                                  style: AppTextStyles.bodySmall(
                                    color: Colors.white.withValues(alpha: .8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacing8),
                          Container(
                            width: AppDimensions.controlSize,
                            height: AppDimensions.controlSize,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Symbols.play_arrow_rounded,
                              fill: 1,
                              size: AppDimensions.meditationIcon,
                              color: AppColors.meditationPlay,
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
    ),
  );

  Widget _shelf(String title, List<String> ids) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(title),
      const SizedBox(height: AppDimensions.spacing12),
      SizedBox(
        height:
            AppDimensions.meditationTileSize *
            MediaQuery.textScalerOf(context).scale(1).clamp(1, double.infinity),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ids.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: AppDimensions.spacing12),
          itemBuilder: (_, index) {
            final practice = MeditationPractice.forId(ids[index])!;
            return Builder(
              builder: (source) => SizedBox(
                width:
                    AppDimensions.meditationTileSize *
                    MediaQuery.textScalerOf(context)
                        .scale(1)
                        .clamp(1, double.infinity),
                child: Material(
                  color: practice.color,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.meditationTileRadius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(practice, source),
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            practice.icon,
                            fill: 1,
                            size: AppDimensions.meditationIcon,
                            color: Colors.white,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                practice.title,
                                style: AppTextStyles.meditationTileTitle(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacing4),
                              Text(
                                practice.rhythm,
                                style: AppTextStyles.bodySmall(
                                  color: Colors.white.withValues(alpha: .78),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _practiceRow(MeditationPractice practice) => Builder(
    builder: (source) => InkWell(
      onTap: () => _open(practice, source),
      borderRadius: BorderRadius.circular(AppDimensions.radius20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimensions.meditationRowHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing8,
          ),
          child: Row(
            children: [
              Container(
                width: AppDimensions.spacing32,
                height: AppDimensions.spacing32,
                decoration: BoxDecoration(
                  color: practice.color,
                  borderRadius: BorderRadius.circular(AppDimensions.radius8),
                ),
                child: Icon(
                  practice.icon,
                  fill: 1,
                  size: AppDimensions.iconSm,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      practice.title,
                      style: AppTextStyles.titleSmall(
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      practice.subtitle,
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Icon(
                Symbols.chevron_right_rounded,
                size: AppDimensions.iconSm,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PracticeArt extends CustomPainter {
  const _PracticeArt();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / AppDimensions.meditationFeaturedArtWidth,
      size.height / AppDimensions.meditationFeaturedArtHeight,
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    for (final radius in [34.0, 65.0, 96.0]) {
      canvas.drawCircle(const Offset(146, 30), radius, paint);
    }
    canvas.drawLine(
      const Offset(15, 137),
      const Offset(180, 137),
      paint
        ..color = Colors.white.withValues(alpha: .22)
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PracticeArt oldDelegate) => false;
}
