// flutter test tool/render_brand_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elyrii_app/app/launch/elyrii_launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('export the production launch scene', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fonts = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'));
    await fonts.load();
    const boundaryKey = ValueKey('launch-preview');
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundaryKey,
          child: ElyriiLaunchScene(progress: 0.55),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(ElyriiLaunchScene.markAsset),
        tester.element(find.byType(ElyriiLaunchScene)),
      );
    });
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    await tester.runAsync(() async {
      final screenshot = await boundary.toImage(pixelRatio: 2);
      final data = await screenshot.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '../art/branding/launch-preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      screenshot.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
