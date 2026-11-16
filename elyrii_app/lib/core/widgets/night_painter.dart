import 'package:flutter/material.dart';

class NightPainter extends CustomPainter {
  final bool dark;
  const NightPainter(this.dark);
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
  bool shouldRepaint(NightPainter oldDelegate) => oldDelegate.dark != dark;
}
