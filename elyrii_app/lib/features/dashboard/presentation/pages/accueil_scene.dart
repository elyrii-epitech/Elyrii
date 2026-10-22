part of 'dashboard_page.dart';

class _NightPainter extends CustomPainter {
  final bool dark;
  const _NightPainter(this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    if (!dark) return;
    final paint = Paint();
    const stars = [
      (8.0, 12.0, 1.4, 1.0),
      (23.0, 31.0, 1.2, .8),
      (41.0, 8.0, 1.8, 1.0),
      (57.0, 23.0, 1.2, .7),
      (72.0, 14.0, 1.4, .9),
      (89.0, 28.0, 2.0, 1.0),
      (14.0, 46.0, 1.2, .6),
      (34.0, 58.0, 1.2, .55),
      (63.0, 49.0, 1.6, .65),
      (82.0, 61.0, 1.2, .55),
      (6.0, 74.0, 1.2, .5),
      (48.0, 81.0, 1.2, .45),
      (93.0, 86.0, 1.6, .5),
      (27.0, 92.0, 1.2, .4),
      (52.0, 3.0, 1.5, 1.0),
      (3.0, 22.0, 1.2, .8),
      (96.0, 6.0, 1.4, .85),
      (30.0, 17.0, 1.2, .7),
    ];
    for (final (x, y, r, a) in stars) {
      canvas.drawCircle(
        Offset(size.width * x / 100, size.height * y / 100),
        r / 2,
        paint..color = Colors.white.withValues(alpha: a),
      );
    }
    const distant = [
      (12.0, 18.0, .8),
      (64.0, 41.0, .8),
      (37.0, 77.0, .7),
      (86.0, 63.0, .9),
      (23.0, 52.0, .7),
      (78.0, 9.0, .7),
    ];
    for (var i = 0; i < distant.length; i++) {
      final (x, y, r) = distant[i];
      final w = i < 3 ? 173.0 : 241.0;
      final h = i < 3 ? 191.0 : 263.0;
      for (var tx = 0.0; tx < size.width; tx += w) {
        for (var ty = 0.0; ty < size.height; ty += h) {
          final point = Offset(tx + x * w / 100, ty + y * h / 100);
          final alpha = .55 * (1 - .65 * (point.dy / size.height));
          canvas.drawCircle(
            point,
            r / 2,
            paint..color = Colors.white.withValues(alpha: alpha.clamp(0, 1)),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_NightPainter oldDelegate) => oldDelegate.dark != dark;
}

class _ScenePainter extends CustomPainter {
  /// Art line kept at its phone-frame height when a wide column makes the art
  /// overflow vertically, so the moon and the ground both stay in view.
  static const _horizon = 300.0;
  final MascotDecor decor;
  final bool dark;
  final bool thumbnail;
  const _ScenePainter({
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
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.decor != decor || oldDelegate.dark != dark;
}
