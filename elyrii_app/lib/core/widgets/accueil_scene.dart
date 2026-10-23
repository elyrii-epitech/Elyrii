import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/dashboard/data/accueil_activities.dart';

class AccueilScenePainter extends CustomPainter {
  /// Art line kept at its phone-frame height when a wide column makes the art
  /// overflow vertically, so the moon and the ground both stay in view.
  static const _horizon = 300.0;
  final MascotDecor decor;
  final bool dark;
  final bool thumbnail;
  const AccueilScenePainter({
    required this.decor,
    required this.dark,
    this.thumbnail = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = thumbnail
        ? math.max(size.width / 370, size.height / 230)
        : math.max(size.width / 390, size.height / 470);
    canvas.translate(
      thumbnail
          ? (size.width - 370 * scale) / 2 - 10 * scale
          : (size.width - 390 * scale) / 2,
      thumbnail
          ? (size.height - 230 * scale) / 2 - 150 * scale
          : size.height * _horizon / 470 - _horizon * scale,
    );
    canvas.scale(scale);
    final paint = Paint();
    Color color(int night, int light) => Color(dark ? night : light);
    void path(Path path, int night, int light) =>
        canvas.drawPath(path, paint..color = color(night, light));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 390, 470),
      paint
        ..color = color(
          0xFF1B1538,
          decor == MascotDecor.hills ? 0xFFE7E1FA : 0xFFE9E4FB,
        ),
    );
    if (dark) {
      const stars = [
        (40.0, 70.0, 1.3),
        (150.0, 60.0, 1.5),
        (214.0, 96.0, 1.0),
        (262.0, 52.0, 1.2),
        (360.0, 70.0, 1.0),
        (92.0, 170.0, 1.1),
        (300.0, 180.0, 1.0),
        (24.0, 236.0, 1.0),
        (352.0, 232.0, 1.2),
      ];
      for (final (x, y, r) in stars) {
        canvas.drawCircle(Offset(x, y), r, paint..color = Colors.white);
      }
    }
    switch (decor) {
      case MascotDecor.arches:
        for (final (left, top, r, night, light) in [
          (45.0, 214.0, 150.0, 0xFF251E52, 0xFFDCD3F7),
          (80.0, 224.0, 115.0, 0xFF30276A, 0xFFCFC3F3),
          (115.0, 234.0, 80.0, 0xFF3D3283, 0xFFC1B3EF),
        ]) {
          path(
            Path()
              ..moveTo(left, 392)
              ..lineTo(left, top)
              ..arcToPoint(
                Offset(left + r * 2, top),
                radius: Radius.elliptical(r, r),
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
      case MascotDecor.hills:
        if (dark) {
          canvas.drawCircle(
            const Offset(66, 214),
            17,
            paint..color = const Color(0xFFF1E6D2),
          );
          canvas.drawCircle(
            const Offset(75, 208),
            15,
            paint..color = const Color(0xFF1B1538),
          );
        } else {
          canvas.drawCircle(
            const Offset(300, 230),
            26,
            paint..color = const Color(0xFFFFD7B0),
          );
        }
        path(
          Path()
            ..moveTo(0, 320)
            ..cubicTo(80, 282, 160, 290, 230, 302)
            ..cubicTo(300, 314, 340, 276, 390, 282)
            ..lineTo(390, 470)
            ..lineTo(0, 470)
            ..close(),
          0xFF2C2463,
          0xFFD4C9F5,
        );
        path(
          Path()
            ..moveTo(0, 358)
            ..cubicTo(70, 338, 150, 332, 220, 346)
            ..cubicTo(290, 360, 330, 350, 390, 332)
            ..lineTo(390, 470)
            ..lineTo(0, 470)
            ..close(),
          0xFF3A2F7C,
          0xFFC2B4F0,
        );
        path(
          Path()
            ..moveTo(0, 388)
            ..cubicTo(100, 372, 260, 374, 390, 384)
            ..lineTo(390, 470)
            ..lineTo(0, 470)
            ..close(),
          0xFF4A3C96,
          0xFFAE9CEA,
        );
      case MascotDecor.waves:
        path(
          Path()
            ..moveTo(0, 270)
            ..cubicTo(90, 230, 170, 320, 260, 282)
            ..cubicTo(350, 244, 360, 240, 390, 256)
            ..lineTo(390, 320)
            ..cubicTo(330, 306, 280, 350, 200, 336)
            ..cubicTo(120, 322, 60, 290, 0, 320)
            ..close(),
          0xFF2B2361,
          0xFFD4C9F5,
        );
        path(
          Path()
            ..moveTo(0, 332)
            ..cubicTo(100, 300, 190, 370, 290, 338)
            ..cubicTo(390, 306, 370, 316, 390, 320)
            ..lineTo(390, 380)
            ..cubicTo(320, 370, 250, 400, 160, 384)
            ..cubicTo(70, 368, 50, 360, 0, 372)
            ..close(),
          0xFF3A2F7C,
          0xFFC2B4F0,
        );
        path(
          Path()
            ..moveTo(0, 380)
            ..cubicTo(120, 360, 240, 404, 390, 376)
            ..lineTo(390, 470)
            ..lineTo(0, 470)
            ..close(),
          0xFF4A3C96,
          0xFFAE9CEA,
        );
      case MascotDecor.clearing:
        path(
          Path()
            ..moveTo(0, 320)
            ..cubicTo(120, 290, 260, 300, 390, 312)
            ..lineTo(390, 470)
            ..lineTo(0, 470)
            ..close(),
          0xFF2E5B4A,
          0xFFBCE2CB,
        );
        path(
          Path()
            ..moveTo(0, 350)
            ..cubicTo(140, 334, 250, 346, 390, 340)
            ..lineTo(390, 470)
            ..lineTo(0, 470)
            ..close(),
          0xFF3B7259,
          0xFFA9D7BD,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AccueilScenePainter oldDelegate) =>
      oldDelegate.decor != decor ||
      oldDelegate.dark != dark ||
      oldDelegate.thumbnail != thumbnail;
}
