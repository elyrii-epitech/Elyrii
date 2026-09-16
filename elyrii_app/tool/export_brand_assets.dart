// Run from elyrii_app: dart run tool/export_brand_assets.dart
// Artwork is generated with ImageGen; this only fits it to OS export dimensions.
import 'dart:io';
import 'dart:math' as math;

// Available through the pinned flutter_launcher_icons dev dependency.
// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;

void main() {
  final mark = img.decodePng(
    File('../art/branding/elyrii-mark.png').readAsBytesSync(),
  )!;
  final icon = img.decodePng(
    File('../art/branding/elyrii-icon.png').readAsBytesSync(),
  )!;
  if (mark.numChannels != 4 || mark.getPixel(0, 0).a != 0) {
    throw StateError('The brand mark must have a transparent background.');
  }

  var left = mark.width;
  var top = mark.height;
  var right = 0;
  var bottom = 0;
  for (final pixel in mark) {
    if (pixel.a <= 8) continue;
    left = math.min(left, pixel.x);
    top = math.min(top, pixel.y);
    right = math.max(right, pixel.x);
    bottom = math.max(bottom, pixel.y);
  }
  final centerX = (left + right) / 2;
  final centerY = (top + bottom) / 2;
  var radius = 0.0;
  for (final pixel in mark) {
    if (pixel.a <= 8) continue;
    radius = math.max(
      radius,
      math.sqrt(
        math.pow(pixel.x - centerX, 2) + math.pow(pixel.y - centerY, 2),
      ),
    );
  }

  void splash(int size, String path, {bool opaque = false}) {
    // The whole silhouette fits inside Android's circular adaptive safe zone.
    final factor = size * (opaque ? 0.38 : 0.30) / radius;
    final fitted = img.copyResize(
      mark,
      width: (mark.width * factor).round(),
      height: (mark.height * factor).round(),
      interpolation: img.Interpolation.cubic,
    );
    final canvas = img.Image(
      width: size,
      height: size,
      numChannels: opaque ? 3 : 4,
    );
    if (opaque) {
      img.fill(canvas, color: img.ColorRgb8(20, 19, 20));
    }
    img.compositeImage(
      canvas,
      fitted,
      dstX: (size / 2 - centerX * factor).round(),
      dstY: (size / 2 - centerY * factor).round(),
    );
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(canvas));
  }

  // flutter_native_splash treats the input as @4x on BOTH platforms, then
  // emits iOS @1x/@2x/@3x and Android mdpi through xxxhdpi resources.
  splash(1152, 'assets/splash_icon.png');
  splash(1024, 'assets/brand/icon_web.png', opaque: true);
  final opaqueIcon = img
      .copyResize(
        icon,
        width: 1024,
        height: 1024,
        interpolation: img.Interpolation.cubic,
      )
      .convert(numChannels: 3);
  for (final path in ['assets/icon.png', 'assets/icon_black_bg.png']) {
    File(path).writeAsBytesSync(img.encodePng(opaqueIcon));
  }
  stdout.writeln(
    'Exported opaque 1024px icons and a 1152px transparent launch mark.',
  );
}
