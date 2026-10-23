import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

enum SectionSkyScene { garden, window, water, arches }

class SectionSkyHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final SectionSkyScene scene;

  /// A control beside the title, such as the Journal « Privé » pill.
  final Widget? titleTrailing;
  final double height;
  final double titleBottom;

  const SectionSkyHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.scene,
    this.titleTrailing,
    this.height = AppDimensions.sectionSkyHeight,
    this.titleBottom = AppDimensions.sectionTitleBottom,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SectionSkyBackdrop(scene: scene),
          Positioned(
            left: AppDimensions.pageHorizontalPadding,
            right: AppDimensions.pageHorizontalPadding,
            bottom: titleBottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: AppDimensions.spacing12,
                  runSpacing: AppDimensions.spacing4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: AppTextStyles.pageTitle(
                          color: dark ? Colors.white : context.textPrimary,
                        ),
                      ),
                    ),
                    ?titleTrailing,
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMedium(
                    color: dark
                        ? Colors.white.withValues(alpha: .78)
                        : context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionSkyBody extends StatelessWidget {
  final Widget child;
  final double bottomPadding;
  final double topPadding;

  const SectionSkyBody({
    super.key,
    required this.child,
    this.bottomPadding = AppDimensions.spacing32,
    this.topPadding = AppDimensions.accueilSectionGap,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      AppDimensions.pageHorizontalPadding,
      topPadding,
      AppDimensions.pageHorizontalPadding,
      bottomPadding,
    ),
    decoration: BoxDecoration(
      color: AppColors.sectionBody(
        Theme.of(context).brightness == Brightness.dark,
      ),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radius30),
      ),
    ),
    child: child,
  );
}

class SectionSkyBackdrop extends StatelessWidget {
  final SectionSkyScene scene;
  const SectionSkyBackdrop({super.key, required this.scene});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _SkyPainter(
        scene,
        Theme.of(context).brightness == Brightness.dark,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  final SectionSkyScene scene;
  final bool dark;
  const _SkyPainter(this.scene, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = math.max(size.width / 390, size.height / 470);
    // The board's scenes use `xMidYMax slice`: the ground stays at the
    // bottom edge and the sky is cropped from the top.
    canvas.translate((size.width - 390 * scale) / 2, size.height - 470 * scale);
    canvas.scale(scale);
    final paint = Paint();
    Color color(int night, int light) => Color(dark ? night : light);
    void shape(Path path, int night, int light) =>
        canvas.drawPath(path, paint..color = color(night, light));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 390, 470),
      paint
        ..color = scene == SectionSkyScene.window
            ? color(0xFF1F1940, 0xFFEDE8FA)
            : AppColors.sectionSky(dark),
    );
    void stars(List<(double, double, double)> points) {
      if (!dark) return;
      for (final (x, y, r) in points) {
        canvas.drawCircle(Offset(x, y), r, paint..color = Colors.white);
      }
    }

    if (scene != SectionSkyScene.window) {
      stars(const [
        (40.0, 70.0, 1.3),
        (150.0, 60.0, 1.5),
        (214.0, 96.0, 1.0),
        (262.0, 52.0, 1.2),
        (360.0, 70.0, 1.0),
        (92.0, 170.0, 1.1),
        (300.0, 180.0, 1.0),
        (24.0, 236.0, 1.0),
        (352.0, 232.0, 1.2),
      ]);
    }
    switch (scene) {
      case SectionSkyScene.garden:
        canvas.drawCircle(
          const Offset(320, 200),
          16,
          paint..color = color(0xFFF1E6D2, 0xFFFFD7B0),
        );
        if (dark) {
          canvas.drawCircle(
            const Offset(329, 194),
            14,
            paint..color = AppColors.sectionSky(dark),
          );
        }
        shape(
          Path()
            ..moveTo(0, 318)
            ..cubicTo(90, 286, 200, 292, 390, 300)
            ..lineTo(390, 470)
            ..lineTo(0, 470)
            ..close(),
          0xFF1F3F47,
          0xFFD3ECDD,
        );
        shape(
          Path()
            ..moveTo(0, 352)
            ..cubicTo(120, 334, 250, 342, 390, 336)
            ..lineTo(390, 470)
            ..lineTo(0, 470)
            ..close(),
          0xFF2B5C52,
          0xFFBCE2CB,
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 384, 390, 86),
          paint..color = color(0xFF244D45, 0xFFA9D7BD),
        );
        for (final (x, y, c) in [
          (40.0, 352.0, AppColors.orangeDark),
          (82.0, 360.0, AppColors.yellowDark),
          (300.0, 356.0, AppColors.pinkDark),
          (342.0, 350.0, AppColors.tealDark),
        ]) {
          canvas.drawLine(
            Offset(x, y + 30),
            Offset(x, y + 6),
            paint
              ..color = AppColors.greenDark
              ..strokeWidth = 3,
          );
          canvas.drawPath(
            Path()
              ..moveTo(x, y + 22)
              ..quadraticBezierTo(x - 11, y + 19, x - 13, y + 10)
              ..quadraticBezierTo(x - 2, y + 12, x, y + 22)
              ..close(),
            paint,
          );
          for (final (dx, dy) in [
            (0.0, -6.0),
            (8.0, 0.0),
            (-8.0, 0.0),
            (5.0, 9.0),
            (-5.0, 9.0),
          ]) {
            canvas.drawCircle(Offset(x + dx, y + dy), 7, paint..color = c);
          }
          canvas.drawCircle(Offset(x, y + 2), 4.5, paint..color = Colors.white);
        }
        for (final (x, y) in [(122.0, 356.0), (268.0, 360.0)]) {
          canvas.drawLine(
            Offset(x, y + 30),
            Offset(x, y + 14),
            paint
              ..color = AppColors.greenDark
              ..strokeWidth = 3,
          );
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y + 10), width: 10, height: 14),
            paint,
          );
        }
      case SectionSkyScene.arches:
        for (final (left, top, r, night, light) in [
          (45.0, 214.0, 150.0, 0xFF251E52, 0xFFDCD3F7),
          (80.0, 224.0, 115.0, 0xFF30276A, 0xFFCFC3F3),
          (115.0, 234.0, 80.0, 0xFF3D3283, 0xFFC1B3EF),
        ]) {
          shape(
            Path()
              ..moveTo(left, 392)
              ..lineTo(left, top)
              ..arcToPoint(
                Offset(left + r * 2, top),
                radius: Radius.circular(r),
              )
              ..lineTo(left + r * 2, 392)
              ..close(),
            night,
            light,
          );
        }
        canvas.drawRect(
          const Rect.fromLTWH(0, 380, 390, 90),
          paint..color = color(0xFF2A2158, 0xFFD6CCF5),
        );
      case SectionSkyScene.water:
        canvas.drawCircle(
          const Offset(310, 268),
          24,
          paint..color = color(0xFFF1E6D2, 0xFFFFD7B0),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 292, 390, 178),
          paint..color = color(0xFF232B63, 0xFFC6D8F6),
        );
        shape(
          Path()
            ..moveTo(0, 292)
            ..lineTo(390, 292)
            ..lineTo(390, 306)
            ..cubicTo(300, 300, 100, 312, 0, 304)
            ..close(),
          0xFF2A2158,
          0xFFD6CCF5,
        );
        for (final (x, y, w) in [
          (282.0, 316.0, 56.0),
          (292.0, 330.0, 36.0),
          (300.0, 344.0, 20.0),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, w, 3),
              const Radius.circular(AppDimensions.spacing2),
            ),
            paint..color = color(0xFFF1E6D2, 0xFFFFD7B0).withValues(alpha: .55),
          );
        }
        for (final (x, y, w) in [
          (30.0, 360.0, 90.0),
          (260.0, 372.0, 100.0),
          (90.0, 396.0, 70.0),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, w, 2),
              const Radius.circular(AppDimensions.spacing2),
            ),
            paint..color = AppColors.tealDark.withValues(alpha: .25),
          );
        }
      case SectionSkyScene.window:
        shape(
          Path()
            ..moveTo(85, 360)
            ..lineTo(85, 170)
            ..arcToPoint(
              const Offset(305, 170),
              radius: const Radius.circular(AppDimensions.gardenBloomSize),
            )
            ..lineTo(305, 360)
            ..close(),
          0xFF2E2768,
          0xFFCFC3F3,
        );
        shape(
          Path()
            ..moveTo(97, 352)
            ..lineTo(97, 172)
            ..arcToPoint(
              const Offset(293, 172),
              radius: const Radius.circular(AppDimensions.gardenBloomSize),
            )
            ..lineTo(293, 352)
            ..close(),
          0xFF171233,
          0xFFDDE7FB,
        );
        stars(const [
          (140.0, 140.0, 1.3),
          (250.0, 120.0, 1.1),
          (214.0, 200.0, 1.0),
          (150.0, 230.0, 1.2),
          (268.0, 250.0, 1.0),
        ]);
        canvas.drawCircle(
          const Offset(238, 168),
          16,
          paint..color = color(0xFFF1E6D2, 0xFFFFD7B0),
        );
        canvas.drawCircle(
          const Offset(247, 162),
          14,
          paint..color = color(0xFF171233, 0xFFDDE7FB),
        );
        canvas.drawRect(
          const Rect.fromLTWH(194, 76, 2, 276),
          paint..color = color(0xFF2E2768, 0xFFCFC3F3),
        );
        canvas.drawRect(
          const Rect.fromLTWH(97, 250, 196, 2),
          paint..color = color(0xFF2E2768, 0xFFCFC3F3),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(40, 360, 310, 10),
            const Radius.circular(AppDimensions.radius4),
          ),
          paint..color = color(0xFF3A2F7C, 0xFFC2B4F0),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 370, 390, 100),
          paint..color = color(0xFF251E52, 0xFFDCD3F7),
        );
        canvas.drawPath(
          Path()
            ..moveTo(318, 360)
            ..relativeLineTo(22, 0)
            ..relativeLineTo(-3, -24)
            ..relativeLineTo(-16, 0)
            ..close(),
          paint..color = AppColors.journalPot,
        );
        canvas.drawPath(
          Path()
            ..moveTo(329, 336)
            ..relativeQuadraticBezierTo(-14, -20, -4, -36)
            ..relativeQuadraticBezierTo(8, 14, 4, 36)
            ..close()
            ..moveTo(329, 336)
            ..relativeQuadraticBezierTo(14, -18, 6, -32)
            ..relativeQuadraticBezierTo(-10, 12, -6, 32)
            ..close(),
          paint..color = AppColors.greenDark,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(58, 338, 14, 22),
            const Radius.circular(AppDimensions.radius4),
          ),
          paint..color = color(0xFFF1E6D2, 0xFFFFD7B0),
        );
        canvas.drawPath(
          Path()
            ..moveTo(65, 336)
            ..relativeQuadraticBezierTo(-5, -8, 0, -14)
            ..relativeQuadraticBezierTo(5, 6, 0, 14)
            ..close(),
          paint..color = AppColors.yellowDark,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.scene != scene;
}
